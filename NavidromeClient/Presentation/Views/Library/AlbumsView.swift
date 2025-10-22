//
//  AlbumsViewContent.swift - FIXED: Filter & Download Button & Preloading Context
//  NavidromeClient
//
//   FIXED: Filter logic now works correctly with all albums
//   FIXED: Download button state reactivity restored
//   FIXED: Preloading uses correct context matching displayed images
//

import SwiftUI

struct AlbumsViewContent: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var coverArtManager: CoverArtManager
    @EnvironmentObject var musicLibraryManager: MusicLibraryManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var downloadManager: DownloadManager
    
    @State private var searchText = ""
    @State private var selectedAlbumSort: ContentService.AlbumSortType = .alphabetical
    @State private var showOnlyDownloaded = false
    @StateObject private var debouncer = Debouncer()
    
    // MARK: - Filter Logic
    
    private var displayedAlbums: [Album] {
        // Step 1: Get base albums based on strategy
        let baseAlbums: [Album]
        
        switch networkMonitor.contentLoadingStrategy {
        case .online:
            baseAlbums = musicLibraryManager.albums
        case .offlineOnly:
            baseAlbums = offlineManager.offlineAlbums
        case .setupRequired:
            baseAlbums = []
        }
        
        // Step 2: Apply download filter if enabled (only in online mode)
        let filteredAlbums: [Album]
        if showOnlyDownloaded && networkMonitor.contentLoadingStrategy.shouldLoadOnlineContent {
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
        // CHECK FOR SETUP REQUIRED FIRST
        if !appConfig.isConfigured {
            return .setupRequired
        } else if appConfig.isInitializingServices {
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
                
                if theme.backgroundStyle == .dynamic {
                    DynamicMusicBackground()
                }
                
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
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Album.self) { album in
                AlbumDetailViewContent(album: album)
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarColorScheme(
                theme.colorScheme,
                for: .navigationBar
            )
            .searchable(text: $searchText, prompt: "Search albums...")
            .refreshable {
                guard networkMonitor.contentLoadingStrategy.shouldLoadOnlineContent else { return }
                await refreshAllData()
            }
            .onChange(of: searchText) { _, _ in
                handleSearchTextChange()
            }
            .onAppear {
                if !displayedAlbums.isEmpty {
                    // FIXED: Use .card context to match CardItemContainer display
                    coverArtManager.preloadWhenIdle(Array(displayedAlbums.prefix(20)), context: .card)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    
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
                        Divider()
                        Text("Filter")
                            .font(DSText.emphasized)
                            .foregroundColor(.secondary)
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
                        Divider()
                        NavigationLink(destination: SettingsView()) {
                            Label("Settings", systemImage: "gear")
                        }


                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DSLayout.elementGap) {
                
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
        .scrollIndicators(.hidden)
        .padding(.horizontal, DSLayout.screenPadding)
    }
    
    // MARK: - Business Logic
    
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
