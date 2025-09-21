//
//  ArtistInfoView.swift
//  NavidromeClient
//
//  Created by Boris Eder on 21.09.25.
//
import SwiftUI

struct ArtistInfoView: View {
    let artist: Artist
    
    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.tightGap) {
            Text(artist.name)
                .font(DSText.prominent)
                .foregroundStyle(DSColor.primary)
                .lineLimit(1)
            
            HStack(spacing: DSLayout.elementGap) {
                Image(systemName: "music.mic")
                    .font(DSText.metadata)
                    .foregroundStyle(DSColor.secondary)
                
                if let count = artist.albumCount {
                    Text("\(count) Album\(count != 1 ? "s" : "")")
                        .font(DSText.metadata.weight(.medium))
                        .foregroundStyle(DSColor.secondary)
                }
            }
        }
    }
}
