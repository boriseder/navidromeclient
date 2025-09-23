//
//  AlbumDetailHeaderView.swift - UPDATED: Consistent Image Loading
//

import SwiftUI

struct AlbumHeaderView: View {
    let album: Album
    let cover: UIImage? // DEPRECATED: Will be removed
    let songs: [Song]
    let isOfflineAlbum: Bool
    
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var downloadManager: DownloadManager
    
    var body: some View {
        VStack(spacing: DSLayout.sectionGap) {
            let size = UIScreen.main.bounds.width * 0.7
            
            // UPDATED: Use AlbumImageView instead of custom logic
            AlbumImageView(album: album, index: 0, size: size)
                .clipShape(RoundedRectangle(cornerRadius: DSCorners.content))
                .shadow(radius: 10)
                .padding(.top, DSLayout.screenGap)
            
            // Album Info (unchanged)
            VStack(spacing: DSLayout.elementGap) {
                Text(album.name)
                    .font(DSText.itemTitle)
                    .multilineTextAlignment(.center)
                    .foregroundColor(DSColor.primary)
                
                Text(album.artist)
                    .font(DSText.emphasized)
                    .foregroundColor(DSColor.secondary)
                
                Text(buildMetadataString())
                    .font(DSText.metadata)
                    .foregroundColor(DSColor.tertiary)
            }
            .padding(.horizontal, DSLayout.contentPadding)
            
            // Action Buttons (unchanged)
            HStack(spacing: DSLayout.contentGap) {
                PlayButton(album: album, songs: songs)
                ShuffleButton(album: album, songs: songs)
                if !isOfflineAlbum {
                    DownloadButton(
                        album: album,
                        songs: songs,
                        navidromeVM: navidromeVM
                    )
                }
            }
            .padding(.horizontal, DSLayout.screenPadding)
            .padding(.bottom, DSLayout.contentPadding)
        }
    }
    
    // Helper methods unchanged
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
