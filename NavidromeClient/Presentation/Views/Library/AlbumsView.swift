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
    @State private var hasLoadedOnce = false  // <- Diese Zeile hinzufügen

    // Computed property für die anzuzeigenden Alben
    private var displayedAlbums: [Album] {
        let albums: [Album]
        
        if networkMonitor.isConnected && !offlineManager.isOfflineMode {
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
                            isOnline: networkMonitor.isConnected,
                            isOfflineMode: offlineManager.isOfflineMode
                        )
                        Spacer()
                    } else {
                        // Header UND Grid zusammen in ScrollView
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                AlbumsStatusHeader(
                                    isOnline: networkMonitor.isConnected,
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
                    .disabled(isLoading || (!networkMonitor.isConnected && !offlineManager.isOfflineMode))
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
            .onChange(of: networkMonitor.isConnected) { _, isConnected in
                if isConnected && !offlineManager.isOfflineMode {
                    Task { await loadAlbums() }
                }
            }
            .onChange(of: offlineManager.isOfflineMode) { _, _ in
                // Trigger UI refresh when offline mode changes
            }
            .accountToolbar()
        }
    }
    
    // Verfügbare Sortierungen basierend auf Online/Offline Status
    private var availableSortTypes: [SubsonicService.AlbumSortType] {
        if networkMonitor.isConnected && !offlineManager.isOfflineMode {
            return SubsonicService.AlbumSortType.allCases
        } else {
            // Offline nur lokale Sortierungen
            return [.alphabetical, .alphabeticalByArtist]
        }
    }
    
    private func loadAlbums() async {
        guard networkMonitor.isConnected && !offlineManager.isOfflineMode else { return }
        guard let service = navidromeVM.getService() else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let albums = try await service.getAllAlbums(sortBy: selectedSortType, size: 500)
            navidromeVM.albums = albums
            
            // Cache Album-Metadaten für Offline-Nutzung
            metadataCache.cacheAlbums(albums)
            
        } catch {
            print("❌ Failed to load albums: \(error)")
            navidromeVM.errorMessage = error.localizedDescription
        }
    }
}
