//
//  AlbumsView.swift - ELIMINATED LibraryViewModel
//  NavidromeClient
//
//  ✅ DIRECT: No unnecessary abstraction layer
//  ✅ CLEAN: Direct manager access for better performance
//

import SwiftUI

struct AlbumsView: View {
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
    
    // MARK: - ✅ DIRECT: Computed Properties
    
    private var displayedAlbums: [Album] {
        let sourceAlbums = getAlbumDataSource()
        return filterAlbums(sourceAlbums)
    }
    
    private var albumCount: Int {
        return displayedAlbums.count
    }
    
    private var isOfflineMode: Bool {
        return !networkMonitor.canLoadOnlineContent || offlineManager.isOfflineMode
    }
    
    private var canLoadOnlineContent: Bool {
        return networkMonitor.canLoadOnlineContent
    }
    
    private var shouldShowAlbumsLoading: Bool {
        return musicLibraryManager.isLoading && !musicLibraryManager.hasLoadedInitialData
    }
    
    private var shouldShowAlbumsEmptyState: Bool {
        return !musicLibraryManager.isLoading && displayedAlbums.isEmpty
    }
    
    private var isLoadingInBackground: Bool {
        return musicLibraryManager.isLoadingInBackground
    }
    
    private var backgroundLoadingProgress: String {
        return musicLibraryManager.backgroundLoadingProgress
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if shouldShowAlbumsLoading {
                    LoadingView()
                } else if shouldShowAlbumsEmptyState {
                    EmptyStateView.albums()
                } else {
                    albumsContentView
                }
            }
            .navigationTitle("Albums")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $searchText,
                placement: .automatic,
                prompt: "Search albums..."
            )
            .onChange(of: searchText) { _, _ in
                handleSearchTextChange()
            }
            .toolbar {
                albumsToolbarContent
            }
            .refreshable {
                await refreshAllData()
            }
            .task(id: displayedAlbums.count) {
                await preloadAlbumImages()
            }
            .accountToolbar()
        }
    }
    
    // MARK: - ✅ DIRECT: Data Source Logic
    
    private func getAlbumDataSource() -> [Album] {
        if canLoadOnlineContent && !isOfflineMode {
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
    
    // MARK: - ✅ DIRECT: Actions
    
    private func refreshAllData() async {
        await musicLibraryManager.refreshAllData()
    }
    
    private func loadAlbums(sortBy: ContentService.AlbumSortType) async {
        selectedAlbumSort = sortBy
        await musicLibraryManager.loadAlbumsProgressively(sortBy: sortBy, reset: true)
    }
    
    private func loadMoreAlbumsIfNeeded() async {
        await musicLibraryManager.loadMoreAlbumsIfNeeded()
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
    
    // MARK: - ✅ UI Components (unchanged)
    
    private var albumsLoadingView: some View {
        VStack(spacing: 16) {
            LoadingView()
            
            if isLoadingInBackground {
                Text(backgroundLoadingProgress)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
       
    private var albumsContentView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if isOfflineMode || !canLoadOnlineContent {
                    LibraryStatusHeader(
                        itemType: .albums,
                        count: albumCount,
                        isOnline: canLoadOnlineContent,
                        isOfflineMode: isOfflineMode
                    )
                }
                
                AlbumGridView(albums: displayedAlbums)
            }
        }
    }
    
    @ToolbarContentBuilder
    private var albumsToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            albumSortMenu
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            offlineModeToggle
        }
        
        ToolbarItem(placement: .navigationBarLeading) {
            refreshButton
        }
    }
    
    private var albumSortMenu: some View {
        Menu {
            ForEach(ContentService.AlbumSortType.allCases, id: \.self) { sortType in
                Button {
                    Task {
                        await loadAlbums(sortBy: sortType)
                    }
                } label: {
                    HStack {
                        Text(sortType.displayName)
                        if selectedAlbumSort == sortType {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: selectedAlbumSort.icon)
        }
    }
    
    private var offlineModeToggle: some View {
        Button {
            toggleOfflineMode()
        } label: {
            HStack(spacing: DSLayout.tightGap) {
                Image(systemName: isOfflineMode ? "icloud.slash" : "icloud")
                    .font(DSText.metadata)
                Text(isOfflineMode ? "Offline" : "All")
                    .font(DSText.metadata)
            }
            .foregroundStyle(isOfflineMode ? DSColor.warning : DSColor.accent)
            .padding(.horizontal, DSLayout.elementPadding)
            .padding(.vertical, DSLayout.tightPadding)
            .background(
                Capsule()
                    .fill((isOfflineMode ? DSColor.warning : DSColor.accent).opacity(0.1))
            )
        }
    }
    
    private var refreshButton: some View {
        Button {
            Task {
                await refreshAllData()
            }
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .disabled(isLoadingInBackground)
    }
}

// MARK: - ✅ Reusable AlbumGridView (unchanged)

struct AlbumGridView: View {
    let albums: [Album]
    
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var musicLibraryManager: MusicLibraryManager

    var body: some View {
        ScrollView {
            albumsGrid
                .screenPadding()
                .padding(.bottom, 100)
        }
    }
    
    private var albumsGrid: some View {
        LazyVGrid(columns: GridColumns.two, spacing: DSLayout.sectionGap) {
            ForEach(albums.indices, id: \.self) { index in
                let album = albums[index]
                NavigationLink {
                    AlbumDetailView(album: album)
                } label: {
                    AlbumCard(album: album, accentColor: .primary, index: index)
                }
                .onAppear {
                    if index == albums.count - 5 {
                        Task { await musicLibraryManager.loadMoreAlbumsIfNeeded() }
                    }
                }
            }
        }
    }
}
