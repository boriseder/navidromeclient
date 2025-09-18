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
            TabItem(view: AnyView(SearchView()), label: "Search", systemImage: "magnifyingglass", badge: nil)
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
                    .frame(height: DSLayout.miniPlayerHeight)
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
                    .font(DSText.metadata)
                Text("Offline Mode")
                    .font(DSText.metadata.weight(.medium))
                Spacer()
                if downloadManager.downloadedAlbums.count > 0 {
                    Button("Downloaded Music") {
                        offlineManager.switchToOfflineMode()
                    }
                    .font(DSText.metadata)
                    .foregroundStyle(DSColor.accent)
                }
            }
            .padding(.horizontal, DSLayout.contentGap)
            .padding(.vertical, DSLayout.elementGap)
            .padding(.top, DSLayout.elementGap)
            .background(DSColor.warning.opacity(0.9), in: RoundedRectangle(cornerRadius: DSCorners.element))
            .foregroundStyle(DSColor.onDark)
            .screenPadding()
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(DSAnimations.ease, value: networkMonitor.isConnected)
        }
    }
}

