//
//  CardItemContainer.swift - FIXED: Import CardContent
//  NavidromeClient
//
//  ELIMINATED: Custom image loading states and logic
//  CLEAN: Delegates to specialized image views
//

import SwiftUI

struct CardItemContainer: View {
    let content: CardContent
    let index: Int
    
    private let textHeight: CGFloat = 70 // fixe Höhe für Titel/Subtitel/Year
    
    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.elementGap) {
            imageView
                .scaledToFill()
                .frame(width: DSLayout.cardCover, height: DSLayout.cardCover)
                .clipShape(RoundedRectangle(cornerRadius: DSCorners.tight))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                .padding(DSLayout.elementPadding)
            
            VStack(alignment: .leading, spacing: DSLayout.elementGap) {
                Text(content.title)
                    .font(DSText.emphasized)
                    .foregroundColor(DSColor.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(content.subtitle)
                    .font(DSText.metadata)
                    .foregroundColor(DSColor.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if let year = content.year {
                    Text(year)
                        .font(DSText.footnote)
                        .foregroundColor(DSColor.tertiary)
                } else {
                    Text("").hidden() // Platzhalter, damit Höhe gleich bleibt
                }
            }
            .frame(height: textHeight)
            .frame(maxWidth: DSLayout.cardCover, alignment: .leading)
            .padding(DSLayout.elementPadding)

        }
        .background(DSMaterial.background) 
        .overlay(
            RoundedRectangle(cornerRadius: DSCorners.tight)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
        .cornerRadius(DSCorners.tight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(content.title), \(content.subtitle), \(content.year ?? "")")
    }
    
    @ViewBuilder
    private var imageView: some View {
        switch content {
        case .album(let album):
            AlbumImageView(album: album, index: index, size: DSLayout.cardCover)
        case .artist(let artist):
            ArtistImageView(artist: artist, index: index, size: DSLayout.cardCover)
        case .genre:
            staticGenreIcon
        }
    }
    
    @ViewBuilder
    private var staticGenreIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DSCorners.tight)
                .fill(LinearGradient(
                    colors: [DSColor.accent.opacity(0.3), DSColor.accent.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            
            Image(systemName: "music.note.list")
                .font(.system(size: DSLayout.largeIcon))
                .foregroundColor(DSColor.primary.opacity(0.7))
        }
        .frame(width: DSLayout.cardCover, height: DSLayout.cardCover)
        .clipShape(RoundedRectangle(cornerRadius: DSCorners.tight))
    }
}
