//
//  ExploreView.swift - REFACTORED to Pure UI
//  NavidromeClient
//
//  ✅ CLEAN: All business logic moved to HomeScreenManager
//  ✅ ELIMINATES: ExploreViewModel dependency completely
//

import SwiftUI

struct ExploreView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var coverArtManager: CoverArtManager
    
    // ✅ NEW: Single source of truth for home screen data
    @StateObject private var homeScreenManager = HomeScreenManager.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                if networkMonitor.canLoadOnlineContent && !offlineManager.isOfflineMode {
                    onlineContent
                } else {
                    offlineContent
                }
            }
            .navigationTitle("Music")
            .navigationBarTitleDisplayMode(.large)
            .task {
                // ✅ SINGLE LINE: Manager handles all complexity
                await setupHomeScreenData()
            }
            .refreshable {
                // ✅ SINGLE LINE: Manager handles refresh logic
                await homeScreenManager.loadHomeScreenData()
                await preloadHomeScreenCovers()
            }
            .onChange(of: networkMonitor.canLoadOnlineContent) { _, canLoad in
                if canLoad && !offlineManager.isOfflineMode {
                    Task {
                        await homeScreenManager.handleNetworkChange(isOnline: true)
                        await preloadHomeScreenCovers()
                    }
                }
            }
            .onChange(of: offlineManager.isOfflineMode) { _, isOffline in
                if !isOffline && networkMonitor.canLoadOnlineContent {
                    Task {
                        await homeScreenManager.loadHomeScreenData()
                        await preloadHomeScreenCovers()
                    }
                }
            }
            .accountToolbar()
        }
    }
    
    // MARK: - ✅ Setup & Configuration
    
    private func setupHomeScreenData() async {
        // Configure manager with service
        if let service = navidromeVM.getService() {
            homeScreenManager.configure(service: service)
        }
        
        // Load data if online
        if networkMonitor.canLoadOnlineContent && !offlineManager.isOfflineMode {
            await homeScreenManager.loadHomeScreenData()
            await preloadHomeScreenCovers()
        }
    }
    
    // ✅ REACTIVE: Uses manager data directly
    private func preloadHomeScreenCovers() async {
        let allAlbums = homeScreenManager.recentAlbums +
                       homeScreenManager.newestAlbums +
                       homeScreenManager.frequentAlbums +
                       homeScreenManager.randomAlbums
        
        await coverArtManager.preloadAlbums(Array(allAlbums.prefix(20)), size: 200)
    }
    
    // MARK: - ✅ Pure UI Content
    
    private var onlineContent: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.xl) {
                WelcomeHeader(
                    username: AppConfig.shared.getCredentials()?.username ?? "User",
                    nowPlaying: playerVM.currentSong
                )
                
                Group {
                    // ✅ REACTIVE: Direct access to manager data
                    if !homeScreenManager.recentAlbums.isEmpty {
                        AlbumSection(
                            title: "Recently played",
                            albums: homeScreenManager.recentAlbums,
                            icon: "clock.fill",
                            accentColor: .orange
                        )
                    }
                    
                    if !homeScreenManager.newestAlbums.isEmpty {
                        AlbumSection(
                            title: "Newly added",
                            albums: homeScreenManager.newestAlbums,
                            icon: "sparkles",
                            accentColor: .green
                        )
                    }
                    
                    if !homeScreenManager.frequentAlbums.isEmpty {
                        AlbumSection(
                            title: "Often played",
                            albums: homeScreenManager.frequentAlbums,
                            icon: "chart.bar.fill",
                            accentColor: .purple
                        )
                    }
                    
                    if !homeScreenManager.randomAlbums.isEmpty {
                        AlbumSection(
                            title: "Explore",
                            albums: homeScreenManager.randomAlbums,
                            icon: "dice.fill",
                            accentColor: .blue,
                            showRefreshButton: true,
                            refreshAction: {
                                await refreshRandomAlbums()
                            }
                        )
                    }
                }
                
                Group {
                    // ✅ REACTIVE: Manager state
                    if homeScreenManager.isLoadingHomeData {
                        loadingView()
                    }
                    
                    if let errorMessage = homeScreenManager.homeDataError {
                        ErrorSection(message: errorMessage)
                    }
                }
                
                Color.clear.frame(height: Sizes.miniPlayer)
            }
            .padding(.top, Spacing.s)
        }
    }
    
    private var offlineContent: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.xl) {
                OfflineWelcomeHeader(
                    downloadedAlbums: downloadManager.downloadedAlbums.count,
                    isConnected: networkMonitor.isConnected
                )
                .screenPadding()
                
                if !offlineManager.offlineAlbums.isEmpty {
                    AlbumSection(
                        title: "Downloaded Albums",
                        albums: Array(offlineManager.offlineAlbums.prefix(10)),
                        icon: "arrow.down.circle.fill",
                        accentColor: .green
                    )
                }
                
                NavigationLink(destination: AlbumsView()) {
                    QuickAccessCard(
                        title: "View All Downloads",
                        subtitle: "\(downloadManager.downloadedAlbums.count) albums available offline",
                        icon: "folder.fill",
                        color: .blue
                    )
                }
                .screenPadding()
                
                StorageInfoCard(
                    totalSize: downloadManager.totalDownloadSize(),
                    albumCount: downloadManager.downloadedAlbums.count
                )
                .screenPadding()
                
                if !networkMonitor.isConnected {
                    NetworkStatusCard()
                        .screenPadding()
                }
                
                Color.clear.frame(height: Sizes.miniPlayer)
            }
            .padding(.top, Spacing.s)
        }
    }
    
    // ✅ SINGLE LINE: Manager handles refresh logic
    private func refreshRandomAlbums() async {
        await homeScreenManager.refreshRandomAlbums()
        await coverArtManager.preloadAlbums(homeScreenManager.randomAlbums, size: 200)
    }
}

