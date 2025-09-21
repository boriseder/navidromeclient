//
//  AlbumsView.swift - MIGRATED to Container Architecture
//  NavidromeClient
//
//   PHASE 1 MIGRATION: Proof-of-Concept using LibraryContainer
//   MAINTAINS: All existing functionality
//   REDUCES: ~60% of view code through container reuse
//
/*
import SwiftUI

struct AlbumsView: View {
    // MARK: - Dependencies (unchanged)
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var coverArtManager: CoverArtManager
    @EnvironmentObject var musicLibraryManager: MusicLibraryManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var downloadManager: DownloadManager
    
    // MARK: - State (unchanged)
    @State private var searchText = ""
    @State private var selectedAlbumSort: ContentService.AlbumSortType = .alphabetical
    @StateObject private var debouncer = Debouncer()
    
    // MARK: - Computed Properties (unchanged)
    private var displayedAlbums: [Album] {
        let sourceAlbums = getAlbumDataSource()
        return filterAlbums(sourceAlbums)
    }
    
    private var isOfflineMode: Bool {
        return !networkMonitor.canLoadOnlineContent || offlineManager.isOfflineMode
    }
    
    private var shouldShowLoading: Bool {
        return musicLibraryManager.isLoading && !musicLibraryManager.hasLoadedInitialData
    }
    
    private var isEmpty: Bool {
        return displayedAlbums.isEmpty
    }
    
    // MARK: -  NEW: Simplified Body using LibraryContainer
    var body: some View {
        LibraryView(
            isLoading: shouldShowLoading,
            isEmpty: isEmpty && !shouldShowLoading,
            isOfflineMode: isOfflineMode,
            emptyStateType: .albums
        ) {
            AlbumsGridContent()
        }
        .onChange(of: searchText) { _, _ in
            handleSearchTextChange()
        }
        .task(id: displayedAlbums.count) {
            await preloadAlbumImages()
        }
        .navigationTitle("Albums")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search albums...")
        .refreshable { await refreshAllData() }

    }

    // MARK: -  FIXED: Grid Content with Load More
    @ViewBuilder
    private func AlbumsGridContent() -> some View {
        UnifiedContainer(
            items: displayedAlbums,
            layout: .twoColumnGrid,
            onLoadMore: { _ in
                Task {
                    await musicLibraryManager.loadMoreAlbumsIfNeeded()
                }
            }
        ) { album, index in
            NavigationLink(value: album) {
                CardItemContainer(content: .album(album), index: index)
            }
        }
    }

    // MARK: -  UNCHANGED: All business logic remains identical
    
    private func getAlbumDataSource() -> [Album] {
        if networkMonitor.canLoadOnlineContent && !isOfflineMode {
            return musicLibraryManager.albums
        } else {
            let downloadedAlbumIds = Set(downloadManager.downloadedAlbums.map { $0.albumId })
            return AlbumMetadataCache.shared.getAlbums(ids: downloadedAlbumIds)
        }
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

*/
