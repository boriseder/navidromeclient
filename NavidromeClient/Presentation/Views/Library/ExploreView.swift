//
//  ExploreViewContent.swift - DIRECT: Ohne UnifiedLibraryContainer
//  NavidromeClient
//
//   DIRECT: Alle Container durch direkte LazyVStack/LazyHStack ersetzt
//   CLEAN: Keine Container-Abstraktionen mehr
//

import SwiftUI

struct ExploreViewContent: View {
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var coverArtManager: CoverArtManager
    
    @StateObject private var exploreManager = ExploreManager.shared
    @State private var hasLoaded = false

    var body: some View {
        NavigationStack {
            ZStack {
                DynamicMusicBackground()
                
                VStack(alignment: .leading) {
                    if appConfig.isInitializingServices {
                        LoadingView(
                            title: "Setting up your music library...",
                            subtitle: "This may take a moment"
                        )
                    } else if networkMonitor.canLoadOnlineContent && !offlineManager.isOfflineMode {
                        onlineContent

                    } else {
                        offlineContent
                    }
                }
                .padding(.horizontal, DSLayout.screenPadding)
                .task(id: hasLoaded) {
                    guard !hasLoaded else { return }
                    await setupHomeScreenData()
                    hasLoaded = true
                }
                .refreshable {
                    await exploreManager.loadExploreData()
                    await preloadHomeScreenCovers()
                }
                .navigationDestination(for: Album.self) { album in
                    AlbumDetailViewContent(album: album)
                }
                .unifiedToolbar(exploreToolbarConfig)
            }
        }
        .overlay( DebugLines() )
    }
    
    private var onlineContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading) {
                WelcomeHeader(
                    username: appConfig.getCredentials()!.username,
                    nowPlaying: playerVM.currentSong
                )
                
                if !exploreManager.recentAlbums.isEmpty {
                    ExploreSection(
                        title: "Recently played",
                        albums: exploreManager.recentAlbums,
                        icon: "clock.fill",
                        accentColor: .orange
                    )
                }
                
                if !exploreManager.newestAlbums.isEmpty {
                    ExploreSection(
                        title: "Newly added",
                        albums: exploreManager.newestAlbums,
                        icon: "sparkles",
                        accentColor: .green
                    )
                }
                
                if !exploreManager.frequentAlbums.isEmpty {
                    ExploreSection(
                        title: "Often played",
                        albums: exploreManager.frequentAlbums,
                        icon: "chart.bar.fill",
                        accentColor: .purple
                    )
                }
                
                if !exploreManager.randomAlbums.isEmpty {
                    ExploreSection(
                        title: "Explore",
                        albums: exploreManager.randomAlbums,
                        icon: "dice.fill",
                        accentColor: .blue,
                        showRefreshButton: true,
                        refreshAction: { await refreshRandomAlbums() }
                    )
                }
                
                Color.clear.frame(height: DSLayout.miniPlayerHeight)
            }
            .padding(.top, DSLayout.elementGap)

        }
    }
    
    private var offlineContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DSLayout.screenGap) {
                OfflineWelcomeHeader(
                    downloadedAlbums: downloadManager.downloadedAlbums.count,
                    isConnected: networkMonitor.isConnected
                )
                
                if !offlineManager.offlineAlbums.isEmpty {
                    ExploreSection(
                        title: "Downloaded Albums",
                        albums: Array(offlineManager.offlineAlbums.prefix(10)),
                        icon: "arrow.down.circle.fill",
                        accentColor: .green
                    )
                }
                
                Color.clear.frame(height: DSLayout.miniPlayerHeight)
            }
        }
    }
    
    private func setupHomeScreenData() async {
        if networkMonitor.canLoadOnlineContent && !offlineManager.isOfflineMode {
            await exploreManager.loadExploreData()
            await preloadHomeScreenCovers()
        }
    }
    
    private func preloadHomeScreenCovers() async {
        let allAlbums = exploreManager.recentAlbums +
                       exploreManager.newestAlbums +
                       exploreManager.frequentAlbums +
                       exploreManager.randomAlbums
        
        await coverArtManager.preloadAlbums(Array(allAlbums.prefix(20)), size: 200)
    }
    
    private func refreshRandomAlbums() async {
        await exploreManager.refreshRandomAlbums()
        await coverArtManager.preloadAlbums(exploreManager.randomAlbums, size: 200)
    }
    
    private var exploreToolbarConfig: ToolbarConfiguration {
        .library(
            title: "Explore your music",
            isOffline: offlineManager.isOfflineMode,
            onRefresh: {
                await refreshRandomAlbums()
            },
            onToggleOffline: offlineManager.toggleOfflineMode
        )
    }
}

// MARK: - ExploreSection - Direct Implementation

struct ExploreSection: View {
    let title: String
    let albums: [Album]
    let icon: String
    let accentColor: Color
    var showRefreshButton: Bool = false
    var refreshAction: (() async -> Void)? = nil
    
    @State private var isRefreshing = false
    
    var body: some View {
        VStack(alignment: .leading) {
            // Section Header
            HStack {
                Label(title, systemImage: icon)
                    .font(DSText.prominent)
                    .foregroundColor(DSColor.primary)
                
                Spacer()
                
                if showRefreshButton, let refreshAction = refreshAction {
                    Button {
                        Task {
                            isRefreshing = true
                            await refreshAction()
                            isRefreshing = false
                        }
                    } label: {
                        if isRefreshing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .medium))
                        }
                    }
                    .disabled(isRefreshing)
                    .foregroundColor(accentColor)
                }
            }
            
            if albums.isEmpty {
                EmptyStateView(
                    type: .albums,
                    customTitle: "No Albums",
                    customMessage: "No albums available for \(title)"
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top) {
                        ForEach(albums.indices, id: \.self) { index in
                            let album = albums[index]
                            
                            NavigationLink(value: album) {
                                CardItemContainer(content: .album(album), index: index)
                            }
                        }
                    }
                }
            }
        }
        .padding(.top, DSLayout.sectionGap)

    }
}
