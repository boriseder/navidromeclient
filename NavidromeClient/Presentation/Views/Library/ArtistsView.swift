import SwiftUI

struct ArtistsView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var offlineManager = OfflineManager.shared
    
    @State private var searchText = ""
    @State private var hasLoadedOnce = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                DynamicMusicBackground()
                
                if navidromeVM.isLoading {
                    loadingView()
                } else if filteredArtists.isEmpty {
                    ArtistsEmptyStateView(
                        isOnline: networkMonitor.canLoadOnlineContent,
                        isOfflineMode: offlineManager.isOfflineMode
                    )
                } else {
                    mainContent
                }
            }
            .navigationTitle("Artists")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $searchText, placement: .automatic, prompt: "Search artists...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    OfflineModeToggle()
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task { await loadArtists() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(navidromeVM.isLoading || networkMonitor.shouldForceOfflineMode)
                }
            }
            .task {
                if !hasLoadedOnce {
                    await loadArtists()
                    hasLoadedOnce = true
                }
            }
            .refreshable {
                await loadArtists()
                hasLoadedOnce = true
            }
            .navigationDestination(for: Artist.self) { artist in
                ArtistDetailView(context: .artist(artist))
                    .environmentObject(navidromeVM)
                    .environmentObject(playerVM)
            }
            // Enhanced network monitoring
            .onChange(of: networkMonitor.canLoadOnlineContent) { _, canLoad in
                if !canLoad {
                    offlineManager.switchToOfflineMode()
                } else if canLoad && !offlineManager.isOfflineMode {
                    Task { await loadArtists() }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .serverUnreachable)) { _ in
                offlineManager.switchToOfflineMode()
            }
            .accountToolbar()
        }
    }

    private var filteredArtists: [Artist] {
        let artists: [Artist]
        
        if networkMonitor.canLoadOnlineContent && !offlineManager.isOfflineMode {
            // Online: Use loaded artists
            artists = navidromeVM.artists
        } else {
            // Offline: Load from offline cache
            artists = getOfflineArtists()
        }
        
        // Filter by search text
        if searchText.isEmpty {
            return artists.sorted(by: { $0.name < $1.name })
        } else {
            return artists
                .filter { $0.name.localizedCaseInsensitiveContains(searchText) }
                .sorted(by: { $0.name < $1.name })
        }
    }
    
    private func getOfflineArtists() -> [Artist] {
        let downloadedAlbums = DownloadManager.shared.downloadedAlbums
        let albumIds = Set(downloadedAlbums.map { $0.albumId })
        let cachedAlbums = AlbumMetadataCache.shared.getAlbums(ids: albumIds)
        
        // Extract unique artists
        let uniqueArtists = Set(cachedAlbums.map { $0.artist })
        return uniqueArtists.compactMap { artistName in
            Artist(
                id: artistName.replacingOccurrences(of: " ", with: "_"),
                name: artistName,
                coverArt: nil,
                albumCount: cachedAlbums.filter { $0.artist == artistName }.count,
                artistImageUrl: nil
            )
        }
    }

    private var mainContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Status header
                if !networkMonitor.canLoadOnlineContent || offlineManager.isOfflineMode {
                    ArtistsStatusHeader(
                        isOnline: networkMonitor.canLoadOnlineContent,
                        isOfflineMode: offlineManager.isOfflineMode,
                        artistCount: filteredArtists.count
                    )
                }
                
                ForEach(Array(filteredArtists.enumerated()), id: \.element.id) { index, artist in
                    NavigationLink(value: artist) {
                        ArtistCard(artist: artist, index: index)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 90)
        }
    }

    // Enhanced loading method
    private func loadArtists() async {
        if networkMonitor.canLoadOnlineContent && !offlineManager.isOfflineMode {
            await navidromeVM.loadArtistsWithOfflineSupport()
        }
        // If offline, filteredArtists will automatically show cached data
    }
}

// MARK: - Artists Empty State View
struct ArtistsEmptyStateView: View {
    let isOnline: Bool
    let isOfflineMode: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text(emptyStateTitle)
                    .font(.title2.weight(.semibold))
                
                Text(emptyStateMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if !isOnline && !isOfflineMode {
                Button("Switch to Downloaded Music") {
                    OfflineManager.shared.switchToOfflineMode()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(40)
    }
    
    private var emptyStateIcon: String {
        if !isOnline {
            return "wifi.slash"
        } else if isOfflineMode {
            return "person.2.slash"
        } else {
            return "person.2"
        }
    }
    
    private var emptyStateTitle: String {
        if !isOnline {
            return "No Connection"
        } else if isOfflineMode {
            return "No Offline Artists"
        } else {
            return "No Artists Found"
        }
    }
    
    private var emptyStateMessage: String {
        if !isOnline {
            return "Connect to WiFi or cellular to browse your artists"
        } else if isOfflineMode {
            return "Download some albums to see artists offline"
        } else {
            return "Your music library appears to have no artists"
        }
    }
}

// MARK: - Artists Status Header
struct ArtistsStatusHeader: View {
    let isOnline: Bool
    let isOfflineMode: Bool
    let artistCount: Int
    
    var body: some View {
        HStack {
            NetworkStatusIndicator()
            
            Spacer()
            
            Text("\(artistCount) Artists")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            if isOnline {
                OfflineModeToggle()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

