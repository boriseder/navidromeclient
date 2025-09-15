//
//  ExploreView.swift - Enhanced with Design System
//  NavidromeClient
//
//  ✅ ENHANCED: Vollständige Anwendung des Design Systems
//

import SwiftUI

struct ExploreView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var coverArtService: CoverArtManager
    
    @StateObject private var exploreVM = ExploreViewModel()
    @State private var showRefreshAnimation = false
    
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
            // ✅ EXPLORE VIEW: Handles its own data loading since it's different from library views
            .task {
                exploreVM.configure(with: navidromeVM, coverArtService: coverArtService)
                
                if networkMonitor.canLoadOnlineContent && !offlineManager.isOfflineMode {
                    await exploreVM.loadHomeScreenData()
                    await preloadHomeScreenCovers()
                }
            }
            .refreshable {
                if networkMonitor.canLoadOnlineContent && !offlineManager.isOfflineMode {
                    await exploreVM.loadHomeScreenData()
                    await preloadHomeScreenCovers()
                }
            }
            .onChange(of: networkMonitor.canLoadOnlineContent) { _, canLoad in
                if canLoad && !offlineManager.isOfflineMode {
                    Task {
                        await exploreVM.loadHomeScreenData()
                        await preloadHomeScreenCovers()
                    }
                }
            }
            .onChange(of: offlineManager.isOfflineMode) { _, isOffline in
                if !isOffline && networkMonitor.canLoadOnlineContent {
                    Task {
                        await exploreVM.loadHomeScreenData()
                        await preloadHomeScreenCovers()
                    }
                }
            }
            .accountToolbar()
        }
    }
    
    // Smart preloading for Home Screen using ReactiveCoverArtService
    private func preloadHomeScreenCovers() async {
        let allAlbums = exploreVM.recentAlbums +
                       exploreVM.newestAlbums +
                       exploreVM.frequentAlbums +
                       exploreVM.randomAlbums
        
        await coverArtService.preloadAlbums(Array(allAlbums.prefix(20)), size: 200)
    }
    
    // Rest of ExploreView implementation remains the same...
    private var onlineContent: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.xl) {
                WelcomeHeader(
                    username: AppConfig.shared.getCredentials()?.username ?? "User",
                    nowPlaying: playerVM.currentSong
                )
                
                Group {
                    if !exploreVM.recentAlbums.isEmpty {
                        AlbumSection(
                            title: "Recently played",
                            albums: exploreVM.recentAlbums,
                            icon: "clock.fill",
                            accentColor: .orange
                        )
                    }
                    
                    if !exploreVM.newestAlbums.isEmpty {
                        AlbumSection(
                            title: "Newly added",
                            albums: exploreVM.newestAlbums,
                            icon: "sparkles",
                            accentColor: .green
                        )
                    }
                    
                    if !exploreVM.frequentAlbums.isEmpty {
                        AlbumSection(
                            title: "Often played",
                            albums: exploreVM.frequentAlbums,
                            icon: "chart.bar.fill",
                            accentColor: .purple
                        )
                    }
                    
                    if !exploreVM.randomAlbums.isEmpty {
                        AlbumSection(
                            title: "Explore",
                            albums: exploreVM.randomAlbums,
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
                    if exploreVM.isLoading {
                        loadingView()
                    }
                    
                    if let errorMessage = exploreVM.errorMessage {
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
    
    private func refreshRandomAlbums() async {
        showRefreshAnimation = true
        await exploreVM.refreshRandomAlbums()
        
        await coverArtService.preloadAlbums(exploreVM.randomAlbums, size: 200)
        
        showRefreshAnimation = false
    }
}

// MARK: - Offline Components (Enhanced with DS)
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

// MARK: - Album Section (Enhanced with DS)
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
                    ForEach(albums) { album in
                        NavigationLink(destination: AlbumDetailView(album: album)) {
                            AlbumCard(album: album, accentColor: accentColor)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, Sizes.screenPadding)
            }
        }
    }
}

// MARK: - Quick Access Components (Enhanced with DS)
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

// MARK: - Error Section (Enhanced with DS)
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
