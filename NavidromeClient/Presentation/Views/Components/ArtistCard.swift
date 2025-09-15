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
        HStack(spacing: Spacing.m) {
            // Artist Avatar - ✅ PURE UI
            artistAvatarView
                .task(id: artist.id) {
                    // ✅ SINGLE LINE: Manager handles staggering, caching, state
                    await coverArtManager.loadArtistImage(
                        artist: artist,
                        size: Int(Sizes.avatarLarge),
                        staggerIndex: index
                    )
                }

            // Artist Info (unchanged)
            artistInfoView
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(TextColor.tertiary)
        }
        .listItemPadding()
        .materialCardStyle()
    }
    
    // MARK: - ✅ Pure UI Components
    
    @ViewBuilder
    private var artistAvatarView: some View {
        ZStack {
            // Background blur
            Circle()
                .fill(BackgroundColor.secondary)
                .frame(width: Sizes.avatarLarge, height: Sizes.avatarLarge)
                .blur(radius: 1)
            
            // Avatar content
            Group {
                if let image = coverArtManager.getArtistImage(for: artist.id) {
                    // ✅ REACTIVE: Uses centralized state
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: Sizes.avatarLarge, height: Sizes.avatarLarge)
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
                        .frame(width: Sizes.avatar, height: Sizes.avatar)
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
                .font(.system(size: Sizes.icon))
                .foregroundStyle(.orange)
        } else {
            Image(systemName: "music.mic")
                .font(.system(size: Sizes.icon))
                .foregroundStyle(TextColor.onDark)
        }
    }
    
    private var artistInfoView: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(artist.name)
                .font(Typography.bodyEmphasized)
                .foregroundColor(TextColor.primary)
                .lineLimit(1)

            HStack(spacing: Spacing.xs) {
                Image(systemName: "record.circle")
                    .font(Typography.caption)
                    .foregroundColor(TextColor.secondary)

                if let count = artist.albumCount {
                    Text("\(count) Album\(count != 1 ? "s" : "")")
                        .font(Typography.caption)
                        .foregroundColor(TextColor.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}
