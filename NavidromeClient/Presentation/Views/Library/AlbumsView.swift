//
//  AlbumsViewContent.swift - FIXED: Filter & Download Button
//  NavidromeClient
//
//   FIXED: Filter logic now works correctly with all albums
//   FIXED: Download button state reactivity restored
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
    @State private var showOnlyDownloaded = false
    @StateObject private var debouncer = Debouncer()
    
    // MARK: - FIXED: Complete Filter Logic
    
    private var displayedAlbums: [Album] {
        // Step 1: Get base albums (respect network state)
        let baseAlbums = switch networkMonitor.contentLoadingStrategy {
        case .online:
            musicLibraryManager.albums
        case .offlineOnly:
            getOfflineAlbums()
        }
        
        // Step 2: Apply download filter if enabled
        let filteredAlbums: [Album]
        if showOnlyDownloaded {
            let downloadedIds = Set(downloadManager.downloadedAlbums.map { $0.albumId })
            filteredAlbums = baseAlbums.filter { downloadedIds.contains($0.id) }
        } else {
            filteredAlbums = baseAlbums
        }
        
        // Step 3: Apply search filter if needed
        if searchText.isEmpty {
            return filteredAlbums
        } else {
            return filteredAlbums.filter { album in
                album.name.localizedCaseInsensitiveContains(searchText) ||
                album.artist.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private var currentState: ViewState? {
        if appConfig.isInitializingServices {
            return .loading("Setting up your music library")
        } else if musicLibraryManager.isLoading && displayedAlbums.isEmpty {
            return .loading("Loading albums")
        } else if displayedAlbums.isEmpty && musicLibraryManager.hasLoadedInitialData {
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
            .navigationBarTitleDisplayMode(.automatic)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .searchable(text: $searchText, prompt: "Search albums...")
            .refreshable {
                guard networkMonitor.contentLoadingStrategy.shouldLoadOnlineContent else { return }
                await refreshAllData()
            }
            .onChange(of: searchText) { _, _ in
                handleSearchTextChange()
            }
            .task(priority: .background) {
                if !displayedAlbums.isEmpty {
                    coverArtManager.preloadWhenIdle(Array(displayedAlbums.prefix(20)), size: 200)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Filter Menu
                    Menu {
                        Button {
                            showOnlyDownloaded = false
                        } label: {
                            HStack {
                                Image(systemName: "music.note.house")
                                Text("All Albums")
                                Spacer()
                                if !showOnlyDownloaded {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        
                        if downloadManager.downloadedAlbums.count > 0 {
                            Button {
                                showOnlyDownloaded = true
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.down.circle.fill")
                                    Text("Downloaded Only (\(downloadManager.downloadedAlbums.count))")
                                    Spacer()
                                    if showOnlyDownloaded {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: showOnlyDownloaded ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .foregroundColor(.white)
                    }
                    
                    // Sort Menu
                    Menu {
                        ForEach(ContentService.AlbumSortType.allCases, id: \.self) { sortType in
                            Button {
                                Task {
                                    await loadAlbums(sortBy: sortType)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: sortType.icon)
                                    Text(sortType.displayName)
                                    Spacer()
                                    if selectedAlbumSort == sortType {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundColor(.white)
                    }
                    
                    // Settings Menu
                    Menu {
                        NavigationLink(destination: SettingsView()) {
                            Label("Settings", systemImage: "gear")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.white)
                    }
                }
            }
            .navigationDestination(for: Album.self) { album in
                AlbumDetailViewContent(album: album)
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DSLayout.elementGap) {

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
    }
    
    // MARK: - Business Logic
    
    private func getOfflineAlbums() -> [Album] {
        let downloadedAlbumIds = Set(downloadManager.downloadedAlbums.map { $0.albumId })
        return AlbumMetadataCache.shared.getAlbums(ids: downloadedAlbumIds)
    }
    
    private func refreshAllData() async {
        await musicLibraryManager.refreshAllData()
    }
    
    private func loadAlbums(sortBy: ContentService.AlbumSortType) async {
        selectedAlbumSort = sortBy
        await musicLibraryManager.loadAlbumsProgressively(sortBy: sortBy, reset: true)
    }
    
    private func handleSearchTextChange() {
        debouncer.debounce {
            // Search filtering happens automatically via computed property
        }
    }
}
