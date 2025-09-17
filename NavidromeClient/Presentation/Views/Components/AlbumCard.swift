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
        VStack(alignment: .leading, spacing: DSLayout.elementGap) {
            // Album Cover - ✅ PURE UI
            albumCoverView()
                .frame(width: DSLayout.cardCover, height: DSLayout.cardCover)
                .cardStyle()
                .task(id: album.id) {
                    // ✅ SINGLE LINE: Manager handles all complexity
                    await coverArtManager.loadAlbumImage(
                        album: album,
                        size: Int(DSLayout.cardCover),
                        staggerIndex: index
                    )
                }
            
            // Album Info (unchanged)
            albumInfoView
                .frame(width: DSLayout.cardCover, alignment: .leading)
        }
    }
    
    // MARK: - ✅ Pure UI Components
    
    @ViewBuilder
    private func albumCoverView() -> some View {
        ZStack {
            // Background gradient
            RoundedRectangle(cornerRadius: DSCorners.tight)
                .fill(LinearGradient(
                    colors: [accentColor.opacity(0.3), accentColor.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            
            // Image content
            if let image = coverArtManager.getAlbumImage(for: album.id) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: DSCorners.tight))
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            } else if coverArtManager.isLoadingImage(for: album.id) {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(accentColor)
            } else if coverArtManager.getImageError(for: album.id) != nil {
                VStack(spacing: DSLayout.tightGap) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: DSLayout.icon))
                        .foregroundColor(DSColor.error)
                    Text("Failed to load")
                        .font(DSText.body)
                        .foregroundColor(DSColor.error)
                }
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: DSLayout.largeIcon))
                    .foregroundColor(accentColor.opacity(0.7))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DSCorners.tight))
    }

    private var albumInfoView: some View {
        VStack(alignment: .leading, spacing: DSLayout.tightGap) {
            Text(album.name)
                .font(DSText.emphasized)
                .foregroundColor(DSColor.primary)
                .lineLimit(1)
            
            Text(album.artist)
                .font(DSText.metadata)
                .foregroundColor(DSColor.secondary)
                .lineLimit(1)
            
            if let year = album.year {
                Text(String(year))
                    .font(DSText.body)
                    .foregroundColor(DSColor.tertiary)
            } else {
                Text(" ") // Spacer for consistent height
                    .font(DSText.body)
                    .foregroundColor(DSColor.tertiary)
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
