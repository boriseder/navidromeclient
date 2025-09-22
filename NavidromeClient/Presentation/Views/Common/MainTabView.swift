//
//  MainTabView.swift - FIXED: Single NavigationStack Architecture
//  NavidromeClient
// FIXED: MainTabView.swift - Navigation Destinations richtig platziert


import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager

    @State private var selectedTab: Int = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Swipebare Tabs
                TabView(selection: $selectedTab) {
                    ForEach(tabs.indices, id: \.self) { index in
                        tabs[index].viewContent
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // Custom TabBar
                VStack {
                    Spacer()
                    customTabBar
                        .padding(.bottom, geometry.safeAreaInsets.bottom)
                }
            }
            // Overlays
            .overlay(networkStatusOverlay, alignment: .top)
            .overlay(alignment: .bottom) {
                MiniPlayerView()
                    .environmentObject(playerVM)
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 85)
            }
        }
    }
    
    // MARK: - Tab Configuration
    private var tabs: [TabConfiguration] {
        [
            TabConfiguration(
                viewContent: AnyView(ExploreViewContent()),
                label: "Explore",
                systemImage: "music.note.house"
            ),
            TabConfiguration(
                viewContent: AnyView(AlbumsViewContent()),
                label: "Albums",
                systemImage: "record.circle",
                badge: offlineManager.isOfflineMode ? "📱" : nil
            ),
            TabConfiguration(
                viewContent: AnyView(ArtistsViewContent()),
                label: "Artists",
                systemImage: "person.2"
            ),
            TabConfiguration(
                viewContent: AnyView(GenreViewContent()),
                label: "Genres",
                systemImage: "music.note.list"
            ),
            TabConfiguration(
                viewContent: AnyView(FavoritesViewContent()),
                label: "Favorites",
                systemImage: "heart"
            )
        ]
    }
    
    // MARK: - Custom TabBar
    private var customTabBar: some View {
        HStack {
            ForEach(tabs.indices, id: \.self) { index in
                Spacer()
                Button {
                    withAnimation(.easeInOut) {
                        selectedTab = index
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tabs[index].systemImage)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(selectedTab == index ? DSColor.accent : DSColor.secondary)
                        
                        Text(tabs[index].label)
                            .font(.caption2)
                            .foregroundStyle(selectedTab == index ? DSColor.accent : DSColor.secondary)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if let badge = tabs[index].badge {
                        Text(badge)
                            .font(.caption2)
                            .padding(4)
                            .background(Circle().fill(DSColor.warning))
                            .foregroundStyle(.white)
                            .offset(x: 12, y: -4)
                    }
                }
                Spacer()
            }
        }
        .padding(.vertical, 8)
        .background(
            BlurView(style: .systemMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        )
        .padding(.horizontal, 16)
    }
    
    // MARK: - Network Status Overlay
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

// MARK: - Tab Configuration
struct TabConfiguration {
    let viewContent: AnyView
    let label: String
    let systemImage: String
    let badge: String?
    
    init(viewContent: AnyView, label: String, systemImage: String, badge: String? = nil) {
        self.viewContent = viewContent
        self.label = label
        self.systemImage = systemImage
        self.badge = badge
    }
}

// MARK: - BlurView
struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

