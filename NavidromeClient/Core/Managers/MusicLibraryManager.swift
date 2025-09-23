//
//  MusicLibraryManager.swift - SIMPLIFIED: Direct UnifiedSubsonicService
//  NavidromeClient
//
//   REMOVED: ContentService dependency, legacy compatibility
//   SIMPLIFIED: Single service dependency via UnifiedSubsonicService
//   CLEAN: Direct access to service.contentService
//

import Foundation
import SwiftUI

@MainActor
class MusicLibraryManager: ObservableObject {
    //  SINGLETON PATTERN (unchanged)
    static let shared = MusicLibraryManager()
    
    //  PROGRESSIVE LIBRARY DATA (unchanged)
    @Published private(set) var loadedAlbums: [Album] = []
    @Published private(set) var totalAlbumCount: Int = 0
    @Published private(set) var albumLoadingState: DataLoadingState = .idle
    
    @Published private(set) var loadedArtists: [Artist] = []
    @Published private(set) var totalArtistCount: Int = 0
    @Published private(set) var artistLoadingState: DataLoadingState = .idle
    
    @Published private(set) var loadedGenres: [Genre] = []
    @Published private(set) var genreLoadingState: DataLoadingState = .idle
    
    //  STATE MANAGEMENT (unchanged)
    @Published private(set) var hasLoadedInitialData = false
    @Published private(set) var lastRefreshDate: Date?
    @Published private(set) var backgroundLoadingProgress: String = ""
    
    //  SINGLE SERVICE DEPENDENCY
    private weak var service: UnifiedSubsonicService?
    
    //  CONFIGURATION (unchanged)
    private struct LoadingConfig {
        static let albumBatchSize = 20
        static let artistBatchSize = 25
        static let genreBatchSize = 30
        static let batchDelay: UInt64 = 200_000_000   // 200ms
    }
    
    //  SINGLETON INIT (unchanged)
    private init() {}
    
    // MARK: -  PUBLIC API (unchanged)
    var albums: [Album] { loadedAlbums }
    var artists: [Artist] { loadedArtists }
    var genres: [Genre] { loadedGenres }
    
    var isLoading: Bool {
        albumLoadingState.isLoading || artistLoadingState.isLoading || genreLoadingState.isLoading
    }
    
    var isLoadingInBackground: Bool {
        isLoading && hasLoadedInitialData
    }
    
    var isDataFresh: Bool {
        guard let lastRefresh = lastRefreshDate else { return false }
        let freshnessDuration: TimeInterval = 10 * 60 // 10 minutes
        return Date().timeIntervalSince(lastRefresh) < freshnessDuration
    }
    
    //  SIMPLIFIED: Single configuration method
    func configure(service: UnifiedSubsonicService) {
        self.service = service
        print(" MusicLibraryManager configured with UnifiedSubsonicService")
    }
    
    // MARK: -  ALBUMS LOADING with Direct Service Access
    