// MARK: - Existing Components (unchanged but kept for completeness)

struct OfflineWelcomeHeader: View {
    let downloadedAlbums: Int
    let isConnected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Offline Music")
                        .font(Typography.title2)
                        .foregroundColor(TextColor.primary)
                    
                    Text(statusText)
                        .font(Typography.subheadline)
                        .foregroundColor(TextColor.secondary)
                }
                
                Spacer()
                
                VStack(spacing: Spacing.xs) {
                    Image(systemName: isConnected ? "wifi" : "wifi.slash")
                        .font(Typography.title3)
                        .foregroundColor(isConnected ? BrandColor.success : BrandColor.warning)
                    
                    Text(isConnected ? "Online" : "Offline")
                        .font(Typography.caption2)
                        .foregroundColor(isConnected ? BrandColor.success : BrandColor.warning)
                }
            }
        }
    }
    
    private var statusText: String {
        if downloadedAlbums == 0 {
            return "No downloaded music available"
        } else {
            return "\(downloadedAlbums) album\(downloadedAlbums != 1 ? "s" : "") available"
        }
    }
}

struct AlbumSection: View {
    let title: String
    let albums: [Album]
    let icon: String
    let accentColor: Color
    var showRefreshButton: Bool = false
    var refreshAction: (() async -> Void)? = nil
    
    @State private var isRefreshing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            // Section Header
            HStack {
                Label(title, systemImage: icon)
                    .font(Typography.headline)
                    .foregroundColor(TextColor.primary)
                
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
                            .font(Typography.subheadline)
                            .foregroundColor(accentColor)
                            .rotationEffect(isRefreshing ? .degrees(360) : .degrees(0))
                            .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                    }
                    .disabled(isRefreshing)
                }
            }
            .screenPadding()
            
            // Horizontal Album Scroll
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Spacing.m) {
                    ForEach(albums.indices, id: \.self) { index in
                        let album = albums[index]
                        NavigationLink(destination: AlbumDetailView(album: album)) {
                            AlbumCard(album: album, accentColor: accentColor, index: index)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, Sizes.screenPadding)
            }
        }
    }
}

struct QuickAccessCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: icon)
                .font(Typography.title2)
                .foregroundColor(color)
                .frame(width: Sizes.buttonHeight, height: Sizes.buttonHeight)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: Radius.s))
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(Typography.headline)
                    .foregroundColor(TextColor.primary)
                
                Text(subtitle)
                    .font(Typography.subheadline)
                    .foregroundColor(TextColor.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(Typography.caption.weight(.semibold))
                .foregroundColor(TextColor.tertiary)
        }
        .listItemPadding()
        .materialCardStyle()
    }
}

struct StorageInfoCard: View {
    let totalSize: String
    let albumCount: Int
    
    var body: some View {
        VStack(spacing: Spacing.m) {
            HStack {
                Label("Storage Used", systemImage: "internaldrive")
                    .font(Typography.headline)
                    .foregroundColor(TextColor.primary)
                
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(totalSize)
                        .font(Typography.title2)
                        .foregroundColor(BrandColor.primary)
                    
                    Text("\(albumCount) albums downloaded")
                        .font(Typography.caption)
                        .foregroundColor(TextColor.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chart.pie.fill")
                    .font(Typography.title)
                    .foregroundColor(BrandColor.primary.opacity(0.6))
            }
        }
        .listItemPadding()
        .materialCardStyle()
    }
}

struct NetworkStatusCard: View {
    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: "wifi.slash")
                .font(Typography.title2)
                .foregroundColor(BrandColor.warning)
                .frame(width: Sizes.buttonHeight, height: Sizes.buttonHeight)
                .background(BrandColor.warning.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: Radius.s))
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("No Connection")
                    .font(Typography.headline)
                    .foregroundColor(TextColor.primary)
                
                Text("Playing from downloaded music only")
                    .font(Typography.subheadline)
                    .foregroundColor(TextColor.secondary)
            }
            
            Spacer()
        }
        .listItemPadding()
        .background(BrandColor.warning.opacity(0.1), in: RoundedRectangle(cornerRadius: Radius.m))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.m)
                .stroke(BrandColor.warning.opacity(0.3), lineWidth: 1)
        )
    }
}

struct ErrorSection: View {
    let message: String
    
    var body: some View {
        VStack(spacing: Spacing.s) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: Sizes.icon))
                .foregroundColor(BrandColor.warning)
            
            Text(message)
                .font(Typography.subheadline)
                .foregroundColor(TextColor.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(Padding.m)
        .background(BrandColor.warning.opacity(0.1))
        .cornerRadius(Radius.s)
        .screenPadding()
    }
}
