//
//  ExploreViewContent.swift - MIGRATED: Unified State System
//  NavidromeClient
//
//   UNIFIED: Single ContentLoadingStrategy for consistent state
//   CLEAN: Proper offline content handling
//   FIXED: Consistent state management pattern
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

    // UNIFIED: Single state logic following the pattern
    private var hasOnlineContent: Bool {
        exploreManager.hasHomeScreenData
    }
    
    private var hasOfflineContent: Bool {
        !offlineManager.offlineAlbums.isEmpty
    }
    
    private var hasContent: Bool {
        switch networkMonitor.contentLoadingStrategy {
        case .online:
            return hasOnlineContent
        case .offlineOnly:
            return hasOfflineContent
        }
    }
    
    private var currentState: ViewState? {
        if appConfig.isInitializingServices {
            return .loading("Setting up your music library")
        } else if exploreManager.isLoadingExploreData && !hasContent {
            return .loading("Loading your music")
        } else if !hasContent && !exploreManager.isLoadingExploreData && hasLoaded {
            return .empty(type: .albums)
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DynamicMusicBackground()
                    .ignoresSafeArea()
                
                // UNIFIED: Single component handles all states
                if let state = currentState {
                    UnifiedStateView(
                        state: state,
                        primaryAction: StateAction("Refresh") {
                            Task {
                                guard networkMonitor.contentLoadingStrategy.shouldLoadOnlineContent else { return }
                                await exploreManager.loadExploreData()
                            }
                        }
                    )
                } else {
                    contentView
                }
            }
            .navigationTitle("Explore your music")
            .task(id: hasLoaded) {
                guard !hasLoaded else { return }
                await setupHomeScreenData()
                hasLoaded = true
            }
            .task(priority: .background) {
                // Background preload when idle
                let allAlbums = exploreManager.recentAlbums +
                               exploreManager.newestAlbums +
                               exploreManager.frequentAlbums +
                               exploreManager.randomAlbums
                
                if !allAlbums.isEmpty {
                    coverArtManager.preloadWhenIdle(Array(allAlbums.prefix(20)), size: 200)
                }
            }
            .refreshable {
                guard networkMonitor.contentLoadingStrategy.shouldLoadOnlineContent else { return }
                await exploreManager.loadExploreData()
            }
            .navigationDestination(for: Album.self) { album in
                AlbumDetailViewContent(album: album)
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            LazyVStack(alignment: .leading) {
                // UNIFIED: Consistent offline banner pattern
                if case .offlineOnly(let reason) = networkMonitor.contentLoadingStrategy {
                    OfflineReasonBanner(reason: reason)
                        .padding(.horizontal, DSLayout.screenPadding)
                }
                
                switch networkMonitor.contentLoadingStrategy {
                case .online:
                    onlineContent
                case .offlineOnly:
                    offlineContent
                }
            }
            .padding(.top, DSLayout.elementGap)
        }
    }

    private var onlineContent: some View {
        LazyVStack(alignment: .leading) {
            WelcomeHeader(
                username: appConfig.getCredentials()?.username ?? "User",
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
        .padding(.horizontal, DSLayout.screenPadding)
    }
    
    private var offlineContent: some View {
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
        .padding(.horizontal, DSLayout.screenPadding)
    }
    
    // MARK: - Business Logic (unchanged)
    
    private func setupHomeScreenData() async {
        if networkMonitor.contentLoadingStrategy.shouldLoadOnlineContent {
            await exploreManager.loadExploreData()
        }
    }
        
    private func refreshRandomAlbums() async {
        await exploreManager.refreshRandomAlbums()
        // Use background idle preloading instead of immediate
        coverArtManager.preloadWhenIdle(exploreManager.randomAlbums, size: 200)
    }
}

// MARK: - ExploreSection (unchanged)

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
            HStack {
                Label(title, systemImage: icon)
                    .font(DSText.prominent)
                    .foregroundColor(DSColor.onDark)
                
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
        .padding(.top, DSLayout.sectionGap)
    }
}