    func loadAlbumsProgressively(
        sortBy: ContentService.AlbumSortType = .alphabetical,
        reset: Bool = false
    ) async {
        
        if reset {
            loadedAlbums = []
            totalAlbumCount = 0
            albumLoadingState = .idle
        }
        
        guard albumLoadingState.canLoadMore else { return }
        
        //  DIRECT SERVICE ACCESS
        guard let service = service else {
            albumLoadingState = .error("Service not available")
            print("❌ UnifiedSubsonicService not configured")
            return
        }
        
        let offset = loadedAlbums.count
        let batchSize = LoadingConfig.albumBatchSize
        
        albumLoadingState = offset == 0 ? .loading : .loadingMore
        backgroundLoadingProgress = "Loading albums \(offset + 1)-\(offset + batchSize)..."
        
        do {
            // Add delay for UI responsiveness
            if offset > 0 {
                try await Task.sleep(nanoseconds: LoadingConfig.batchDelay)
            }
            
            //  DIRECT ACCESS: service.contentService
            let newAlbums = try await service.contentService.getAllAlbums(
                sortBy: sortBy,
                size: batchSize,
                offset: offset
            )
            
            if newAlbums.isEmpty {
                albumLoadingState = .completed
                totalAlbumCount = loadedAlbums.count
                backgroundLoadingProgress = ""
                return
            }
            
            // Cache albums for offline use (unchanged)
            AlbumMetadataCache.shared.cacheAlbums(newAlbums)
            
            // Update UI progressively (unchanged)
            loadedAlbums.append(contentsOf: newAlbums)
            
            // Determine if we have more to load (unchanged)
            if newAlbums.count < batchSize {
                albumLoadingState = .completed
                totalAlbumCount = loadedAlbums.count
            } else {
                albumLoadingState = .idle
            }
            
            // Update initial data flag (unchanged)
            if !hasLoadedInitialData && loadedAlbums.count >= LoadingConfig.albumBatchSize {
                hasLoadedInitialData = true
                lastRefreshDate = Date()
            }
            
            backgroundLoadingProgress = ""
            
            print(" Loaded album batch: \(newAlbums.count) albums (total: \(loadedAlbums.count))")
            
        } catch {
            await handleLoadingError(error, for: "albums")
        }
    }
    
    // MARK: -  ARTISTS LOADING with Direct Service Access
    
    func loadArtistsProgressively(reset: Bool = false) async {
        
        if reset {
            loadedArtists = []
            totalArtistCount = 0
            artistLoadingState = .idle
        }
        
        guard artistLoadingState.canLoadMore else { return }
        
        //  DIRECT SERVICE ACCESS
        guard let service = service else {
            artistLoadingState = .error("Service not available")
            print("❌ UnifiedSubsonicService not configured")
            return
        }
        
        artistLoadingState = loadedArtists.isEmpty ? .loading : .loadingMore
        backgroundLoadingProgress = "Loading artists..."
        
        do {
            //  DIRECT ACCESS: service.contentService
            let allArtists = try await service.contentService.getArtists()
            
            loadedArtists = allArtists
            totalArtistCount = allArtists.count
            artistLoadingState = .completed
            backgroundLoadingProgress = ""
            
            print(" Loaded artists: \(allArtists.count)")
            
        } catch {
            await handleLoadingError(error, for: "artists")
        }
    }
    
    // MARK: -  GENRES LOADING with Direct Service Access
    
    func loadGenresProgressively(reset: Bool = false) async {
        
        if reset {
            loadedGenres = []
            genreLoadingState = .idle
        }
        
        guard genreLoadingState.canLoadMore else { return }
        
        //  DIRECT SERVICE ACCESS
        guard let service = service else {
            genreLoadingState = .error("Service not available")
            print("❌ UnifiedSubsonicService not configured")
            return
        }
        
        genreLoadingState = .loading
        backgroundLoadingProgress = "Loading genres..."
        
        do {
            //  DIRECT ACCESS: service.contentService
            let allGenres = try await service.contentService.getGenres()
            
            loadedGenres = allGenres
            genreLoadingState = .completed
            backgroundLoadingProgress = ""
            
            print(" Loaded genres: \(allGenres.count)")
            
        } catch {
            await handleLoadingError(error, for: "genres")
        }
    }
    
    // MARK: -  COORDINATED LOADING (simplified logic, direct service calls)
    
    func loadInitialDataIfNeeded() async {
        guard !hasLoadedInitialData,
              let service = service,
              NetworkMonitor.shared.canLoadOnlineContent else {
            print("⚠️ Skipping initial data load - Service: \(service != nil), Network: \(NetworkMonitor.shared.canLoadOnlineContent)")
            return
        }
        
        print("🚀 Starting progressive initial data load...")
        
        // Load first batch of each type with staggered timing (unchanged)
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.loadAlbumsProgressively(reset: true)
            }
            
            group.addTask {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
                await self.loadArtistsProgressively(reset: true)
            }
            
