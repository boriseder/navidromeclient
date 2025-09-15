//
//  LibraryViewModel.swift
//  NavidromeClient
//
//  Created by Boris Eder on 16.09.25.
//


//
//  LibraryViewModel.swift - Centralized Library UI Logic
//  NavidromeClient
//
//  ✅ EXTRACTS: All filtering, sorting, data source logic from AlbumsView, ArtistsView, GenreView
//  ✅ DRY: Single source of truth for library UI state
//

import Foundation
import SwiftUI

@MainActor
class LibraryViewModel: ObservableObject {
    
    // MARK: - Search & Filter State
    @Published var searchText: String = ""
    @Published var selectedAlbumSort: SubsonicService.AlbumSortType = .alphabetical
    
    // MARK: - Dependencies
    private let musicLibraryManager: MusicLibraryManager
    private let networkMonitor: NetworkMonitor
    private let offlineManager: OfflineManager
    private let downloadManager: DownloadManager
    
    init(
        musicLibraryManager: MusicLibraryManager = MusicLibraryManager.shared,
        networkMonitor: NetworkMonitor = NetworkMonitor.shared,
        offlineManager: OfflineManager = OfflineManager.shared,
        downloadManager: DownloadManager = DownloadManager.shared
    ) {
        self.musicLibraryManager = musicLibraryManager
        self.networkMonitor = networkMonitor
        self.offlineManager = offlineManager
        self.downloadManager = downloadManager
    }
    
    
    
    
    // MARK: - ALBUMS: Data Source + Filtering Logic
    /// Get filtered and sorted albums for UI
    var displayedAlbums: [Album] {
        let sourceAlbums = getAlbumDataSource()
        return filterAlbums(sourceAlbums)
    }
    
    /// Get album data source based on online/offline mode
    private func getAlbumDataSource() -> [Album] {
        let canLoadOnline = networkMonitor.canLoadOnlineContent
        let isOffline = offlineManager.isOfflineMode
        
        if canLoadOnline && !isOffline {
            return musicLibraryManager.albums
        } else {
            // Offline mode: get albums from downloaded content
            let downloadedAlbumIds = Set(downloadManager.downloadedAlbums.map { $0.albumId })
            return AlbumMetadataCache.shared.getAlbums(ids: downloadedAlbumIds)
        }
    }
    
    /// Filter albums by search text
    private func filterAlbums(_ albums: [Album]) -> [Album] {
        if searchText.isEmpty {
            return albums
        } else {
            return albums.filter { album in
                let nameMatches = album.name.localizedCaseInsensitiveContains(searchText)
                let artistMatches = album.artist.localizedCaseInsensitiveContains(searchText)
                return nameMatches || artistMatches
            }
        }
    }
    
    /// Load albums with specific sorting
    func loadAlbums(sortBy: SubsonicService.AlbumSortType) async {
        selectedAlbumSort = sortBy
        await musicLibraryManager.loadAlbumsProgressively(sortBy: sortBy, reset: true)
    }
    
    // MARK: - ARTISTS: Data Source + Filtering Logic
    
    /// Get filtered artists for UI
    var displayedArtists: [Artist] {
        let sourceArtists = getArtistDataSource()
        return filterArtists(sourceArtists)
    }
    
    /// Get artist data source based on online/offline mode
    private func getArtistDataSource() -> [Artist] {
        if networkMonitor.canLoadOnlineContent && !offlineManager.isOfflineMode {
            return musicLibraryManager.artists
        } else {
            return offlineManager.offlineArtists
        }
    }
    
