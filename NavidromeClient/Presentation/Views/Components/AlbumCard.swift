//
//  AlbumCard.swift - Enhanced with Design System
//  NavidromeClient
//
//  ✅ ENHANCED: Vollständige Anwendung des Design Systems
//

import SwiftUI

struct AlbumCard: View {
    let album: Album
    let accentColor: Color
    
    // REAKTIVER Cover Art Service
    @EnvironmentObject var coverArtService: ReactiveCoverArtService
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            // Album Cover - REAKTIV mit Design System
            ZStack {
                RoundedRectangle(cornerRadius: Radius.xs)
                    .fill(LinearGradient(
                        colors: [accentColor.opacity(0.3), accentColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: Sizes.card, height: Sizes.card)
                
                // REAKTIV: Automatisches Update wenn Bild geladen
                if let coverImage = coverArtService.coverImage(for: album, size: 200) {
                    Image(uiImage: coverImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: Sizes.card, height: Sizes.card)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.xs))
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: Sizes.iconLarge))
                        .foregroundColor(accentColor.opacity(0.7))
                        .onAppear {
                            // FIRE-AND-FORGET Request
                            coverArtService.requestImage(for: album.id, size: 200)
                        }
                }
            }
            .cardShadow()
            
            // Album Info mit Design System
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
                    Text(" ") // Spacer für konsistente Höhe
                        .font(Typography.caption2)
                        .foregroundColor(TextColor.tertiary)
                }
            }
            .frame(width: Sizes.card, alignment: .leading)
        }
    }
}
