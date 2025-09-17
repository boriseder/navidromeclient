//
//  ArtistCard.swift - REFACTORED to Pure UI
//  NavidromeClient
//
//  ✅ CLEAN: All image loading logic moved to CoverArtManager
//  ✅ REACTIVE: Uses centralized state, automatic staggering handled by manager
//

import SwiftUI

struct ArtistCard: View {
    let artist: Artist
    let index: Int
    
    // ✅ UPDATED: Uses CoverArtManager instead of ReactiveCoverArtService
    @EnvironmentObject var coverArtManager: CoverArtManager
    
    var body: some View {
        HStack(spacing: DSLayout.contentGap) {
            // Artist Avatar - ✅ PURE UI
            artistAvatarView
                .task(id: artist.id) {
                    // ✅ SINGLE LINE: Manager handles staggering, caching, state
                    await coverArtManager.loadArtistImage(
                        artist: artist,
                        size: Int(DSLayout.smallAvatar),
                        staggerIndex: index
                    )
                }

            // Artist Info (unchanged)
            artistInfoView
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(DSText.metadata.weight(.semibold))
                .foregroundStyle(DSColor.tertiary)
        }
        .listItemPadding()
        .cardStyle()
    }
    
    // MARK: - ✅ Pure UI Components
    
    @ViewBuilder
    private var artistAvatarView: some View {
        ZStack {
            // Background blur
            Circle()
                .fill(DSColor.surface)
                .frame(width: DSLayout.smallAvatar, height: DSLayout.smallAvatar)
                .blur(radius: 1)
            
            // Avatar content
            Group {
                if let image = coverArtManager.getArtistImage(for: artist.id) {
                    // ✅ REACTIVE: Uses centralized state
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: DSLayout.smallAvatar, height: DSLayout.smallAvatar)
                        .clipShape(Circle())
                        .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                } else {
                    // Default avatar with loading state
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.red, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: DSLayout.smallAvatar, height: DSLayout.smallAvatar)
                        .overlay(avatarOverlay)
                }
            }
        }
    }
    
    @ViewBuilder
    private var avatarOverlay: some View {
        if coverArtManager.isLoadingImage(for: artist.id) {
            // ✅ REACTIVE: Uses centralized loading state
            ProgressView()
                .scaleEffect(0.7)
                .tint(.white)
        } else if let error = coverArtManager.getImageError(for: artist.id) {
            // ✅ NEW: Error state handling
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: DSLayout.icon))
                .foregroundStyle(.orange)
        } else {
            Image(systemName: "music.mic")
                .font(.system(size: DSLayout.icon))
                .foregroundStyle(DSColor.onDark)
        }
    }
    
    private var artistInfoView: some View {
        VStack(alignment: .leading, spacing: DSLayout.tightGap) {
            Text(artist.name)
                .font(DSText.emphasized)
                .foregroundColor(DSColor.primary)
                .lineLimit(1)

            HStack(spacing: DSLayout.tightGap) {
                Image(systemName: "record.circle")
                    .font(DSText.metadata)
                    .foregroundColor(DSColor.secondary)

                if let count = artist.albumCount {
                    Text("\(count) Album\(count != 1 ? "s" : "")")
                        .font(DSText.metadata)
                        .foregroundColor(DSColor.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}
