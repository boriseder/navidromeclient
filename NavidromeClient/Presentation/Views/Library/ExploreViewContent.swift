//
//  ExploreViewContent.swift - MIGRIERT: UnifiedLibraryContainer
//  NavidromeClient
//
//   MIGRIERT: ExploreSection nutzt jetzt UnifiedLibraryContainer für horizontal layout
//   CLEAN: Single Container-Pattern
//

import SwiftUI

struct ExploreViewContent: View {
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
                if networkMonitor.canLoadOnlineContent && !offlineManager.isOfflineMode {
                    onlineContent
                } else {
                    offlineContent
                }
            }
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
    
    private var onlineContent: some View {
        ScrollView {
            LazyVStack(spacing: DSLayout.screenGap) {
                WelcomeHeader(
                    username: "User",
                    nowPlaying: playerVM.currentSong
                )
                
                if !exploreManager.recentAlbums.isEmpty {
                    ExploreSectionMigrated(
                        title: "Recently played",
                        albums: exploreManager.recentAlbums,
                        icon: "clock.fill",
                        accentColor: .orange
                    )
                }
                
                if !exploreManager.newestAlbums.isEmpty {
                    ExploreSectionMigrated(
                        title: "Newly added",
                        albums: exploreManager.newestAlbums,
                        icon: "sparkles",
                        accentColor: .green
                    )
                }
                
                if !exploreManager.frequentAlbums.isEmpty {
                    ExploreSectionMigrated(
                        title: "Often played",
                        albums: exploreManager.frequentAlbums,
                        icon: "chart.bar.fill",
                        accentColor: .purple
                    )
                }
                
                if !exploreManager.randomAlbums.isEmpty {
                    ExploreSectionMigrated(
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
            LazyVStack(spacing: DSLayout.screenGap) {
                OfflineWelcomeHeader(
                    downloadedAlbums: downloadManager.downloadedAlbums.count,
                    isConnected: networkMonitor.isConnected
                )
                .screenPadding()
                
                if !offlineManager.offlineAlbums.isEmpty {
                    ExploreSectionMigrated(
                        title: "Downloaded Albums",
                        albums: Array(offlineManager.offlineAlbums.prefix(10)),
                        icon: "arrow.down.circle.fill",
                        accentColor: .green
                    )
                }
                
                Color.clear.frame(height: DSLayout.miniPlayerHeight)
            }
            .padding(.top, DSLayout.elementGap)
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

// MARK: - ✅ MIGRIERTE ExploreSection mit UnifiedLibraryContainer

struct ExploreSectionMigrated: View {
    let title: String
    let albums: [Album]
    let icon: String
    let accentColor: Color
    var showRefreshButton: Bool = false
    var refreshAction: (() async -> Void)? = nil
    
    @State private var isRefreshing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.contentGap) {
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
                        Image(systemName: "arrow.clockwise")
                            .font(DSText.sectionTitle)
                            .foregroundColor(accentColor)
                            .rotationEffect(isRefreshing ? .degrees(360) : .degrees(0))
                            .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                    }
                    .disabled(isRefreshing)
                }
            }
            .screenPadding()
            
            // ✅ MIGRIERT: UnifiedLibraryContainer für horizontal scroll
            UnifiedLibraryContainer(
                items: albums,
                isLoading: false,
                isEmpty: false,
                isOfflineMode: false,
                emptyStateType: .albums,
                layout: .horizontal
            ) { album, index in
                NavigationLink(value: album) {
                    CardItemContainer(content: .album(album), index: index)
                }
            }
        }
    }
}
