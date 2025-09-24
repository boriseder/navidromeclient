//
//  MusicLibraryManager.swift - PHASE 2: Loading State Coordination
//  NavidromeClient
//
//   FIXED: Race conditions and parallel loading issues
//   ADDED: Centralized loading coordination
//

import Foundation
import SwiftUI

@MainActor
class MusicLibraryManager: ObservableObject {
    static let shared = MusicLibraryManager()
    
    // MARK: - Progressive Library Data (unchanged)
    @Published private(set) var loadedAlbums: [Album] = []
    @Published private(set) var totalAlbumCount: Int = 0
    @Published private(set) var albumLoadingState: DataLoadingState = .idle
    
    @Published private(set) var loadedArtists: [Artist] = []
    @Published private(set) var totalArtistCount: Int = 0
    @Published private(set) var artistLoadingState: DataLoadingState = .idle
    
    @Published private(set) var loadedGenres: [Genre] = []
    @Published private(set) var genreLoadingState: DataLoadingState = .idle
    
    // MARK: - State Management (unchanged)
    @Published private(set) var hasLoadedInitialData = false
    @Published private(set) var lastRefreshDate: Date?
    @Published private(set) var backgroundLoadingProgress: String = ""
    
    // MARK: - PHASE 2: Loading Coordination
    private var isCurrentlyLoading = false
    private var pendingNetworkStateChange: EffectiveConnectionState?
    
    private weak var service: UnifiedSubsonicService?
    
    private struct LoadingConfig {
        static let albumBatchSize = 20
        static let artistBatchSize = 25
        static let genreBatchSize = 30
        static let batchDelay: UInt64 = 200_000_000   // 200ms
    }
    
    private init() {
        setupNetworkStateObserver()
    }
    
    // MARK: - PUBLIC API (unchanged)
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
    
    func configure(service: UnifiedSubsonicService) {
        self.service = service
        print("✅ MusicLibraryManager configured with UnifiedSubsonicService")
    }
    
    // MARK: - PHASE 2: Coordinated Loading
    
    func loadInitialDataIfNeeded() async {
        // PHASE 2: Check centralized state and prevent parallel loading
        guard !hasLoadedInitialData,
              !isCurrentlyLoading,
              let service = service,
              NetworkMonitor.shared.shouldLoadOnlineContent else {
            print("⚠️ Skipping initial data load - Already loaded: \(hasLoadedInitialData), Loading: \(isCurrentlyLoading), Should load online: \(NetworkMonitor.shared.shouldLoadOnlineContent)")
            return
        }
        
        isCurrentlyLoading = true
        defer { isCurrentlyLoading = false }
        
        print("🚀 Starting coordinated initial data load...")
        
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
        
        print("✅ Coordinated initial data load completed")
    }
    
    func refreshAllData() async {
        // PHASE 2: Prevent parallel refreshes
        guard !isCurrentlyLoading,
              NetworkMonitor.shared.shouldLoadOnlineContent else {
            print("⚠️ Skipping refresh - Loading: \(isCurrentlyLoading), Should load online: \(NetworkMonitor.shared.shouldLoadOnlineContent)")
            return
        }
        
        isCurrentlyLoading = true
        defer { isCurrentlyLoading = false }
        
        print("🔄 Starting coordinated data refresh...")
        
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
        print("✅ Coordinated data refresh completed")
    }
    
    // MARK: - PHASE 2: Network State Handling
    
    private func setupNetworkStateObserver() {
        NotificationCenter.default.addObserver(
            forName: .networkStateChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let newState = notification.object as? EffectiveConnectionState {
                Task { @MainActor in
                    await self?.handleNetworkStateChange(newState)
                }
            }
        }
    }
    
    func handleNetworkChange(isOnline: Bool) async {
        // PHASE 2: Use centralized state instead of parameter
        await handleNetworkStateChange(NetworkMonitor.shared.effectiveConnectionState)
    }
    
    private func handleNetworkStateChange(_ newState: EffectiveConnectionState) async {
        // PHASE 2: Prevent handling during active loading
        if isCurrentlyLoading {
            pendingNetworkStateChange = newState
            print("📦 Network state change queued during loading: \(newState.displayName)")
            return
        }
        
        pendingNetworkStateChange = nil
        
        switch newState {
        case .online:
            if !isDataFresh && service != nil {
                print("🌐 Network online - refreshing stale data")
                await refreshAllData()
            } else {
                print("🌐 Network online - data is fresh, triggering UI update")
                objectWillChange.send()
            }
            
        case .userOffline, .serverUnreachable, .disconnected:
            print("📵 Network effectively offline - triggering UI update for offline content")
            objectWillChange.send()
        }
        
        // Handle any pending state changes
        if let pendingState = pendingNetworkStateChange {
            await handleNetworkStateChange(pendingState)
        }
    }
    
