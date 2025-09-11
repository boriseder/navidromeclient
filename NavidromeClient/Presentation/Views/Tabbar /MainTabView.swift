//
//  MainTabView.swift
//  NavidromeClient
//
//  Created by Boris Eder on 11.09.25.
//


import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var offlineManager = OfflineManager.shared

    var body: some View {
        TabView {
            // Home/Explore Tab
            ZStack {
                HomeScreenView()
                VStack {
                    Spacer()
                    MiniPlayerView()
                        .environmentObject(playerVM)
                        .frame(height: 90)
                }
            }
            .tabItem { 
                Label("Explore", systemImage: "music.note.house") 
            }
            
            // Albums Tab - NEU!
            ZStack {
                AlbumsView()
                VStack {
                    Spacer()
                    MiniPlayerView()
                        .environmentObject(playerVM)
                        .frame(height: 90)
                }
            }
            .tabItem { 
                Label("Albums", systemImage: "square.stack") 
            }
            .badge(offlineManager.isOfflineMode ? "📱" : nil) // Offline-Indikator
            
            // Artists Tab
            ZStack {
                ArtistsView()
                VStack {
                    Spacer()
                    MiniPlayerView()
                        .environmentObject(playerVM)
                        .frame(height: 90)
                }
            }
            .tabItem { 
                Label("Artists", systemImage: "person.2.fill") 
            }
  
            // Genres Tab
            ZStack {
                GenreView()
                VStack {
                    Spacer()
                    MiniPlayerView()
                        .environmentObject(playerVM)
                        .frame(height: 90)
                }
            }
            .tabItem { 
                Label("Genres", systemImage: "music.note.list") 
            }

            // Search Tab
            ZStack {
                SearchView()
                VStack {
                    Spacer()
                    MiniPlayerView()
                        .environmentObject(playerVM)
                        .frame(height: 90)
                }
            }
            .tabItem { 
                Label("Search", systemImage: "magnifyingglass") 
            }
        }
        .onAppear {
            setupTabBarAppearance()
        }
        .overlay(
            // Network Status Overlay (dezent oben)
            networkStatusOverlay,
            alignment: .top
        )
    }
    
    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    @ViewBuilder
    private var networkStatusOverlay: some View {
        if !networkMonitor.isConnected {
            HStack {
                Image(systemName: "wifi.slash")
                    .font(.caption)
                Text("Offline Mode")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
                
                if DownloadManager.shared.downloadedAlbums.count > 0 {
                    Button("Downloaded Music") {
                        offlineManager.switchToOfflineMode()
                    }
                    .font(.caption)
                    .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.orange.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.white)
            .padding(.horizontal)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.3), value: networkMonitor.isConnected)
        }
    }
}