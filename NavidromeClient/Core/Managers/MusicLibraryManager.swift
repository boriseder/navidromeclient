//
//  MusicLibraryManager.swift - FIXED: Pure Facade Pattern
//  NavidromeClient
//
//  FIXED: Removed contentService extraction
//  CLEAN: Direct facade delegation only
//
//  MusicLibraryManager.swift
//  Manages progressive loading of complete music library
//  Responsibilities: Load albums/artists/genres in batches, handle pagination

import Foundation
import SwiftUI

@MainActor
class MusicLibraryManager: ObservableObject {
    // REMOVED: static let shared = MusicLibraryManager()
    
    // MARK: - Progressive Library Data
    @Published private(set) var loadedAlbums: [Album] = []
    @Published private(set) var totalAlbumCount: Int = 0
    @Published private(set) var albumLoadingState: DataLoadingState = .idle
    
    @Published private(set) var loadedArtists: [Artist] = []
    @Published private(set) var totalArtistCount: Int = 0
    @Published private(set) var artistLoadingState: DataLoadingState = .idle
    
    @Published private(set) var loadedGenres: [Genre] = []
    @Published private(set) var genreLoadingState: DataLoadingState = .idle
    
    // MARK: - State Management
    @Published private(set) var hasLoadedInitialData = false
    @Published private(set) var lastRefreshDate: Date?
    @Published private(set) var backgroundLoadingProgress: String = ""
    
    // MARK: - Loading Coordination
    private var isCurrentlyLoading = false
    private var pendingNetworkStateChange: EffectiveConnectionState?
    
    private weak var service: UnifiedSubsonicService?
    
    private struct LoadingConfig {
        static let albumBatchSize = 20
        static let artistBatchSize = 25
        static let genreBatchSize = 30
        static let batchDelay: UInt64 = 200_000_000
    }
    
    init() {
        setupNetworkStateObserver()
        setupFactoryResetObserver()
    }
    
