//
//  SongInfoView.swift
//  NavidromeClient
//
//  Created by Boris Eder on 21.09.25.
//
import SwiftUI

struct SongInfoView: View {
    let song: Song
    let isPlaying: Bool
    
    private var formattedYear: String {
        guard let year = song.year else { return "" }
        return String(year)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.tightGap) {
            Text(song.title)
                .font(DSText.emphasized)
                .foregroundStyle(isPlaying ? DSColor.playing : DSColor.primary)
                .lineLimit(1)
            
            Text(song.artist ?? "Unknown Artist")
                .font(DSText.emphasized)
                .foregroundStyle(DSColor.secondary)
                .lineLimit(1)
            
            HStack(spacing: DSLayout.elementGap) {
                if !song.album.isNilOrEmpty {
                    MetadataItem(
                        icon: "record.circle.fill",
                        text: song.album!,
                        fontSize: DSText.metadata
                    )
                }
                
                if !song.album.isNilOrEmpty && !formattedYear.isEmpty {
                    MetadataSeparator(fontSize: DSText.metadata)
                }
                
                if !formattedYear.isEmpty {
                    MetadataItem(
                        icon: "calendar",
                        text: formattedYear,
                        fontSize: DSText.metadata
                    )
                }
            }
        }
    }
}
