//
//  ArtistsView.swift - Enhanced with Design System
//  NavidromeClient
//
//  ✅ ENHANCED: Vollständige Anwendung des Design Systems
//

import SwiftUI

struct ArtistsView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var downloadManager: DownloadManager
    
    @State private var searchText = ""
    @State private var hasLoadedOnce = false
    
    var body: some View {
        NavigationStack {
            Group {
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
            }
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
            artists = navidromeVM.artists
        } else {
            artists = getOfflineArtists()
        }
        
        if searchText.isEmpty {
            return artists.sorted(by: { $0.name < $1.name })
        } else {
            return artists
                .filter { $0.name.localizedCaseInsensitiveContains(searchText) }
                .sorted(by: { $0.name < $1.name })
        }
    }
    
    private func getOfflineArtists() -> [Artist] {
        let downloadedAlbums = downloadManager.downloadedAlbums
        let albumIds = Set(downloadedAlbums.map { $0.albumId })
        let cachedAlbums = AlbumMetadataCache.shared.getAlbums(ids: albumIds)
        
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
            LazyVStack(spacing: Spacing.s) {
                if !networkMonitor.canLoadOnlineContent || offlineManager.isOfflineMode {
                    ArtistsStatusHeader(
                        isOnline: networkMonitor.canLoadOnlineContent,
                        isOfflineMode: offlineManager.isOfflineMode,
                        artistCount: filteredArtists.count
                    )
                }
                
                ForEach(filteredArtists.indices, id: \.self) { index in
                    let artist = filteredArtists[index]
                    NavigationLink(value: artist) {
                        ArtistCard(artist: artist, index: index)
                    }
                }
            }
            .screenPadding()
            .padding(.bottom, Sizes.miniPlayer) // Using DS value
        }
    }

    private func loadArtists() async {
        if networkMonitor.canLoadOnlineContent && !offlineManager.isOfflineMode {
            await navidromeVM.loadArtistsWithOfflineSupport()
        }
    }
}

// MARK: - Artists Empty State View (Enhanced with DS)
struct ArtistsEmptyStateView: View {
    let isOnline: Bool
    let isOfflineMode: Bool
    
    var body: some View {
        VStack(spacing: Spacing.l) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 60)) // Approx. DS applied
                .foregroundStyle(TextColor.secondary)
            
            VStack(spacing: Spacing.s) {
                Text(emptyStateTitle)
                    .font(Typography.title2)
                
                Text(emptyStateMessage)
                    .font(Typography.subheadline)
                    .foregroundStyle(TextColor.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if !isOnline && !isOfflineMode {
                Button("Switch to Downloaded Music") {
                    OfflineManager.shared.switchToOfflineMode()
                }
                .primaryButtonStyle()
            }
        }
        .padding(Padding.xl)
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

// MARK: - Artists Status Header (Enhanced with DS)
struct ArtistsStatusHeader: View {
    let isOnline: Bool
    let isOfflineMode: Bool
    let artistCount: Int
    
    var body: some View {
        HStack {
            NetworkStatusIndicator()
            
            Spacer()
            
            Text("\(artistCount) Artists")
                .font(Typography.caption)
                .foregroundStyle(TextColor.secondary)
            
            Spacer()
            
            if isOnline {
                OfflineModeToggle()
            }
        }
        .listItemPadding()
        .glassCardStyle()
        .screenPadding()
        .padding(.bottom, Spacing.s)
    }
}
