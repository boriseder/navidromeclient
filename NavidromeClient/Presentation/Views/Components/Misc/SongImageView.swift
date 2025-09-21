//
//  SongImageView.swift
//  NavidromeClient
//
//  Created by Boris Eder on 21.09.25.
//


struct SongImageView: View {
    @EnvironmentObject var coverArtManager: CoverArtManager

    let song: Song
    let isPlaying: Bool
    
    //  UPDATED: Uses CoverArtManager instead of ReactiveCoverArtService
    // MIGRATED to AppDependencies
    
    //  REACTIVE: Get song image via centralized state
    private var songImage: UIImage? {
        coverArtManager.getSongImage(for: song, size: Int(DSLayout.miniCover))
    }
    
    //  REACTIVE: Get loading state via centralized state
    private var isLoading: Bool {
        guard let albumId = song.albumId else { return false }
        return coverArtManager.isLoadingImage(for: albumId, size: Int(DSLayout.miniCover))
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DSCorners.element)
                .fill(DSColor.surface.opacity(isPlaying ? 0.2 : 0.1))
                .frame(width: DSLayout.listCover, height: DSLayout.listCover)
            
            Group {
                if let image = songImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: DSLayout.miniCover, height: DSLayout.miniCover)
                        .clipShape(RoundedRectangle(cornerRadius: DSCorners.element))
                        .overlay(playingOverlay)
                        .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                } else {
                    RoundedRectangle(cornerRadius: DSCorners.element)
                        .fill(
                            LinearGradient(
                                colors: [.green, .blue.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: DSLayout.miniCover, height: DSLayout.miniCover)
                        .overlay(songImageOverlay)
                }
            }
        }
        .task(id: song.albumId) {
            //  SINGLE LINE: Manager handles all complexity
            _ = await coverArtManager.loadSongImage(song: song, size: Int(DSLayout.miniCover))
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
        if isLoading {
            //  REACTIVE: Uses centralized loading state
            ProgressView()
                .scaleEffect(0.6)
                .tint(.white)
        } else if let albumId = song.albumId, let error = coverArtManager.getImageError(for: albumId, size: Int(DSLayout.smallAvatar*3)) {
            //  NEW: Error state handling
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
