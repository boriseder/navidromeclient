//
//  SongImageView.swift - FIXED: Reactive State
//  NavidromeClient
//
//  ✅ FIXED: Views reagieren GARANTIERT auf CoverArtManager Updates
//

import SwiftUI

struct SongImageView: View {
    @EnvironmentObject var deps: AppDependencies
    
    let song: Song
    let isPlaying: Bool
    
    // ✅ CRITICAL: Local state that forces UI updates
    @State private var currentImage: UIImage?
    @State private var isLoading = false
    @State private var hasError = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DSCorners.element)
                .fill(DSColor.surface.opacity(isPlaying ? 0.2 : 0.1))
                .frame(width: DSLayout.listCover, height: DSLayout.listCover)
            
            Group {
                if let image = currentImage {
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
            await loadImageAsync()
        }
        // ✅ CRITICAL: Listen to CoverArtManager changes
        .onReceive(deps.coverArtManager.objectWillChange) {
            updateImageFromCache()
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
            ProgressView()
                .scaleEffect(0.6)
                .tint(.white)
        } else if hasError {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: DSLayout.smallIcon))
                .foregroundStyle(.orange)
        } else {
            Image(systemName: "music.note")
                .font(.system(size: DSLayout.largeIcon))
                .foregroundStyle(DSColor.onDark)
        }
    }
    
    // ✅ FIXED: Async loading with proper state management
    private func loadImageAsync() async {
        let imageSize = Int(DSLayout.miniCover * 3)
        
        // Check immediate cache first
        updateImageFromCache()
        if currentImage != nil { return }
        
        await MainActor.run {
            isLoading = true
            hasError = false
        }
        
        let loadedImage = await deps.coverArtManager.loadSongImage(
            song: song,
            size: imageSize
        )
        
        await MainActor.run {
            self.currentImage = loadedImage
            self.isLoading = false
            self.hasError = loadedImage == nil
        }
    }
    
    // ✅ CRITICAL: Update from cache when CoverArtManager changes
    private func updateImageFromCache() {
        let imageSize = Int(DSLayout.miniCover * 3)
        let cachedImage = deps.coverArtManager.getSongImage(for: song, size: imageSize)
        
        if cachedImage != currentImage {
            currentImage = cachedImage
        }
    }
}