            group.addTask {
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms delay
                await self.loadGenresProgressively(reset: true)
            }
        }
        
        print(" Initial progressive data load completed")
    }
    
    func loadMoreAlbumsIfNeeded() async {
        await loadAlbumsProgressively()
    }
    
    func refreshAllData() async {
        print("🔄 Starting progressive data refresh...")
        
        // Reset all states and reload (unchanged)
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.loadAlbumsProgressively(reset: true)
            }
            group.addTask {
                await self.loadArtistsProgressively(reset: true)
            }
            group.addTask {
                await self.loadGenresProgressively(reset: true)
            }
        }
        
        lastRefreshDate = Date()
        print(" Progressive data refresh completed")
    }
    
    // MARK: -  NETWORK STATE HANDLING (unchanged)
    
    func handleNetworkChange(isOnline: Bool) async {
        guard isOnline,
              !OfflineManager.shared.isOfflineMode,
              let service = service else {
            return
        }
        
        if !isDataFresh {
            print("🌐 Network restored - refreshing stale data")
            await refreshAllData()
        } else {
            print("🌐 Network restored - data is fresh, skipping refresh")
        }
    }
    
    // MARK: -  ARTIST/GENRE DETAIL SUPPORT with Direct Service Access
    
    
    func loadAlbums(context: AlbumCollectionContext) async throws -> [Album] {
        //  DIRECT SERVICE ACCESS
        guard let service = service else {
            print("❌ UnifiedSubsonicService not available for context loading")
            throw URLError(.networkConnectionLost)
        }
        
        switch context {
        case .byArtist(let artist):
            //  DIRECT ACCESS: service.contentService
            return try await service.contentService.getAlbumsByArtist(artistId: artist.id)
        case .byGenre(let genre):
            //  DIRECT ACCESS: service.contentService
            return try await service.contentService.getAlbumsByGenre(genre: genre.value)
        }
    }
    
    // MARK: -  PRIVATE IMPLEMENTATION (simplified error messages)
    
    private func handleLoadingError(_ error: Error, for dataType: String) async {
        print("❌ Failed to load \(dataType): \(error)")
        
        let errorMessage: String
        if let subsonicError = error as? SubsonicError {
            switch subsonicError {
            case .timeout:
                await handleImmediateOfflineSwitch()
                return
            case .network where subsonicError.isOfflineError:
                await handleOfflineFallback()
                return
            default:
                errorMessage = subsonicError.localizedDescription
            }
        } else {
            errorMessage = error.localizedDescription
        }
        
        // Update appropriate loading state (unchanged)
        switch dataType {
        case "albums":
            albumLoadingState = .error(errorMessage)
        case "artists":
            artistLoadingState = .error(errorMessage)
        case "genres":
            genreLoadingState = .error(errorMessage)
        default:
            break
        }
        
        backgroundLoadingProgress = ""
    }
    
    private func handleImmediateOfflineSwitch() async {
        OfflineManager.shared.switchToOfflineMode()
        await NetworkMonitor.shared.checkServerConnection()
        print("⚡ Immediate offline switch completed")
    }
    
    private func handleOfflineFallback() async {
        OfflineManager.shared.switchToOfflineMode()
    }
    
    // MARK: -  RESET (unchanged)
    
    func reset() {
        loadedAlbums = []
        loadedArtists = []
        loadedGenres = []
        
        albumLoadingState = .idle
        artistLoadingState = .idle
        genreLoadingState = .idle
        
        hasLoadedInitialData = false
        lastRefreshDate = nil
        backgroundLoadingProgress = ""
        totalAlbumCount = 0
        totalArtistCount = 0
        
        print(" MusicLibraryManager reset completed")
    }
}

// MARK: -  DATA LOADING STATE (unchanged)

enum DataLoadingState: Equatable {
    case idle
    case loading
    case loadingMore
    case completed
    case error(String)
    
    var isLoading: Bool {
        switch self {
        case .loading, .loadingMore: return true
        default: return false
        }
    }
    
    var canLoadMore: Bool {
        switch self {
        case .idle: return true
        case .loading,.completed, .loadingMore, .error: return false
        }
    }
}
