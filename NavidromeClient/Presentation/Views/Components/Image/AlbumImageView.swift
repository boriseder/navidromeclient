//
//  AlbumImageView.swift
//  NavidromeClient
//
//  Created by Boris Eder on 21.09.25.
//
import SwiftUI

struct AlbumImageView: View {
    @EnvironmentObject var coverArtManager: CoverArtManager

    let album: Album
    let index: Int
    let size: CGFloat?
    
    // Computed property for actual size
    private var actualSize: CGFloat {
        size ?? DSLayout.listCover
    }
    
    // Computed property for image size (3x for high resolution)
    private var imageSize: Int {
        return 300 // CoverArtManager.OptimalSizes.album
    }
    
    // FIXED: Scale image on display instead of requesting different sizes
    private var displaySize: CGFloat {
        size ?? DSLayout.listCover
    }
    
    
    // Initializer with optional size parameter
    init(album: Album, index: Int, size: CGFloat? = nil) {
        self.album = album
        self.index = index
        self.size = size
    }
        
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DSCorners.element)
                .fill(DSColor.surface)
                .frame(width: displaySize, height: displaySize)

            Group {
                if let image = coverArtManager.getAlbumImage(for: album.id, size: imageSize) {
                    //  REACTIVE: Uses centralized state
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: displaySize, height: displaySize)
                        .clipShape(RoundedRectangle(cornerRadius: DSCorners.element))
                        .transition(.opacity.animation(.easeInOut(duration: 0.3)))
        
                    
                } else {
                    RoundedRectangle(cornerRadius: DSCorners.element)
                        .fill(
                            LinearGradient(
                                colors: [.orange, .pink.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: displaySize, height: displaySize)
                        .overlay(albumImageOverlay)
                }
            }
        }
        .task(id: album.id) {
            //  SINGLE LINE: Manager handles staggering, caching, state
            await coverArtManager.loadAlbumImage(
                album: album,
                size: imageSize,
                staggerIndex: index
            )
        }
    }
    
    @ViewBuilder
    private var albumImageOverlay: some View {
        if coverArtManager.isLoadingImage(for: album.id, size: imageSize) {
            //  REACTIVE: Uses centralized loading state
            ProgressView()
                .scaleEffect(0.7)
                .tint(.white)
        } else if let error = coverArtManager.getImageError(for: album.id, size: imageSize) {
            //  NEW: Error state handling
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: DSLayout.smallIcon))
                .foregroundStyle(.orange)
        } else {
            Image(systemName: "record.circle.fill")
                .font(.system(size: DSLayout.icon))
                .foregroundStyle(DSColor.onDark)
        }
    }
}
