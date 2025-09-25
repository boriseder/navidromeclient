//
//  AlbumDetailHeaderView.swift - UPDATED: Consistent Image Loading
//

import SwiftUI

struct AlbumHeaderView: View {
    let album: Album
    let songs: [Song]
    let isOfflineAlbum: Bool
    
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var downloadManager: DownloadManager
    
    var body: some View {
        VStack(spacing: DSLayout.sectionGap) {
            let size = UIScreen.main.bounds.width * 0.9
            
            // Cover + Infos im Cover
            ZStack(alignment: .bottom) {
                AlbumImageView(album: album, index: 0, size: size)
                    .clipShape(RoundedRectangle(cornerRadius: DSCorners.content))
                    .shadow(radius: 10)
                    .padding(.top, DSLayout.screenGap)

                VStack(spacing: DSLayout.elementGap) {
                    Text(album.name)
                        .font(DSText.itemTitle)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                    
                    Text(album.artist)
                        .font(DSText.emphasized)
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text(buildMetadataString())
                        .font(DSText.metadata)
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(DSLayout.contentPadding)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.75), // deutlich dunkler unten
                            Color.black.opacity(0.4),  // mittlerer Übergang
                            Color.black.opacity(0.0)   // nach oben transparent
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: DSCorners.content))
            .shadow(radius: 10)
            
            // Buttons direkt unter dem Cover
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
            .padding(.top, DSLayout.elementGap)
            .padding(.bottom, DSLayout.contentPadding)        }
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
