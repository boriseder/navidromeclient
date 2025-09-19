//
//  AlbumSongsListView.swift
//  NavidromeClient
//
//  Created by Boris Eder on 11.09.25.
//

import SwiftUI

// MARK: - Album Songs List
struct AlbumSongsListView: View {

    @EnvironmentObject var deps: AppDependencies
    @State private var showingDeleteConfirmation = false

    let songs: [Song]
    let album: Album
    
    var body: some View {
        if songs.isEmpty {
            LoadingView()
        } else {
            VStack(spacing: 5) {
                ForEach(songs.indices, id: \.self) { index in
                    let song = songs[index]
                    SongRow(
                        song: song,
                        index: index + 1,
                        isPlaying: deps.playerVM.currentSong?.id == song.id && deps.playerVM.isPlaying,
                        action: {
                            Task { await deps.playerVM.setPlaylist(songs, startIndex: index, albumId: album.id) }
                        },
                        onMore: {
                            deps.playerVM.stop()
                        }
                    )
                    
                }
            }
        }
    }
}
