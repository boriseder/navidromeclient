import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager

    @State private var selectedTab: Int = 0
    
    // MARK: - TabItem Definition
    private struct TabItem {
        let view: AnyView
        let label: String
        let systemImage: String
        let badge: String?
        let navigationDestinations: [(Any.Type, (Any) -> AnyView)]
        
        init(
            view: AnyView,
            label: String,
            systemImage: String,
            badge: String? = nil,
            navigationDestinations: [(Any.Type, (Any) -> AnyView)] = []
        ) {
            self.view = view
            self.label = label
            self.systemImage = systemImage
            self.badge = badge
            self.navigationDestinations = navigationDestinations
        }
    }
    
    // MARK: - Tab Konfiguration
    private var tabs: [TabItem] {
        [
            TabItem(
                view: AnyView(ExploreView()),
                label: "Explore",
                systemImage: "music.note.house"
            ),
            TabItem(
                view: AnyView(AlbumsView()),
                label: "Albums",
                systemImage: "record.circle",
                badge: offlineManager.isOfflineMode ? "📱" : nil,
                navigationDestinations: [
                    (Album.self, { album in
                        AnyView(AlbumDetailView(album: album as! Album))
                    })
                ]
            ),
            TabItem(
                view: AnyView(ArtistsView()),
                label: "Artists",
                systemImage: "person.2",
                navigationDestinations: [
                    (Artist.self, { artist in
                        AnyView(ArtistDetailView(context: .artist(artist as! Artist)))
                    })
                ]
            ),
            TabItem(
                view: AnyView(GenreView()),
                label: "Genres",
                systemImage: "music.note.list",
                navigationDestinations: [
                    (Genre.self, { genre in
                        AnyView(ArtistDetailView(context: .genre(genre as! Genre)))
                    })
                ]
            ),
            TabItem(
                view: AnyView(FavoritesView()),
                label: "Favorites",
                systemImage: "heart"
            )
        ]
    }
    
    var body: some View {
        NavigationStack {   // ✅ nur ein einziger NavigationStack
            GeometryReader { geometry in
                ZStack {
                    // Swipebare Tabs
                    TabView(selection: $selectedTab) {
                        ForEach(tabs.indices, id: \.self) { index in
                            tabs[index].view
                                .applyNavigationDestinations(tabs[index].navigationDestinations)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    
                    // Custom TabBar
                    VStack {
                        Spacer()
                        customTabBar
                            .padding(.bottom, geometry.safeAreaInsets.bottom + 10)
                    }
                }
                // Overlays (z.B. MiniPlayer, Network Status)
                .overlay(networkStatusOverlay, alignment: .top)
                .overlay(alignment: .bottom) {
                    MiniPlayerView()
                        .environmentObject(playerVM)
                        .padding(.bottom, geometry.safeAreaInsets.bottom + 60) // Platz für TabBar
                }
            }
        }
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
            BlurView(style: .systemMaterial) // schöner Glas-Effekt
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

// MARK: - NavigationDestinations Extension
extension View {
    @ViewBuilder
    func applyNavigationDestinations(_ destinations: [(Any.Type, (Any) -> AnyView)]) -> some View {
        self.modifier(NavigationDestinationsModifier(destinations: destinations))
    }
}

struct NavigationDestinationsModifier: ViewModifier {
    let destinations: [(Any.Type, (Any) -> AnyView)]
    
    func body(content: Content) -> some View {
        destinations.reduce(AnyView(content)) { currentView, destination in
            let (type, builder) = destination
            
            if type == Artist.self {
                return AnyView(currentView.navigationDestination(for: Artist.self) { item in
                    builder(item)
                })
            } else if type == Album.self {
                return AnyView(currentView.navigationDestination(for: Album.self) { item in
                    builder(item)
                })
            } else if type == Genre.self {
                return AnyView(currentView.navigationDestination(for: Genre.self) { item in
                    builder(item)
                })
            }
            return currentView
        }
    }
}

/// Ein einfacher Wrapper für UIVisualEffectView (Blur)
struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}
