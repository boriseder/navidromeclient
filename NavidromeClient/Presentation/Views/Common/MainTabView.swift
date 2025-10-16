//
//  MainTabView.swift - FIXED: Single NavigationStack Architecture
//  NavidromeClient
// FIXED: MainTabView.swift - Navigation Destinations richtig platziert


import SwiftUI

//
//  MainTabView.swift - Native iOS TabView
//  NavidromeClient
//
//  Uses native iOS TabView for better system integration
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager

    var body: some View {
        TabView {
            ExploreViewContent()
                .tabItem {
                    Image(systemName: "music.note.house")
                    Text("Explore")
                }
                .tag(0)
            
            AlbumsViewContent()
                .tabItem {
                    Image(systemName: "record.circle")
                    Text("Albums")
                }
                .tag(1)
            
            ArtistsViewContent()
                .tabItem {
                    Image(systemName: "person.2")
                    Text("Artists")
                }
                .tag(2)
            
            GenreViewContent()
                .tabItem {
                    Image(systemName: "music.note.list")
                    Text("Genres")
                }
                .tag(3)
            
            FavoritesViewContent()
                .tabItem {
                    Image(systemName: "heart")
                    Text("Favorites")
                }
                .tag(4)
        }
        .overlay(networkStatusOverlay, alignment: .top)
        .overlay(alignment: .bottom) {
            MiniPlayerView()
                .environmentObject(playerVM)
                .padding(.bottom, DSLayout.miniPlayerHeight) // Standard tab bar height
        }
        .id(appConfig.userBackgroundStyle) // ← NUR HIER!
        .environment(\.colorScheme,
            appConfig.userBackgroundStyle == .dark ? .dark : .light)
    }
    
    // MARK: - Network Status Overlay
    @ViewBuilder
    private var networkStatusOverlay: some View {
        // DISTINGUISH between different offline reasons
        switch networkMonitor.contentLoadingStrategy {
            case .offlineOnly(let reason):
                OfflineReasonBanner(reason: reason)
                    .padding(.horizontal, DSLayout.screenPadding)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(DSAnimations.ease, value: networkMonitor.canLoadOnlineContent)
                
            case .online, .setupRequired:
                EmptyView()
        }
    }
}

