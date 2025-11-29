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
            HStack(spacing: 4) {
                Image(systemName: "shuffle")
                    .font(.system(size: DSLayout.smallIcon, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.orange)
            .clipShape(Capsule())
            .shadow(radius: 4)
        }
    }
}
