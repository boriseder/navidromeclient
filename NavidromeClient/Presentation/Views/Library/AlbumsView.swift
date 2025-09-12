import SwiftUI

struct AlbumsView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var offlineManager = OfflineManager.shared
    @StateObject private var metadataCache = AlbumMetadataCache.shared
    
    @State private var searchText = ""
    @State private var selectedSortType: SubsonicService.AlbumSortType = .alphabetical
    @State private var isLoading = false
    @State private var hasLoadedOnce = false

    // FIX: Enhanced computed property using canLoadOnlineContent
    private var displayedAlbums: [Album] {
        let albums: [Album]
        
        if networkMonitor.canLoadOnlineContent && !offlineManager.isOfflineMode {
            // Online: Zeige alle geladenen Alben
            albums = navidromeVM.albums
        } else {
            // Offline: Zeige nur heruntergeladene Alben
            let downloadedAlbumIds = Set(DownloadManager.shared.downloadedAlbums.map { $0.albumId })
            albums = metadataCache.getAlbums(ids: downloadedAlbumIds)
        }
        
        // Filtere nach Suchtext
        if searchText.isEmpty {
            return albums
        } else {
            return albums.filter { album in
                album.name.localizedCaseInsensitiveContains(searchText) ||
                album.artist.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // FIX: Enhanced availableSortTypes using canLoadOnlineContent
    private var availableSortTypes: [SubsonicService.AlbumSortType] {
        if networkMonitor.canLoadOnlineContent && !offlineManager.isOfflineMode {
            return SubsonicService.AlbumSortType.allCases
        } else {
            // Offline nur lokale Sortierungen
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
                            isOnline: networkMonitor.canLoadOnlineContent, // FIX: Use canLoadOnlineContent
                            isOfflineMode: offlineManager.isOfflineMode
                        )
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                AlbumsStatusHeader(
                                    isOnline: networkMonitor.canLoadOnlineContent, // FIX: Use canLoadOnlineContent
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
                    .disabled(isLoading || networkMonitor.shouldForceOfflineMode) // FIX: Use shouldForceOfflineMode
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
            // FIX: Listen to server reachability changes
            .onChange(of: networkMonitor.canLoadOnlineContent) { _, canLoad in
                if canLoad && !offlineManager.isOfflineMode {
                    Task { await loadAlbums() }
                } else if !canLoad {
                    // Auto-switch to offline mode when server becomes unreachable
                    offlineManager.switchToOfflineMode()
                }
            }
            .onChange(of: offlineManager.isOfflineMode) { _, _ in
                // Trigger UI refresh when offline mode changes
            }
            // FIX: Listen to server unreachable notifications
            .onReceive(NotificationCenter.default.publisher(for: .serverUnreachable)) { _ in
                offlineManager.switchToOfflineMode()
            }
            .accountToolbar()
        }
    }
    
    private func loadAlbums() async {
        // FIX: Use enhanced method with auto-fallback
        guard networkMonitor.canLoadOnlineContent && !offlineManager.isOfflineMode else {
            // Load from offline cache immediately
            await navidromeVM.loadOfflineAlbums()
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        // This will now auto-fallback to offline if server is unreachable
        await navidromeVM.loadAllAlbums(sortBy: selectedSortType)
    }
}
