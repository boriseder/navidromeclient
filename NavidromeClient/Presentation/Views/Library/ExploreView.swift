//
//  ExploreViewContent.swift - MIGRATED: Unified State System
//  NavidromeClient
//
//   UNIFIED: Single ContentLoadingStrategy for consistent state
//   CLEAN: Network checks handled by manager, not view
//   SEPARATION: View displays state, Manager handles business logic
//

import SwiftUI

struct ExploreViewContent: View {
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var coverArtManager: CoverArtManager
    @EnvironmentObject var exploreManager: ExploreManager
    
    @State private var hasAttemptedInitialLoad = false
    @State private var loadingCompleted = false

/*
 private var hasContent: Bool {
        let result: Bool
        
        switch networkMonitor.contentLoadingStrategy {
        case .online:
            result = hasOnlineContent
        case .offlineOnly:
            result = hasOfflineContent
        case .setupRequired:
            result = false
        }

        return result
    }
 */
    
    private var hasOnlineContent: Bool {
        let result = exploreManager.hasExploreViewData
        return result
    }

    private var hasOfflineContent: Bool {
        !offlineManager.offlineAlbums.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                
                if theme.backgroundStyle == .dynamic {
                    DynamicMusicBackground()
                }
                
                contentView
            }
            .task {
                guard !hasAttemptedInitialLoad else { return }
                hasAttemptedInitialLoad = true
                await setupHomeScreenData()
            }
            .task(priority: .background) {
                // Background preload when idle
                let allAlbums = exploreManager.recentAlbums +
                exploreManager.newestAlbums +
                exploreManager.frequentAlbums +
                exploreManager.randomAlbums
                
                if !allAlbums.isEmpty {
                    coverArtManager.preloadWhenIdle(Array(allAlbums.prefix(20)), context: .card)
                }
            }
            .navigationTitle("Explore & listen")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Album.self) { album in
                AlbumDetailViewContent(album: album)
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarColorScheme(
                theme.colorScheme,
                for: .navigationBar
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        // show refresh-button only when online
                        if networkMonitor.contentLoadingStrategy.shouldLoadOnlineContent {
                            Button {
                                Task { await refreshRandomAlbums() }
                            } label: {
                                Label("Refresh random albums", systemImage: "arrow.clockwise")
                            }
                            Divider()
                        }

                        // NavigationLink -> öffnet Settings
                        NavigationLink(destination: SettingsView()) {
                            Label("Settings", systemImage: "person.crop.circle.fill")
                        }
                        
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
            .refreshable {
                // Manager internally checks if online before loading
                await exploreManager.loadExploreData()
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DSLayout.contentGap) {
                                
                switch networkMonitor.contentLoadingStrategy {
                case .online:
                    onlineContent
                case .offlineOnly:
                    offlineContent
                case .setupRequired:
                    onlineContent
                        .overlay {
                            Text("Empty State: Setup required")
                        }
                }
            }
            .padding(.bottom, DSLayout.miniPlayerHeight)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, DSLayout.screenPadding)
    }

    private var onlineContent: some View {
        LazyVStack(spacing: DSLayout.elementGap) {
            
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
        }
    }
    
    private var offlineContent: some View {
        LazyVStack(alignment: .leading, spacing: DSLayout.screenGap) {
            
            OfflineWelcomeHeader(
                downloadedAlbums: downloadManager.downloadedAlbums.count,
                isConnected: networkMonitor.canLoadOnlineContent
            )
            
            if !offlineManager.offlineAlbums.isEmpty {
                ExploreSection(
                    title: "Downloaded Albums",
                    albums: Array(offlineManager.offlineAlbums.prefix(10)),
                    icon: "arrow.down.circle.fill",
                    accentColor: .green
                )
            }
        }
    }
    
    // MARK: - Business Logic
    
    /// No network check needed - manager handles it internally
    private func setupHomeScreenData() async {
        await exploreManager.loadExploreData()
    }
    
    /// Manager checks network state internally
    private func refreshRandomAlbums() async {
        await exploreManager.refreshRandomAlbums()
        // Use background idle preloading instead of immediate
        coverArtManager.preloadWhenIdle(exploreManager.randomAlbums, context: .card)
    }
}

// MARK: - ExploreSection

struct ExploreSection: View {
    @EnvironmentObject var theme: ThemeManager

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
                    .foregroundColor(theme.textColor)

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
                                .padding(.trailing, DSLayout.elementPadding)

                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(DSText.emphasized)
                                .foregroundColor(theme.textColor)
                                .padding(.trailing, DSLayout.elementPadding)
                        }
                    }
                    .disabled(isRefreshing)
                    .foregroundColor(accentColor)
                }
                else {
                    Image(systemName: "arrow.right")
                        .font(DSText.emphasized)
                        .foregroundColor(theme.textColor)
                        .padding(.trailing, DSLayout.elementPadding)
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
            .scrollIndicators(.hidden)
        }
        .padding(.top, DSLayout.sectionGap)
    }
}
