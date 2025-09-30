//
//  SongImageView.swift
//  NavidromeClient
//
//  Created by Boris Eder on 21.09.25.
//
import SwiftUI

struct SongImageView: View {
    @EnvironmentObject var coverArtManager: CoverArtManager

    let song: Song
    let isPlaying: Bool
    
    // Remove state management entirely
    
    private var loadedimage: UIImage? {
        coverArtManager.getSongImage(for: song, size: Int(DSLayout.miniCover))
    }
    
    private var isLoading: Bool {
        guard let albumId = song.albumId else { return false }
        return coverArtManager.isLoadingImage(for: albumId, size: Int(DSLayout.miniCover))
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DSCorners.tight)
                .fill(LinearGradient(
                    colors: [DSColor.accent.opacity(0.3), DSColor.accent.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            if let image = loadedimage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: DSCorners.tight))
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            } else if isLoading {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(.white)
            } else {
                songImageOverlay
            }
            
            playingOverlay
        }
        // ✅ Use .task with song.albumId as identity
        .task(id: song.albumId) {
            _ = await coverArtManager.loadSongImage(
                song: song,
                size: Int(DSLayout.miniCover)
            )
        }
    }
    
    @ViewBuilder
    private var playingOverlay: some View {
        if isPlaying {
            RoundedRectangle(cornerRadius: DSCorners.element)
                .fill(DSColor.playing.opacity(0.3))
                .overlay(
                    Image(systemName: "speaker.wave.2.fill")
                        .font(DSText.metadata)
                        .foregroundStyle(DSColor.playing)
                )
        }
    }
    
    @ViewBuilder
    private var songImageOverlay: some View {
        if let albumId = song.albumId,
           let error = coverArtManager.getImageError(for: albumId, size: Int(DSLayout.smallAvatar*3)) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: DSLayout.smallIcon))
                .foregroundStyle(.orange)
        } else {
            Image(systemName: "music.note")
                .font(.system(size: DSLayout.largeIcon))
                .foregroundStyle(DSColor.onDark)
        }
    }
}
