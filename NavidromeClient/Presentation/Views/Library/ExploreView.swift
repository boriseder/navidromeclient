import SwiftUI

struct ExploreView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var coverArtService: ReactiveCoverArtService // NEW
    
    @StateObject private var exploreVM = ExploreViewModel() // RENAMED
    @State private var showRefreshAnimation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                DynamicMusicBackground()

                if networkMonitor.canLoadOnlineContent && !offlineManager.isOfflineMode {
                    onlineContent
                } else {
                    offlineContent
                }
            }
            .navigationTitle("Music")
            .navigationBarTitleDisplayMode(.large)
            .task {
                exploreVM.configure(with: navidromeVM)
                if networkMonitor.canLoadOnlineContent && !offlineManager.isOfflineMode {
                    await exploreVM.loadHomeScreenData()
                    
                    // NEW: Smart preloading nach dem Laden
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
    
    // NEW: Smart preloading für Home Screen
    private func preloadHomeScreenCovers() async {
        let allAlbums = exploreVM.recentAlbums +
                       exploreVM.newestAlbums +
                       exploreVM.frequentAlbums +
                       exploreVM.randomAlbums
        
        await coverArtService.preloadAlbums(Array(allAlbums.prefix(20)), size: 200)
    }
    
    // MARK: - Online Content
    private var onlineContent: some View {
        ScrollView {
            LazyVStack(spacing: 32) {
                WelcomeHeader()
                    .padding(.horizontal, 20)
                
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
                
                if exploreVM.isLoading {
                    loadingView()
                }
                
                if let errorMessage = exploreVM.errorMessage {
                    ErrorSection(message: errorMessage)
                }
                
                Color.clear.frame(height: 90)
            }
            .padding(.top, 10)
        }
    }
    
    // MARK: - Offline Content
    private var offlineContent: some View {
        ScrollView {
            LazyVStack(spacing: 32) {
                OfflineWelcomeHeader(
                    downloadedAlbums: downloadManager.downloadedAlbums.count,
                    isConnected: networkMonitor.isConnected
                )
                .padding(.horizontal, 20)
                
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
                .padding(.horizontal, 20)
                
                StorageInfoCard(
                    totalSize: downloadManager.totalDownloadSize(),
                    albumCount: downloadManager.downloadedAlbums.count
                )
                .padding(.horizontal, 20)
                
                if !networkMonitor.isConnected {
                    NetworkStatusCard()
                        .padding(.horizontal, 20)
                }
                
                Color.clear.frame(height: 90)
            }
            .padding(.top, 10)
        }
    }
    
    private func refreshRandomAlbums() async {
        showRefreshAnimation = true
        await exploreVM.refreshRandomAlbums()
        
        // NEW: Preload nach refresh
        await coverArtService.preloadAlbums(exploreVM.randomAlbums, size: 200)
        
        showRefreshAnimation = false
    }
}

// MARK: - Welcome Headers
struct WelcomeHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greetingText())
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.black.opacity(0.8))
                    
                    Text("Enjoy your music")
                        .font(.subheadline)
                        .foregroundColor(.black.opacity(0.6))
                }
                
                Spacer()
                
                Text(currentTimeString())
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.black.opacity(0.5))
            }
        }
    }
    
    private func greetingText() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Good night"
        }
    }
    
    private func currentTimeString() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
}

struct OfflineWelcomeHeader: View {
    let downloadedAlbums: Int
    let isConnected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Offline Music")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.black.opacity(0.8))
                    
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundColor(.black.opacity(0.6))
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Image(systemName: isConnected ? "wifi" : "wifi.slash")
                        .font(.title3)
                        .foregroundColor(isConnected ? .green : .orange)
                    
                    Text(isConnected ? "Online" : "Offline")
                        .font(.caption2)
                        .foregroundColor(isConnected ? .green : .orange)
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

// MARK: - Album Section
struct AlbumSection: View {
    let title: String
    let albums: [Album]
    let icon: String
    let accentColor: Color
    var showRefreshButton: Bool = false
    var refreshAction: (() async -> Void)? = nil
    
    @State private var isRefreshing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Label(title, systemImage: icon)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.black.opacity(0.9))
                
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
                            .font(.subheadline)
                            .foregroundColor(accentColor)
                            .rotationEffect(isRefreshing ? .degrees(360) : .degrees(0))
                            .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                    }
                    .disabled(isRefreshing)
                }
            }
            .padding(.horizontal, 20)
            
            // Horizontal Album Scroll
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(albums) { album in
                        NavigationLink(destination: AlbumDetailView(album: album)) {
                            AlbumCard(album: album, accentColor: accentColor)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Offline-specific Components
struct QuickAccessCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.black.opacity(0.9))
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.black.opacity(0.6))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }
}

struct StorageInfoCard: View {
    let totalSize: String
    let albumCount: Int
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Label("Storage Used", systemImage: "internaldrive")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.black.opacity(0.9))
                
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(totalSize)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text("\(albumCount) albums downloaded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chart.pie.fill")
                    .font(.title)
                    .foregroundColor(.blue.opacity(0.6))
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }
}

struct NetworkStatusCard: View {
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.title2)
                .foregroundColor(.orange)
                .frame(width: 44, height: 44)
                .background(.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("No Connection")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.black.opacity(0.9))
                
                Text("Playing from downloaded music only")
                    .font(.subheadline)
                    .foregroundColor(.black.opacity(0.6))
            }
            
            Spacer()
        }
        .padding(20)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Error Section
struct ErrorSection: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundColor(.orange)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.black.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }
}
