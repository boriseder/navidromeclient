//
//  ArtistCard.swift - FIXED SwiftUI Generic Issue
//  NavidromeClient
//
//  ✅ FIXED: SwiftUI generic parameter issue in Circle gradient
//

import SwiftUI

// MARK: - Enhanced Artist Card
struct ArtistCard: View {
    let artist: Artist
    let index: Int
    
    // REAKTIVER Cover Art Service
    @EnvironmentObject var coverArtService: ReactiveCoverArtService
    
    var body: some View {
        HStack(spacing: Spacing.m) {
            // Artist Avatar - REAKTIV mit Design System
            ZStack {
                Circle()
                    .fill(BackgroundColor.secondary)
                    .frame(width: Sizes.avatarLarge, height: Sizes.avatarLarge)
                    .blur(radius: 1)
                
                Group {
                    // REAKTIV: Automatisches Update
                    if let image = coverArtService.artistImage(for: artist, size: 120) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: Sizes.avatarLarge, height: Sizes.avatarLarge)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.red, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: Sizes.avatar, height: Sizes.avatar)
                            .overlay(
                                Image(systemName: "music.mic")
                                    .font(.system(size: Sizes.icon))
                                    .foregroundStyle(TextColor.onDark)
                            )
                            .onAppear {
                                // ✅ FIXED: Don't call requestImage - it doesn't exist in new API
                                // The reactive system will handle loading automatically
                            }
                    }
                }
            }

            // Artist Info mit Design System
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
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(TextColor.tertiary)
        }
        .listItemPadding()
        .materialCardStyle()
    }
}
