//
//  AlbumImageView.swift
//  NavidromeClient
//
//  REFACTORED: Context-aware image loading with smooth transitions
//

import SwiftUI

struct AlbumImageView: View {
    @EnvironmentObject var coverArtManager: CoverArtManager

    let album: Album
    let index: Int
    let context: ImageContext
    
    private var displaySize: CGFloat {
        return context.displaySize
    }
    
    private var hasImage: Bool {
        coverArtManager.getAlbumImage(for: album.id, context: context) != nil
    }
    
    init(album: Album, index: Int, context: ImageContext) {
        self.album = album
        self.index = index
        self.context = context
    }
        
    var body: some View {
        ZStack {
            placeholderView
                .opacity(hasImage ? 0 : 1)
            
            if let image = coverArtManager.getAlbumImage(for: album.id, context: context) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: displaySize, height: displaySize)
                    .clipShape(RoundedRectangle(cornerRadius: DSCorners.element))
                    .opacity(hasImage ? 1 : 0)
                    .transition(.opacity)
            }
        }
        .frame(width: displaySize, height: displaySize)
        .animation(.easeInOut(duration: 0.3), value: hasImage)
        .task(id: "\(album.id)_\(context.size)") {
            // FIXED: Use .task instead of .onAppear for proper cancellation and idempotency
            await coverArtManager.loadAlbumImage(
                for: album.id,
                context: context,
                staggerIndex: index
            )
        }
    }
    
    @ViewBuilder
    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: DSCorners.element)
            .fill(
                LinearGradient(
                    colors: [.orange, .pink.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: displaySize, height: displaySize)
            .overlay(placeholderOverlay)
    }
    
    @ViewBuilder
    private var placeholderOverlay: some View {
        if coverArtManager.isLoadingImage(for: album.id, size: context.size) {
            ProgressView()
                .scaleEffect(0.7)
                .tint(.white)
        } else if let error = coverArtManager.getImageError(for: album.id, size: context.size) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: DSLayout.smallIcon))
                .foregroundStyle(.white.opacity(0.8))
        } else {
            Image(systemName: "record.circle.fill")
                .font(.system(size: DSLayout.icon))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}
