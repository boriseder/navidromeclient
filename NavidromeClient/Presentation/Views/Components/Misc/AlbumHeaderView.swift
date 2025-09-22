//
//  AlbumHeaderView.swift
//  NavidromeClient
//
//  Created by Boris Eder on 21.09.25.
//
import SwiftUI

struct AlbumHeaderView: View {
    let album: Album
    let cover: UIImage?
    let songs: [Song]
    let isOfflineAlbum: Bool
    
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var downloadManager: DownloadManager
    
    var body: some View {
        HStack(spacing: DSLayout.sectionGap) {
            AlbumCoverView(cover: cover)
                .frame(width: DSLayout.cardCover, height: DSLayout.cardCover)
                .cardStyle()
            
            VStack(alignment: .leading, spacing: DSLayout.elementGap) {
                VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                    Text(album.name)
                        .font(DSText.sectionTitle)
                        .lineLimit(2)
                        .foregroundColor(DSColor.primary)
                    
                    Text(album.artist)
                        .font(DSText.emphasized)
                        .foregroundColor(DSColor.secondary)
                        .lineLimit(1)
                }
                
                Text(buildMetadataString())
                    .font(DSText.metadata)
                    .foregroundColor(DSColor.tertiary)
                    .lineLimit(1)
                
                HStack(spacing: DSLayout.elementGap) {
                    CompactPlayButton(album: album, songs: songs)
                    ShuffleButton(album: album, songs: songs)
                    
                    //  BESTEHENDE KOMPONENTE: DownloadButton
                    if !isOfflineAlbum {
                        DownloadButton(
                            album: album,
                            songs: songs,
                            navidromeVM: navidromeVM
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, DSLayout.screenGap)
        .cardStyle()
    }
    
    private func buildMetadataString() -> String {
        var parts: [String] = []
        
        if !songs.isEmpty {
            parts.append("\(songs.count) Song\(songs.count != 1 ? "s" : "")")
        }
        if let duration = album.duration {
            parts.append(formatDuration(duration))
        }
        if let year = album.year {
            parts.append("\(year)")
        }
        
        return parts.joined(separator: " • ")
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remaining = seconds % 60
        return String(format: "%d:%02d", minutes, remaining)
    }
}
