//
//  ArtistImageView.swift
//  NavidromeClient
//
//  REFACTORED: Context-aware image loading with smooth transitions
//

import SwiftUI

struct ArtistImageView: View {
    @EnvironmentObject var coverArtManager: CoverArtManager
    @State private var showImage = false
    
    let artist: Artist
    let index: Int
    let context: ImageContext
    
    private var displaySize: CGFloat {
        return context.displaySize
    }
    
    init(artist: Artist, index: Int, context: ImageContext) {
        self.artist = artist
        self.index = index
        self.context = context
    }
    
    var body: some View {
        ZStack {
            // Always show placeholder
            placeholderView
                .opacity(showImage ? 0 : 1)
            
            // Fade in actual image
            if let image = coverArtManager.getArtistImage(for: artist.id, context: context) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: displaySize, height: displaySize)
                    .clipped() // verhindert Überlauf
                    .aspectRatio(1, contentMode: .fill)
                    .opacity(showImage ? 1 : 0)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showImage = true
                        }
                    }
                    .overlay(
                        Rectangle()
                            .stroke(DSColor.onLight.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: DSColor.onLight.opacity(0.1), radius: 4, x: 0, y: 2)

            }
        }
        .frame(width: displaySize, height: displaySize)
        .task(id: artist.id) {
            await coverArtManager.loadArtistImage(
                for: artist.id,
                context: context,
                staggerIndex: index
            )
        }
    }
    
    @ViewBuilder
    private var placeholderView: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.blue, .purple.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: displaySize, height: displaySize)
            .overlay(placeholderOverlay)
    }
    
    @ViewBuilder
    private var placeholderOverlay: some View {
        if coverArtManager.isLoadingImage(for: artist.id, size: context.size) {
            ProgressView()
                .scaleEffect(0.7)
                .tint(.white)
        } else if let error = coverArtManager.getImageError(for: artist.id, size: context.size) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: DSLayout.smallIcon))
                .foregroundStyle(.white.opacity(0.8))
        } else {
            Image(systemName: "music.mic")
                .font(.system(size: DSLayout.icon))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}
