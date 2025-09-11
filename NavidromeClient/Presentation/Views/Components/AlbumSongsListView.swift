//
//  AlbumSongsListView.swift
//  NavidromeClient
//
//  Created by Boris Eder on 11.09.25.
//

import SwiftUI

// MARK: - Album Songs List
struct AlbumSongsListView: View {
    let songs: [Song]
    let album: Album
    @Binding var miniPlayerVisible: Bool
    
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    
    var body: some View {
        if songs.isEmpty {
            loadingView()
        } else {
            VStack(spacing: 5) {
                ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                    SongRow(
                        song: song,
                        index: index + 1,
                        isPlaying: playerVM.currentSong?.id == song.id && playerVM.isPlaying,
                        action: {
                            Task { await playerVM.setPlaylist(songs, startIndex: index, albumId: album.id) }
                        },
                        onMore: {
                            playerVM.stop()
                            miniPlayerVisible = false
                        }
                    )
                }
            }
        }
    }
}
