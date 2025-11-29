//
//  CompactPlayButton.swift
//  NavidromeClient
//
//  Created by Boris Eder on 18.09.25.
//
import SwiftUI

struct PlayButton: View {
    let album: Album
    let songs: [Song]
    @EnvironmentObject var playerVM: PlayerViewModel

    var body: some View {
        Button {
            Task { await playerVM.setPlaylist(songs, startIndex: 0, albumId: album.id) }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "play.fill")
                    .font(.system(size: DSLayout.smallIcon, weight: .semibold))
                //Text("Play")
                //    .font(DSText.metadata.weight(.semibold))
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