    // MARK: - ALBUMS LOADING (unchanged core logic, added coordination)
    
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
        
        guard let service = service else {
            albumLoadingState = .error("Service not available")
            print("❌ UnifiedSubsonicService not configured")
            return
        }
        
        // PHASE 2: Check centralized state before loading
        guard NetworkMonitor.shared.shouldLoadOnlineContent else {
            albumLoadingState = .completed
            print("⚠️ Not loading albums - should not load online content")
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
            
            print("✅ Loaded album batch: \(newAlbums.count) albums (total: \(loadedAlbums.count))")
            
        } catch {
            await handleLoadingError(error, for: "albums")
        }
    }
    
    // MARK: - ARTISTS LOADING (unchanged core logic, added coordination)
    
    func loadArtistsProgressively(reset: Bool = false) async {
        
        if reset {
            loadedArtists = []
            totalArtistCount = 0
            artistLoadingState = .idle
        }
        
        guard artistLoadingState.canLoadMore else { return }
        
        guard let service = service else {
            artistLoadingState = .error("Service not available")
            print("❌ UnifiedSubsonicService not configured")
            return
        }
        
        // PHASE 2: Check centralized state before loading
        guard NetworkMonitor.shared.shouldLoadOnlineContent else {
            artistLoadingState = .completed
            print("⚠️ Not loading artists - should not load online content")
            return
        }
        
        artistLoadingState = loadedArtists.isEmpty ? .loading : .loadingMore
        backgroundLoadingProgress = "Loading artists..."
        
        do {
            let allArtists = try await service.contentService.getArtists()
            
            loadedArtists = allArtists
            totalArtistCount = allArtists.count
            artistLoadingState = .completed
            backgroundLoadingProgress = ""
            
            print("✅ Loaded artists: \(allArtists.count)")
            
        } catch {
            await handleLoadingError(error, for: "artists")
        }
    }
    
    // MARK: - GENRES LOADING (unchanged core logic, added coordination)
    
    func loadGenresProgressively(reset: Bool = false) async {
        
        if reset {
            loadedGenres = []
            genreLoadingState = .idle
        }
        
        guard genreLoadingState.canLoadMore else { return }
        
        guard let service = service else {
            genreLoadingState = .error("Service not available")
            print("❌ UnifiedSubsonicService not configured")
            return
        }
        
        // PHASE 2: Check centralized state before loading
        guard NetworkMonitor.shared.shouldLoadOnlineContent else {
            genreLoadingState = .completed
            print("⚠️ Not loading genres - should not load online content")
            return
        }
        
        genreLoadingState = .loading
        backgroundLoadingProgress = "Loading genres..."
        
        do {
            let allGenres = try await service.contentService.getGenres()
            
            loadedGenres = allGenres
            genreLoadingState = .completed
            backgroundLoadingProgress = ""
            
            print("✅ Loaded genres: \(allGenres.count)")
            
        } catch {
            await handleLoadingError(error, for: "genres")
        }
    }
    
    // MARK: - Load More (unchanged)
    
    func loadMoreAlbumsIfNeeded() async {
        await loadAlbumsProgressively()
    }
    
    // MARK: - Artist/Genre Detail Support (updated with centralized state)
    
    func loadAlbums(context: AlbumCollectionContext) async throws -> [Album] {
        guard let service = service else {
            print("❌ UnifiedSubsonicService not available for context loading")
            throw URLError(.networkConnectionLost)
        }
        
        // PHASE 2: Check centralized state
        guard NetworkMonitor.shared.shouldLoadOnlineContent else {
            print("⚠️ Cannot load albums for context - should not load online content")
            throw URLError(.notConnectedToInternet)
        }
        
        switch context {
        case .byArtist(let artist):
            return try await service.contentService.getAlbumsByArtist(artistId: artist.id)
        case .byGenre(let genre):
            return try await service.contentService.getAlbumsByGenre(genre: genre.value)
        }
    }
    
    // MARK: - Private Implementation (unchanged)
    
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
    }
    
    private func handleOfflineFallback() async {
        OfflineManager.shared.switchToOfflineMode()
    }
    
    // MARK: - Reset (unchanged)
    
    func reset() {
        isCurrentlyLoading = false
        pendingNetworkStateChange = nil
        
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
        
        print("✅ MusicLibraryManager reset completed with coordination")
    }
}

// MARK: - DATA LOADING STATE (unchanged)

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
