//
//  AlbumsViewContent.swift - PHASE 3: Standardized View Logic
//  NavidromeClient
//
//   STANDARDIZED: Consistent state handling across all views
//   ELIMINATED: Inconsistent loading patterns
//

import SwiftUI

struct AlbumsViewContent: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var coverArtManager: CoverArtManager
    @EnvironmentObject var musicLibraryManager: MusicLibraryManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var downloadManager: DownloadManager
    
    @State private var searchText = ""
    @State private var selectedAlbumSort: ContentService.AlbumSortType = .alphabetical
    @StateObject private var debouncer = Debouncer()
    
    // MARK: - PHASE 3: Standardized State Logic
    
    private var connectionState: EffectiveConnectionState {
        networkMonitor.effectiveConnectionState
    }
    
    private var displayedAlbums: [Album] {
        switch connectionState {
        case .online:
            return filterAlbums(musicLibraryManager.albums)
        case .userOffline, .serverUnreachable, .disconnected:
            return filterAlbums(getOfflineAlbums())
        }
    }
    
    private var shouldShowLoading: Bool {
        return connectionState.shouldLoadOnlineContent &&
               musicLibraryManager.isLoading &&
               !musicLibraryManager.hasLoadedInitialData
    }
    
    private var isEmpty: Bool {
        return displayedAlbums.isEmpty
    }
    
    private var isEffectivelyOffline: Bool {
        return connectionState.isEffectivelyOffline
    }
    
    var body: some View {
        NavigationStack {
            UnifiedLibraryContainer(
                items: displayedAlbums,
                isLoading: shouldShowLoading,
                isEmpty: isEmpty && !shouldShowLoading,
                isOfflineMode: isEffectivelyOffline,
                emptyStateType: .albums,
                layout: .twoColumnGrid,
                onLoadMore: { _ in
                    // PHASE 3: Only load more if we should load online content
                    guard connectionState.shouldLoadOnlineContent else { return }
                    Task { await musicLibraryManager.loadMoreAlbumsIfNeeded() }
                }
            ) { album, index in
                NavigationLink(value: album) {
                    CardItemContainer(content: CardContent.album(album), index: index)
                }
            }
            .searchable(text: $searchText, prompt: "Search albums...")
            .refreshable {
                // PHASE 3: Only refresh if we should load online content
                guard connectionState.shouldLoadOnlineContent else { return }
                await refreshAllData()
            }
            .onChange(of: searchText) { _, _ in
                handleSearchTextChange()
            }
            .task(id: displayedAlbums.count) {
                await preloadAlbumImages()
            }
            .navigationDestination(for: Album.self) { album in
                AlbumDetailViewContent(album: album)
            }
            .unifiedToolbar(.libraryWithSort(
                title: "Albums",
                isOffline: isEffectivelyOffline,
                currentSort: selectedAlbumSort,
                sortOptions: ContentService.AlbumSortType.allCases,
                onRefresh: {
                    guard connectionState.shouldLoadOnlineContent else { return }
                    await loadAlbums(sortBy: selectedAlbumSort)
                },
                onToggleOffline: toggleOfflineMode,
                onSort: { sortType in
                    guard connectionState.shouldLoadOnlineContent else { return }
                    Task { await loadAlbums(sortBy: sortType) }
                }
            ))
        }
    }
    
    // MARK: - PHASE 3: Standardized Business Logic
    
    private func getOfflineAlbums() -> [Album] {
        let downloadedAlbumIds = Set(downloadManager.downloadedAlbums.map { $0.albumId })
        return AlbumMetadataCache.shared.getAlbums(ids: downloadedAlbumIds)
    }
    
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
    
    private func refreshAllData() async {
        await musicLibraryManager.refreshAllData()
    }
    
    private func loadAlbums(sortBy: ContentService.AlbumSortType) async {
        selectedAlbumSort = sortBy
        await musicLibraryManager.loadAlbumsProgressively(sortBy: sortBy, reset: true)
    }
    
    private func preloadAlbumImages() async {
        let albumsToPreload = Array(displayedAlbums.prefix(20))
        await coverArtManager.preloadAlbums(albumsToPreload, size: 200)
    }
    
    private func handleSearchTextChange() {
        debouncer.debounce {
            // Search filtering happens automatically via computed property
        }
    }
    
    private func toggleOfflineMode() {
        offlineManager.toggleOfflineMode()
    }
}
