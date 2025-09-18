//
//  CompactPlayButton.swift
//  NavidromeClient
//
//  Created by Boris Eder on 18.09.25.
//
import SwiftUI

struct CompactPlayButton: View {
    let album: Album
    let songs: [Song]
    @EnvironmentObject var playerVM: PlayerViewModel

    var body: some View {
        Button {
            Task { await playerVM.setPlaylist(songs, startIndex: 0, albumId: album.id) }
        } label: {
            HStack(spacing: DSLayout.tightGap) {
                Image(systemName: "play.fill")
                    .font(.system(size: DSLayout.smallIcon, weight: .semibold))
                Text("Play")
                    .font(DSText.metadata.weight(.semibold))
            }
            .foregroundColor(DSColor.onDark)
            .padding(.horizontal, DSLayout.elementPadding)
            .padding(.vertical, DSLayout.tightPadding)
            .background(
                Capsule()
                    .fill(DSColor.accent)
            )
        }
    }
}
