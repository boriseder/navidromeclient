//
//  SearchResultSongRow.swift
//  NavidromeClient
//
//  Created by Boris Eder on 21.09.25.
//

import SwiftUI

struct SearchResultSongRow: View {
    let song: Song
    let index: Int
    let isPlaying: Bool
    let action: () -> Void
    
    //  UPDATED: Uses CoverArtManager instead of ReactiveCoverArtService
    @EnvironmentObject var coverArtManager: CoverArtManager
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DSLayout.contentGap) {
                //  REACTIVE: Uses centralized state
                SongImageView(song: song, isPlaying: isPlaying)
                SongInfoView(song: song, isPlaying: isPlaying)
                Spacer()
                SongDurationView(duration: song.duration)
            }
            .listItemPadding()
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}
