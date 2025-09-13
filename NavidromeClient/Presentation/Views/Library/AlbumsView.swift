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

    private func getDisplayedAlbums() -> [Album] {
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
                let nameMatches = album.name.localizedCaseInsensitiveContains(searchText)
                let artistMatches = album.artist.localizedCaseInsensitiveContains(searchText)
                return nameMatches || artistMatches
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
            Group {
                VStack(spacing: 0) {
                    if isLoading {
                        Spacer()
                        loadingView()
                        Spacer()
                    } else if getDisplayedAlbums().isEmpty {
                        Spacer()
                        AlbumsEmptyStateView(
                            isOnline: networkMonitor.canLoadOnlineContent,
                            isOfflineMode: offlineManager.isOfflineMode
                        )
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                AlbumGridView(albums: getDisplayedAlbums())
                            }
                        }
                    }
                }
            }
            .navigationTitle("Albums")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, placement: .automatic, prompt: "Search albums...")
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
            .task(id: getDisplayedAlbums().count) {
                // Only preload when album count changes, with delay
                let albums = getDisplayedAlbums()
                if !albums.isEmpty {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second delay
                    coverArtService.preloadVisibleAlbums(albums)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .serverUnreachable)) { _ in
                offlineManager.switchToOfflineMode()
            }
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
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    OfflineModeToggle()
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task {
                            await loadAlbums()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(navidromeVM.isLoading || networkMonitor.shouldForceOfflineMode)
                }
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
