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
                .badge(offlineManager.isOfflineMode ? "📱" : nil)
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
                .padding(.bottom, 90) // Standard tab bar height
        }
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

