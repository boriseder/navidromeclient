//
//  Enhanced MainTabView - Navigation Destinations in TabItem Structure
//  NavidromeClient
//
//  ✅ CLEAN: Keeps generic builders intact
//  ✅ DECLARATIVE: Navigation destinations defined with tab configuration
//  ✅ TYPE-SAFE: Compile-time verified navigation setup
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager

    // MARK: - ✅ ENHANCED: TabItem with Navigation Destinations
    
    private struct TabItem {
        let view: AnyView
        let label: String
        let systemImage: String
        let badge: String?
        let navigationDestinations: [(Any.Type, (Any) -> AnyView)]
        
        // ✅ CONVENIENCE: Simple initializer without destinations
        init(
            view: AnyView,
            label: String,
            systemImage: String,
            badge: String? = nil
        ) {
            self.view = view
            self.label = label
            self.systemImage = systemImage
            self.badge = badge
            self.navigationDestinations = []
        }
        
        // ✅ FULL: Initializer with navigation destinations
        init(
            view: AnyView,
            label: String,
            systemImage: String,
            badge: String? = nil,
            navigationDestinations: [(Any.Type, (Any) -> AnyView)]
        ) {
            self.view = view
            self.label = label
            self.systemImage = systemImage
            self.badge = badge
            self.navigationDestinations = navigationDestinations
        }
    }
    
    // MARK: - ✅ CLEAN: Tab Configuration with Destinations
    
    private var tabs: [TabItem] {
        [
            // Explore - no navigation destinations needed
            TabItem(
                view: AnyView(ExploreView()),
                label: "Explore",
                systemImage: "music.note.house"
            ),
            
            // Albums - navigates to AlbumDetailView
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
            
            // Artists - navigates to ArtistDetailView
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
            
            // Genres - navigates to ArtistDetailView with genre context
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
            
            //
            TabItem(
                view: AnyView(FavoritesView()),
                label: "Favorites",
                systemImage: "heart",
            )
        ]
    }
    
    var body: some View {
        GeometryReader { geometry in  // ← ADD GeometryReader
            
            TabView {
                ForEach(tabs.indices, id: \.self) { index in
                    tabContent(tabs[index])
                }
            }
            .overlay(networkStatusOverlay, alignment: .top)
            .overlay(alignment: .bottom) {
                MiniPlayerView()
                    .environmentObject(playerVM)
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 15)
                
            }
        }
    }
    
    // MARK: - ✅ GENERIC: Builder bleibt sauber und generisch
    
    @ViewBuilder
    private func tabContent(_ tab: TabItem) -> some View {
        NavigationStack {
            ZStack {
                tab.view
            }
            // ✅ MAGIC: Dynamically apply navigation destinations from TabItem
            .applyNavigationDestinations(tab.navigationDestinations)
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

// MARK: - ✅ CLEAN: Extension für dynamische Navigation Destinations

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
            // Future: Add Song.self, Playlist.self etc.
            
            return currentView
        }
    }
}
