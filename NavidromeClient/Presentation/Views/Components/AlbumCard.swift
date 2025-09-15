//
//  AlbumCard.swift - REFACTORED to Pure UI
//  NavidromeClient
//
//  ✅ CLEAN: All business logic moved to CoverArtManager
//  ✅ REACTIVE: Uses centralized state instead of local @State
//

import SwiftUI

struct AlbumCard: View {
    let album: Album
    let accentColor: Color
    let index: Int // For staggered loading
    
    // ✅ UPDATED: Uses CoverArtManager instead of ReactiveCoverArtService
    @EnvironmentObject var coverArtManager: CoverArtManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            // Album Cover - ✅ PURE UI
            albumCoverView
                .frame(width: Sizes.card, height: Sizes.card)
                .cardShadow()
                .task(id: album.id) {
                    // ✅ SINGLE LINE: Manager handles all complexity
                    await coverArtManager.loadAlbumImage(
                        album: album,
                        size: Int(Sizes.card),
                        staggerIndex: index
                    )
                }
            
            // Album Info (unchanged)
            albumInfoView
                .frame(width: Sizes.card, alignment: .leading)
        }
    }
    
    // MARK: - ✅ Pure UI Components
    
    @ViewBuilder
    private var albumCoverView: some View {
        ZStack {
            // Background gradient
            RoundedRectangle(cornerRadius: Radius.xs)
                .fill(LinearGradient(
                    colors: [accentColor.opacity(0.3), accentColor.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            
            // Image content
            Group {
                if let image = coverArtManager.getAlbumImage(for: album.id) {
                    // ✅ REACTIVE: Uses centralized state
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: Radius.xs))
                        .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                } else if coverArtManager.isLoadingImage(for: album.id) {
                    // ✅ REACTIVE: Uses centralized loading state
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(accentColor)
                } else if let error = coverArtManager.getImageError(for: album.id) {
                    // ✅ NEW: Error state handling
                    VStack(spacing: Spacing.xs) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: Sizes.icon))
                            .foregroundColor(BrandColor.error)
                        Text("Failed to load")
                            .font(Typography.caption2)
                            .foregroundColor(BrandColor.error)
                    }
                } else {
                    // Placeholder
                    Image(systemName: "music.note")
                        .font(.system(size: Sizes.iconLarge))
                        .foregroundColor(accentColor.opacity(0.7))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.xs))
    }
    
    private var albumInfoView: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(album.name)
                .font(Typography.bodyEmphasized)
                .foregroundColor(TextColor.primary)
                .lineLimit(1)
            
            Text(album.artist)
                .font(Typography.caption)
                .foregroundColor(TextColor.secondary)
                .lineLimit(1)
            
            if let year = album.year {
                Text(String(year))
                    .font(Typography.caption2)
                    .foregroundColor(TextColor.tertiary)
            } else {
                Text(" ") // Spacer for consistent height
                    .font(Typography.caption2)
                    .foregroundColor(TextColor.tertiary)
            }
        }
    }
}

// MARK: - ✅ Preview Helper
extension AlbumCard {
    /// Convenience initializer without index for simple usage
    init(album: Album, accentColor: Color) {
        self.album = album
        self.accentColor = accentColor
        self.index = 0
    }
}
