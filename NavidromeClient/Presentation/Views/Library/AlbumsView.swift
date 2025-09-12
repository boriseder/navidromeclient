import SwiftUI

struct AlbumsView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var coverArtService: ReactiveCoverArtService
    
    @State private var searchText = ""
    @State private var selectedSortType: SubsonicService.AlbumSortType = .alphabetical
    @State private var isLoading = false
    @State private var hasLoadedOnce = false

    private var displayedAlbums: [Album] {
        let albums: [Album]
        
        if networkMonitor.canLoadOnlineContent && !offlineManager.isOfflineMode {
            albums = navidromeVM.albums
        } else {
            let downloadedAlbumIds = Set(DownloadManager.shared.downloadedAlbums.map { $0.albumId })
            albums = AlbumMetadataCache.shared.getAlbums(ids: downloadedAlbumIds)
        }
        
        if searchText.isEmpty {
            return albums
        } else {
            return albums.filter { album in
                album.name.localizedCaseInsensitiveContains(searchText) ||
                album.artist.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private var availableSortTypes: [SubsonicService.AlbumSortType] {
        if networkMonitor.canLoadOnlineContent && !offlineManager.isOfflineMode {
            return SubsonicService.AlbumSortType.allCases
        } else {
            return [.alphabetical, .alphabeticalByArtist]
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                DynamicMusicBackground()
                
                VStack(spacing: 0) {
                    if isLoading {
                        Spacer()
                        loadingView()
                        Spacer()
                    } else if displayedAlbums.isEmpty {
                        Spacer()
                        AlbumsEmptyStateView(
                            isOnline: networkMonitor.canLoadOnlineContent,
                            isOfflineMode: offlineManager.isOfflineMode
                        )
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                AlbumsStatusHeader(
                                    isOnline: networkMonitor.canLoadOnlineContent,
                                    isOfflineMode: offlineManager.isOfflineMode,
                                    albumCount: displayedAlbums.count,
                                    onOfflineToggle: { offlineManager.toggleOfflineMode() }
                                )
                                
                                AlbumGridView(albums: displayedAlbums)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Albums")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, placement: .automatic, prompt: "Search albums...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(availableSortTypes, id: \.self) { sortType in
                            Button {
                                selectedSortType = sortType
                                Task { await loadAlbums() }
                            } label: {
                                HStack {
                                    Text(sortType.displayName)
                                    if selectedSortType == sortType {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: selectedSortType.icon)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task { await loadAlbums() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading || networkMonitor.shouldForceOfflineMode)
                }
            }
            .task {
                if !hasLoadedOnce {
                    await loadAlbums()
                    hasLoadedOnce = true
                }
            }
            .refreshable {
                await loadAlbums()
            }
            .onChange(of: networkMonitor.canLoadOnlineContent) { _, canLoad in
                if canLoad && !offlineManager.isOfflineMode {
                    Task { await loadAlbums() }
                } else if !canLoad {
                    offlineManager.switchToOfflineMode()
                }
            }
            .onChange(of: offlineManager.isOfflineMode) { _, _ in
                // Trigger UI refresh when offline mode changes
            }
            // FIX: Async preloading to avoid publishing during view updates
            .task(id: displayedAlbums.count) {
                // Only preload when album count changes, with delay
                if !displayedAlbums.isEmpty {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second delay
                    coverArtService.preloadVisibleAlbums(displayedAlbums)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .serverUnreachable)) { _ in
                offlineManager.switchToOfflineMode()
            }
            .accountToolbar()
        }
    }
    
    private func loadAlbums() async {
        guard networkMonitor.canLoadOnlineContent && !offlineManager.isOfflineMode else {
            await navidromeVM.loadOfflineAlbums()
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        await navidromeVM.loadAllAlbums(sortBy: selectedSortType)
    }
}
