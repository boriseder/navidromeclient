//
//  ArtistCard.swift - Enhanced with Design System
//  NavidromeClient
//
//  ✅ ENHANCED: Vollständige Anwendung des Design Systems
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
                    .frame(width: Sizes.avatarLarge, height: Sizes.avatarLarge) // 100pt aus Design System
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
                                    colors: [Color.red, Color.blue.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: Sizes.avatar, height: Sizes.avatar) // 72pt aus Design System
                            .overlay(
                                Image(systemName: "music.mic")
                                    .font(.system(size: Sizes.icon))
                                    .foregroundStyle(TextColor.onDark)
                            )
                            .onAppear {
                                // FIRE-AND-FORGET Request
                                if let coverArt = artist.coverArt {
                                    coverArtService.requestImage(for: coverArt, size: 120)
                                }
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
