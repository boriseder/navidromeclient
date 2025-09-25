//
//  AlbumDetailViewContent.swift
//  NavidromeClient
//
//  Created by Boris Eder on 21.09.25.
//
import SwiftUI

struct AlbumDetailViewContent: View {
    let album: Album
    @State private var scrollOffset: CGFloat = 0

    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var coverArtManager: CoverArtManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    
    @State private var songs: [Song] = []
    @State private var isOfflineAlbum = false
    
    var body: some View {
        ZStack {
            DynamicMusicBackground()
            
            
            ScrollView {
                VStack(spacing: DSLayout.screenGap) {
                    AlbumHeaderView(
                        album: album,
                        songs: songs,
                        isOfflineAlbum: isOfflineAlbum
                    )
                    
                    if isOfflineAlbum || !networkMonitor.canLoadOnlineContent {
                        HStack {
                            if downloadManager.isAlbumDownloaded(album.id) {
                                OfflineStatusBadge(album: album)
                            } else {
                                NetworkStatusIndicator(showText: true)
                            }
                            Spacer()
                        }
                    }
                    
                    if songs.isEmpty {
                        EmptyStateView(
                            type: .songs,
                            customTitle: "No Songs Available",
                            customMessage: isOfflineAlbum ?
                            "This album is not downloaded for offline listening." :
                                "No songs found in this album."
                        )
                    } else {
                        AlbumSongsListView(
                            songs: songs,
                            album: album
                        )
                    }
                }
                .padding(.horizontal, DSLayout.screenPadding)
                .padding(.bottom, DSLayout.miniPlayerHeight + DSLayout.contentGap)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadAlbumData()
            }
        }
        .overlay( DebugLines() )
    }
    
    @MainActor
    private func loadAlbumData() async {
        isOfflineAlbum = !networkMonitor.canLoadOnlineContent || offlineManager.isOfflineMode
        
        songs = await navidromeVM.loadSongs(for: album.id)
    }
}
