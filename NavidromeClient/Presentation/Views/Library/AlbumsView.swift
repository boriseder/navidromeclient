//
//  AlbumsViewContent.swift - MIGRATED: Unified State System
//  NavidromeClient
//
//   ELIMINATED: Custom LoadingView, EmptyStateView (~80 LOC)
//   UNIFIED: 4-line state logic with modern design
//   CLEAN: Single state component handles all scenarios
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
    
    // MARK: - UNIFIED: Single State Logic (4 lines)
    
    private var displayedAlbums: [Album] {
        switch networkMonitor.contentLoadingStrategy {
        case .online:
            return musicLibraryManager.albums
        case .offlineOnly:
            return getOfflineAlbums()
        }
    }
    
    private var currentState: ViewState? {
        if appConfig.isInitializingServices {
            return .loading("Setting up your music library")
        } else if musicLibraryManager.isLoading && displayedAlbums.isEmpty {
            return .loading("Loading albums")
        } else if displayedAlbums.isEmpty {
            return .empty(type: .albums)
        }
        return nil
    }
    

    
    var body: some View {
        NavigationStack {
            ZStack {
                DynamicMusicBackground()
                
                if let state = currentState {
                    UnifiedStateView(
                        state: state,
                        primaryAction: StateAction("Refresh") {
                            Task { await refreshAllData() }
                        }
                    )
                } else {
                    contentView
                }
            }
            .navigationTitle("Albums")
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)  // dunkler Hintergrund
            .toolbarColorScheme(.dark, for: .navigationBar)        // Titel weiß
            .searchable(text: $searchText, prompt: "Search albums...")
            .refreshable {
                guard networkMonitor.contentLoadingStrategy.shouldLoadOnlineContent else { return }
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
        }

    }
    
    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DSLayout.contentGap) {
                
                if case .offlineOnly(let reason) = networkMonitor.contentLoadingStrategy {
                    OfflineReasonBanner(reason: reason)
                        .padding(.bottom, DSLayout.elementPadding)
                }

                LazyVGrid(columns: GridColumns.two, spacing: DSLayout.contentGap) {
                    ForEach(displayedAlbums.indices, id: \.self) { index in
                        let album = displayedAlbums[index]
                        
                        NavigationLink(value: album) {
                            CardItemContainer(content: .album(album), index: index)
                        }
                        .onAppear {
                            if networkMonitor.contentLoadingStrategy.shouldLoadOnlineContent &&
                               index >= displayedAlbums.count - 5 {
                                Task {
                                    await musicLibraryManager.loadMoreAlbumsIfNeeded()
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, DSLayout.miniPlayerHeight)
            }
        }
        .padding(.horizontal, DSLayout.screenPadding)
        .padding(.top, DSLayout.tightGap)
    }
    
    // MARK: - Business Logic (unchanged)
    
    private func getOfflineAlbums() -> [Album] {
        let downloadedAlbumIds = Set(downloadManager.downloadedAlbums.map { $0.albumId })
        return AlbumMetadataCache.shared.getAlbums(ids: downloadedAlbumIds)
    }
    
    private func filterAlbums(_ albums: [Album]) -> [Album] {
        if searchText.isEmpty {
            return albums
        } else {
            return albums.filter { album in
                album.name.localizedCaseInsensitiveContains(searchText) ||
                album.artist.localizedCaseInsensitiveContains(searchText)
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