    // MARK: - PUBLIC API
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
        let freshnessDuration: TimeInterval = 10 * 60
        return Date().timeIntervalSince(lastRefresh) < freshnessDuration
    }
    
    func configure(service: UnifiedSubsonicService) {
        self.service = service
        print("MusicLibraryManager configured with UnifiedSubsonicService facade")
    }
    
    // MARK: - Coordinated Loading
    
    func loadInitialDataIfNeeded() async {
        guard !hasLoadedInitialData,
              !isCurrentlyLoading,
              let service = service,
              NetworkMonitor.shared.shouldLoadOnlineContent else {
            print("Skipping initial data load")
            return
        }
        
        isCurrentlyLoading = true
        defer { isCurrentlyLoading = false }
        
        print("Starting coordinated initial data load...")
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.loadAlbumsProgressively(reset: true)
            }
            
            group.addTask {
                try? await Task.sleep(nanoseconds: 100_000_000)
                await self.loadArtistsProgressively(reset: true)
            }
            
            group.addTask {
                try? await Task.sleep(nanoseconds: 200_000_000)
                await self.loadGenresProgressively(reset: true)
            }
        }
    }
    
    func refreshAllData() async {
        guard !isCurrentlyLoading,
              NetworkMonitor.shared.shouldLoadOnlineContent else {
            print("Skipping refresh")
            return
        }
        
        isCurrentlyLoading = true
        defer { isCurrentlyLoading = false }
        
        print("Starting coordinated data refresh...")
        
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
    }
    
    // MARK: - Network State Handling
    
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
    
    private func setupFactoryResetObserver() {
        NotificationCenter.default.addObserver(
            forName: .factoryResetRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reset()
            }
        }
    }
    
    func handleNetworkChange(isOnline: Bool) async {
        await handleNetworkStateChange(NetworkMonitor.shared.effectiveConnectionState)
    }
    
    private func handleNetworkStateChange(_ newState: EffectiveConnectionState) async {
        if isCurrentlyLoading {
            pendingNetworkStateChange = newState
            print("Network state change queued during loading: \(newState.displayName)")
            return
        }
        
        pendingNetworkStateChange = nil
        
        switch newState {
        case .online:
            if !isDataFresh && service != nil {
                print("Network online - refreshing stale data")
                await refreshAllData()
                // objectWillChange fired by refreshAllData when data actually changes
            } else {
                print("Network online - data is fresh, no UI update needed")
                // No objectWillChange: data hasn't changed, views will react to NetworkMonitor
            }
            
        case .userOffline, .serverUnreachable, .disconnected:
            print("Network effectively offline - no UI update needed")
            // No objectWillChange: views will react to NetworkMonitor's state change
            // Only views displaying different data (offline vs online) will re-render
        }
        
        if let pendingState = pendingNetworkStateChange {
            await handleNetworkStateChange(pendingState)
        }
    }
    
    // MARK: - ALBUMS LOADING
    
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
            print("UnifiedSubsonicService not configured")
            return
        }
        
        guard NetworkMonitor.shared.shouldLoadOnlineContent else {
            albumLoadingState = .completed
            print("Not loading albums - should not load online content")
            return
        }
        
        let offset = loadedAlbums.count
        let batchSize = LoadingConfig.albumBatchSize
        
        albumLoadingState = offset == 0 ? .loading : .loadingMore
        backgroundLoadingProgress = "Loading albums \(offset + 1)-\(offset + batchSize)..."
        
        do {
            if offset > 0 {
                try await Task.sleep(nanoseconds: LoadingConfig.batchDelay)
            }
            
            let newAlbums = try await service.getAllAlbums(
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
            
            AlbumMetadataCache.shared.cacheAlbums(newAlbums)
            
            loadedAlbums.append(contentsOf: newAlbums)
            
            if newAlbums.count < batchSize {
                albumLoadingState = .completed
                totalAlbumCount = loadedAlbums.count
            } else {
                albumLoadingState = .idle
            }
            
            if !hasLoadedInitialData && loadedAlbums.count >= LoadingConfig.albumBatchSize {
                hasLoadedInitialData = true
                lastRefreshDate = Date()
            }
            
            backgroundLoadingProgress = ""
            
        } catch {
            await handleLoadingError(error, for: "albums")
        }
    }
    
    // MARK: - ARTISTS LOADING
    
    func loadArtistsProgressively(reset: Bool = false) async {
        
        if reset {
            loadedArtists = []
            totalArtistCount = 0
            artistLoadingState = .idle
        }
        
        guard artistLoadingState.canLoadMore else { return }
        
        guard let service = service else {
            artistLoadingState = .error("Service not available")
            print("UnifiedSubsonicService not configured")
            return
        }
        
        guard NetworkMonitor.shared.shouldLoadOnlineContent else {
            artistLoadingState = .completed
            print("Not loading artists - should not load online content")
            return
        }
        
        artistLoadingState = loadedArtists.isEmpty ? .loading : .loadingMore
        backgroundLoadingProgress = "Loading artists..."
        
        do {
            let allArtists = try await service.getArtists()
            
            loadedArtists = allArtists
            totalArtistCount = allArtists.count
            artistLoadingState = .completed
            backgroundLoadingProgress = ""
            
        } catch {
            await handleLoadingError(error, for: "artists")
        }
    }
    
    // MARK: - GENRES LOADING
    
    func loadGenresProgressively(reset: Bool = false) async {
        
        if reset {
            loadedGenres = []
            genreLoadingState = .idle
        }
        
        guard genreLoadingState.canLoadMore else { return }
        
        guard let service = service else {
            genreLoadingState = .error("Service not available")
            print("UnifiedSubsonicService not configured")
            return
        }
        
        guard NetworkMonitor.shared.shouldLoadOnlineContent else {
            genreLoadingState = .completed
            print("Not loading genres - should not load online content")
            return
        }
        
        genreLoadingState = .loading
        backgroundLoadingProgress = "Loading genres..."
        
        do {
            let allGenres = try await service.getGenres()
            
            loadedGenres = allGenres
            genreLoadingState = .completed
            backgroundLoadingProgress = ""
            
        } catch {
            await handleLoadingError(error, for: "genres")
        }
    }
    
    // MARK: - Load More
    
    func loadMoreAlbumsIfNeeded() async {
        await loadAlbumsProgressively()
    }
    
    // MARK: - Artist/Genre Detail Support
    
    func loadAlbums(context: AlbumCollectionContext) async throws -> [Album] {
        guard let service = service else {
            print("UnifiedSubsonicService not available for context loading")
            throw URLError(.networkConnectionLost)
        }
        
        guard NetworkMonitor.shared.shouldLoadOnlineContent else {
            print("Cannot load albums for context - should not load online content")
            throw URLError(.notConnectedToInternet)
        }
        
        switch context {
        case .byArtist(let artist):
            return try await service.getAlbumsByArtist(artistId: artist.id)
        case .byGenre(let genre):
            return try await service.getAlbumsByGenre(genre: genre.value)
        }
    }
    
    // MARK: - Private Implementation
    
    private func handleLoadingError(_ error: Error, for dataType: String) async {
        print("Failed to load \(dataType): \(error)")
        
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
    
    // MARK: - Reset
    
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
        
        print("MusicLibraryManager reset completed")
    }
}

// MARK: - DATA LOADING STATE

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
