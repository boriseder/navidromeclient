//
//  AlbumDetailView.swift
//  NavidromeClient
//
//  FIXED: Preload fullscreen images for better quality on detail view
//

import SwiftUI

struct AlbumDetailViewContent: View {
    let album: Album
    
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var songManager: SongManager
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var coverArtManager: CoverArtManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    
    @State private var songs: [Song] = []
    @State private var isOfflineAlbum = false
    
    private var currentState: ViewState? {
        if songs.isEmpty {
            return .empty(type: .songs)
        }
        return nil
    }
    
    var body: some View {
        ZStack {
            blurredAlbumBackground
            
            ScrollView {
                VStack(spacing: 1) {
                     
                     AlbumHeaderView(
                        album: album,
                        songs: songs,
                        isOfflineAlbum: isOfflineAlbum
                     )
                     
                     if let state = currentState {
                        UnifiedStateView(
                            state: state,
                            primaryAction: StateAction("Refresh") {
                                Task {
                                    await loadAlbumData()
                                }
                            }
                        )
                     } else {
                        AlbumSongsListView(
                            songs: songs,
                            album: album
                        )
                    }
                }
                .padding(.horizontal, DSLayout.screenPadding)
                .padding(.bottom, DSLayout.miniPlayerHeight)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadAlbumData()
                // Preload fullscreen image in background for better quality
                Task.detached(priority: .background) {
                    await coverArtManager.preloadForFullscreen(albumId: album.id)
                }
            }
            .scrollIndicators(.hidden)
            .onReceive(NotificationCenter.default.publisher(for: .downloadCompleted)) { notification in
                if let albumId = notification.object as? String, albumId == album.id {
                    Task {
                        await loadAlbumData()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .downloadDeleted)) { notification in
                if let albumId = notification.object as? String, albumId == album.id {
                    Task {
                        await loadAlbumData()
                    }
                }
            }
        }
    }
    
    @MainActor
    private func loadAlbumData() async {
        let isNetworkOffline = !networkMonitor.shouldLoadOnlineContent
        let isDownloaded = downloadManager.isAlbumDownloaded(album.id)
        
        isOfflineAlbum = isNetworkOffline || isDownloaded
        
        songs = await songManager.loadSongs(for: album.id)
    }
    
    @ViewBuilder
    private var blurredAlbumBackground: some View {
        GeometryReader { geo in
            AlbumImageView(album: album, index: 0, context: .fullscreen)
                .scaledToFill()
                .contentShape(Rectangle())
                .blur(radius: 20)
                .offset(
                    x: -1 * (CGFloat(ImageContext.fullscreen.size) - geo.size.width) / 2,
                    y: -geo.size.height * 0.15
                )
                .overlay(
                    LinearGradient(
                        colors: [
                            .black.opacity(0.7),
                            .black.opacity(0.35),
                            .black.opacity(0.3),
                            .black.opacity(0.2),
                            .black.opacity(0.7),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .offset(
                        x: -1 * (CGFloat(ImageContext.fullscreen.size) - geo.size.width) / 2,
                        y: -geo.size.height * 0.15)
                )
                .ignoresSafeArea(edges: .top)
        }
    }
}
