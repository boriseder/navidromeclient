//
//  ShuffleButton.swift
//  NavidromeClient
//
//  Created by Boris Eder on 18.09.25.
//

import SwiftUI

struct ShuffleButton: View {

    @EnvironmentObject var deps: AppDependencies

    let album: Album
    let songs: [Song]
    
    var body: some View {
        Button {
            Task { await deps.playerVM.setPlaylist(songs.shuffled(), startIndex: 0, albumId: album.id) }
        } label: {
            Image(systemName: deps.playerVM.isShuffling ? "shuffle.circle.fill" : "shuffle")
                .resizable()
                .scaledToFit()
                .frame(width: DSLayout.icon, height: DSLayout.icon)
                .foregroundColor(DSColor.secondary)
        }
    }
}
