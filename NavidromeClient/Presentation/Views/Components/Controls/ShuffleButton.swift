//
//  ShuffleButton.swift
//  NavidromeClient
//
//  Created by Boris Eder on 18.09.25.
//

import SwiftUI

struct ShuffleButton: View {
    let album: Album
    let songs: [Song]
    @EnvironmentObject var playerVM: PlayerViewModel

    var body: some View {
        Button {
            Task { await playerVM.setPlaylist(songs.shuffled(), startIndex: 0, albumId: album.id) }
        } label: {
            Image(systemName: playerVM.isShuffling ? "shuffle.circle.fill" : "shuffle")
                .resizable()
                .scaledToFit()
                .frame(width: DSLayout.icon, height: DSLayout.icon)
                .foregroundColor(DSColor.secondary)
        }
    }
}