    /// Filter artists by search text
    private func filterArtists(_ artists: [Artist]) -> [Artist] {
        let filteredArtists: [Artist]
        
        if searchText.isEmpty {
            filteredArtists = artists
        } else {
            filteredArtists = artists.filter { artist in
                artist.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filteredArtists.sorted(by: { $0.name < $1.name })
    }
    
    // MARK: - GENRES: Data Source + Filtering Logic
    
    /// Get filtered genres for UI
    var displayedGenres: [Genre] {
        let sourceGenres = getGenreDataSource()
        return filterGenres(sourceGenres)
    }
    
    /// Get genre data source based on online/offline mode
    private func getGenreDataSource() -> [Genre] {
        if networkMonitor.canLoadOnlineContent && !offlineManager.isOfflineMode {
            return musicLibraryManager.genres
        } else {
            return offlineManager.offlineGenres
        }
    }
    
    /// Filter genres by search text
    private func filterGenres(_ genres: [Genre]) -> [Genre] {
        let filteredGenres: [Genre]
        
        if searchText.isEmpty {
            filteredGenres = genres
        } else {
            filteredGenres = genres.filter { genre in
                genre.value.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filteredGenres.sorted(by: { $0.value < $1.value })
    }
    
    // MARK: - ✅ LOADING STATES: Computed Properties
    
    /// Check if initial loading is in progress
    var isLoadingInitialData: Bool {
        return musicLibraryManager.isLoading && !musicLibraryManager.hasLoadedInitialData
    }
    
    /// Check if background loading is in progress
    var isLoadingInBackground: Bool {
        return musicLibraryManager.isLoadingInBackground
    }
    
    /// Get background loading progress text
    var backgroundLoadingProgress: String {
        return musicLibraryManager.backgroundLoadingProgress
    }
    
    /// Check if data has been loaded initially
    var hasLoadedInitialData: Bool {
        return musicLibraryManager.hasLoadedInitialData
    }
    
    // MARK: - ✅ EMPTY STATES: Logic
    
    /// Check if albums are empty for current mode
    var albumsIsEmpty: Bool {
        return displayedAlbums.isEmpty
    }
    
    /// Check if artists are empty for current mode
    var artistsIsEmpty: Bool {
        return displayedArtists.isEmpty
    }
    
    /// Check if genres are empty for current mode
    var genresIsEmpty: Bool {
        return displayedGenres.isEmpty
    }
    
    // MARK: - ✅ MODE DETECTION: Computed Properties
    
    /// Check if we're in offline mode
    var isOfflineMode: Bool {
        return !networkMonitor.canLoadOnlineContent || offlineManager.isOfflineMode
    }
    
    /// Check if we can load online content
    var canLoadOnlineContent: Bool {
        return networkMonitor.canLoadOnlineContent
    }
    
    // MARK: - ✅ ACTIONS: Delegate to Managers
    
    /// Refresh all library data
    func refreshAllData() async {
        await musicLibraryManager.refreshAllData()
    }
    
    /// Load more albums if needed (infinite scroll)
    func loadMoreAlbumsIfNeeded() async {
        await musicLibraryManager.loadMoreAlbumsIfNeeded()
    }
    
    /// Clear search text
    func clearSearch() {
        searchText = ""
    }
    
    /// Toggle offline mode
    func toggleOfflineMode() {
        offlineManager.toggleOfflineMode()
    }
    
    /// Switch to offline mode
    func switchToOfflineMode() {
        offlineManager.switchToOfflineMode()
    }
    
    /// Switch to online mode
    func switchToOnlineMode() {
        offlineManager.switchToOnlineMode()
    }
    
    // MARK: - ✅ STATS: For UI Display
    
    /// Get album count for current mode
    var albumCount: Int {
        return displayedAlbums.count
    }
    
    /// Get artist count for current mode
    var artistCount: Int {
        return displayedArtists.count
    }
    
    /// Get genre count for current mode
    var genreCount: Int {
        return displayedGenres.count
    }
    
    /// Get offline stats summary
    var offlineStats: OfflineStats {
        return offlineManager.offlineStats
    }
    
    // MARK: - ✅ SEARCH: Debounced Logic
    
    private var searchTask: Task<Void, Never>?
    
    /// Handle search text changes with debouncing
    func handleSearchTextChange() {
        // Cancel previous search
        searchTask?.cancel()
        
        // Start new debounced search
        searchTask = Task {
            // Wait for user to stop typing
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
            
            guard !Task.isCancelled else { return }
            
            // Trigger UI update by changing @Published searchText
            // (This will automatically update computed properties)
            await MainActor.run {
                self.objectWillChange.send()
            }
        }
    }
    
    // MARK: - ✅ PRELOADING: For Performance
    
    /// Preload images for visible albums
    func preloadAlbumImages(_ albums: [Album], coverArtManager: CoverArtManager) async {
        let albumsToPreload = Array(albums.prefix(20)) // Limit to visible items
        await coverArtManager.preloadAlbums(albumsToPreload, size: 200)
    }
    
    /// Preload images for visible artists
    func preloadArtistImages(_ artists: [Artist], coverArtManager: CoverArtManager) async {
        let artistsToPreload = Array(artists.prefix(20)) // Limit to visible items
        await coverArtManager.preloadArtists(artistsToPreload, size: 120)
    }
    
    // MARK: - ✅ SORTING: Album Sort Options
    
    /// Get all available album sort options
    var availableAlbumSorts: [SubsonicService.AlbumSortType] {
        return SubsonicService.AlbumSortType.allCases
    }
    
    /// Check if a sort type is currently selected
    func isAlbumSortSelected(_ sortType: SubsonicService.AlbumSortType) -> Bool {
        return selectedAlbumSort == sortType
    }
    
    // MARK: - ✅ NETWORK HANDLING: Reactive Updates
    
    /// Handle network status changes
    func handleNetworkChange(isOnline: Bool) async {
        if isOnline && !offlineManager.isOfflineMode {
            // Network restored and not in forced offline mode
            await refreshAllData()
        }
        
        // UI will automatically update via computed properties
        objectWillChange.send()
    }
    
    /// Handle offline mode changes
    func handleOfflineModeChange(isOfflineMode: Bool) {
        // UI will automatically update via computed properties
        objectWillChange.send()
    }
}

// MARK: - ✅ CONVENIENCE EXTENSIONS

extension LibraryViewModel {
    
    /// Check if we should show loading state for albums
    var shouldShowAlbumsLoading: Bool {
        return isLoadingInitialData
    }
    
    /// Check if we should show empty state for albums
    var shouldShowAlbumsEmptyState: Bool {
        return !isLoadingInitialData && albumsIsEmpty
    }
    
    /// Check if we should show loading state for artists
    var shouldShowArtistsLoading: Bool {
        return isLoadingInitialData
    }
    
    /// Check if we should show empty state for artists
    var shouldShowArtistsEmptyState: Bool {
        return !isLoadingInitialData && artistsIsEmpty
    }
    
    /// Check if we should show loading state for genres
    var shouldShowGenresLoading: Bool {
        return isLoadingInitialData
    }
    
    /// Check if we should show empty state for genres
    var shouldShowGenresEmptyState: Bool {
        return !isLoadingInitialData && genresIsEmpty
    }
    
    /// Get status header data for albums
    var albumsStatusHeaderData: LibraryStatusHeaderData {
        return LibraryStatusHeaderData(
            itemType: .albums,
            count: albumCount,
            isOnline: canLoadOnlineContent,
            isOfflineMode: isOfflineMode
        )
    }
    
    /// Get status header data for artists
    var artistsStatusHeaderData: LibraryStatusHeaderData {
        return LibraryStatusHeaderData(
            itemType: .artists,
            count: artistCount,
            isOnline: canLoadOnlineContent,
            isOfflineMode: isOfflineMode
        )
    }
    
    /// Get status header data for genres
    var genresStatusHeaderData: LibraryStatusHeaderData {
        return LibraryStatusHeaderData(
            itemType: .genres,
            count: genreCount,
            isOnline: canLoadOnlineContent,
            isOfflineMode: isOfflineMode
        )
    }
}

// MARK: - SUPPORTING TYPES

struct LibraryStatusHeaderData {
    let itemType: LibraryItemType
    let count: Int
    let isOnline: Bool
    let isOfflineMode: Bool
}
