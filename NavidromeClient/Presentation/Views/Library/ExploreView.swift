//
//  ExploreView.swift - REFACTORED to Pure UI
//  NavidromeClient
//
//  ✅ CLEAN: All business logic moved to HomeScreenManager
//  ✅ ELIMINATES: ExploreViewModel dependency completely
//

import SwiftUI

struct ExploreView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var coverArtManager: CoverArtManager
    
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
                await setupHomeScreenData()
            }
            .refreshable {
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
    
    // MARK: - Setup
    
    private func setupHomeScreenData() async {
        // Keine Service-Übergabe mehr nötig
        if networkMonitor.canLoadOnlineContent && !offlineManager.isOfflineMode {
            await homeScreenManager.loadHomeScreenData()
            await preloadHomeScreenCovers()
        }
    }
    
    private func preloadHomeScreenCovers() async {
        let allAlbums = homeScreenManager.recentAlbums +
                       homeScreenManager.newestAlbums +
                       homeScreenManager.frequentAlbums +
                       homeScreenManager.randomAlbums
        
        await coverArtManager.preloadAlbums(Array(allAlbums.prefix(20)), size: 200)
    }
    
    // MARK: - Online Content
    
    private var onlineContent: some View {
        ScrollView {
            LazyVStack(spacing: DSLayout.screenGap) {
                WelcomeHeader(
                    username: "User", // falls du keinen navidromeVM mehr hast
                    nowPlaying: playerVM.currentSong
                )
                
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
                
                if homeScreenManager.isLoadingHomeData {
                    LoadingView()
                }
                
                if let errorMessage = homeScreenManager.homeDataError {
                    ErrorSection(message: errorMessage)
                }
                
                Color.clear.frame(height: DSLayout.miniPlayerHeight)
            }
            .padding(.top, DSLayout.elementGap)
        }
    }
    
    // MARK: - Offline Content
    
    private var offlineContent: some View {
        ScrollView {
            LazyVStack(spacing: DSLayout.screenGap) {
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
                
                Color.clear.frame(height: DSLayout.miniPlayerHeight)
            }
            .padding(.top, DSLayout.elementGap)
        }
    }
    
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
        VStack(alignment: .leading, spacing: DSLayout.elementGap) {
            HStack {
                VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                    Text("Offline Music")
                        .font(DSText.sectionTitle)
                        .foregroundColor(DSColor.primary)
                    
                    Text(statusText)
                        .font(DSText.body)
                        .foregroundColor(DSColor.secondary)
                }
                
                Spacer()
                
                VStack(spacing: DSLayout.tightGap) {
                    Image(systemName: isConnected ? "wifi" : "wifi.slash")
                        .font(DSText.sectionTitle)
                        .foregroundColor(isConnected ? DSColor.success : DSColor.warning)
                    
                    Text(isConnected ? "Online" : "Offline")
                        .font(DSText.body)
                        .foregroundColor(isConnected ? DSColor.success : DSColor.warning)
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
            
            // Horizontal Album Scroll
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: DSLayout.contentGap) {
                    ForEach(albums.indices, id: \.self) { index in
                        let album = albums[index]
                        NavigationLink(destination: AlbumDetailView(album: album)) {
                            AlbumCard(album: album, accentColor: accentColor, index: index)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, DSLayout.screenPadding)
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
        HStack(spacing: DSLayout.contentGap) {
            Image(systemName: icon)
                .font(DSText.sectionTitle)
                .foregroundColor(color)
                .frame(width: DSLayout.buttonHeight, height: DSLayout.buttonHeight)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: DSCorners.element))
            
            VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                Text(title)
                    .font(DSText.prominent)
                    .foregroundColor(DSColor.primary)
                
                Text(subtitle)
                    .font(DSText.sectionTitle)
                    .foregroundColor(DSColor.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(DSText.metadata.weight(.semibold))
                .foregroundColor(DSColor.tertiary)
        }
        .listItemPadding()
        .cardStyle()
    }
}

struct StorageInfoCard: View {
    let totalSize: String
    let albumCount: Int
    
    var body: some View {
        VStack(spacing: DSLayout.contentGap) {
            HStack {
                Label("Storage Used", systemImage: "internaldrive")
                    .font(DSText.prominent)
                    .foregroundColor(DSColor.primary)
                
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                    Text(totalSize)
                        .font(DSText.sectionTitle)
                        .foregroundColor(DSColor.accent)
                    
                    Text("\(albumCount) albums downloaded")
                        .font(DSText.metadata)
                        .foregroundColor(DSColor.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chart.pie.fill")
                    .font(DSText.sectionTitle)
                    .foregroundColor(DSColor.accent.opacity(0.6))
            }
        }
        .listItemPadding()
        .cardStyle()
    }
}

struct NetworkStatusCard: View {
    var body: some View {
        HStack(spacing: DSLayout.contentGap) {
            Image(systemName: "wifi.slash")
                .font(DSText.sectionTitle)
                .foregroundColor(DSColor.warning)
                .frame(width: DSLayout.buttonHeight, height: DSLayout.buttonHeight)
                .background(DSColor.warning.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: DSCorners.element))
            
            VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                Text("No Connection")
                    .font(DSText.prominent)
                    .foregroundColor(DSColor.primary)
                
                Text("Playing from downloaded music only")
                    .font(DSText.sectionTitle)
                    .foregroundColor(DSColor.secondary)
            }
            
            Spacer()
        }
        .listItemPadding()
        .background(DSColor.warning.opacity(0.1), in: RoundedRectangle(cornerRadius: DSCorners.content))
        .overlay(
            RoundedRectangle(cornerRadius: DSCorners.content)
                .stroke(DSColor.warning.opacity(0.3), lineWidth: 1)
        )
    }
}

struct ErrorSection: View {
    let message: String
    
    var body: some View {
        VStack(spacing: DSLayout.elementGap) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: DSLayout.icon))
                .foregroundColor(DSColor.warning)
            
            Text(message)
                .font(DSText.sectionTitle)
                .foregroundColor(DSColor.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(DSLayout.contentPadding)
        .background(DSColor.warning.opacity(0.1))
        .cornerRadius(DSCorners.element)
        .screenPadding()
    }
}
