import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager

    private struct TabItem {
        let view: AnyView
        let label: String
        let systemImage: String
        let badge: String?
    }
    
    private var tabs: [TabItem] {
        [
            TabItem(view: AnyView(ExploreView()), label: "Explore", systemImage: "music.note.house", badge: nil),
            TabItem(view: AnyView(AlbumsView()), label: "Albums", systemImage: "record.circle", badge: offlineManager.isOfflineMode ? "📱" : nil),
            TabItem(view: AnyView(ArtistsView()), label: "Artists", systemImage: "person.2", badge: nil),
            TabItem(view: AnyView(GenreView()), label: "Genres", systemImage: "music.note.list", badge: nil),
            TabItem(view: AnyView(SearchView()), label: "Search", systemImage: "magnifyingglass", badge: nil),
            TabItem(view: AnyView(NetworkTestView()), label: "NWTV", systemImage: "magnifyingglass", badge: nil)
        ]
    }
    
    var body: some View {
        TabView {
            ForEach(tabs.indices, id: \.self) { index in
                tabContent(tabs[index])
            }
        }
        .overlay(networkStatusOverlay, alignment: .top)
    }
    
    @ViewBuilder
    private func tabContent(_ tab: TabItem) -> some View {
        ZStack {
            tab.view
            VStack {
                Spacer()
                MiniPlayerView()
                    .frame(height: Sizes.miniPlayer)
            }
        }
        .tabItem {
            Label(tab.label, systemImage: tab.systemImage)
        }
        .badge(tab.badge)
    }
        
    @ViewBuilder
    private var networkStatusOverlay: some View {
        if !networkMonitor.isConnected {
            HStack {
                Image(systemName: "wifi.slash")
                    .font(Typography.caption)
                Text("Offline Mode")
                    .font(Typography.caption.weight(.medium))
                Spacer()
                if downloadManager.downloadedAlbums.count > 0 {
                    Button("Downloaded Music") {
                        offlineManager.switchToOfflineMode()
                    }
                    .font(Typography.caption)
                    .foregroundStyle(BrandColor.primary)
                }
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .background(BrandColor.warning.opacity(0.9), in: RoundedRectangle(cornerRadius: Radius.s))
            .foregroundStyle(TextColor.onDark)
            .screenPadding()
            .padding(.top, Spacing.s)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(Animations.ease, value: networkMonitor.isConnected)
        }
    }
}

