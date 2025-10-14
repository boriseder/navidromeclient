//
//  CardItemContainer.swift
//  NavidromeClient
//
//  REFACTORED: Context-aware image display
//

import SwiftUI

struct CardItemContainer: View {
    let content: CardContent
    let index: Int
    
    private let textHeight: CGFloat = 40
    
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack {
                    Text(content.subtitle)
                        .font(DSText.metadata)
                        .foregroundColor(DSColor.secondary)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let year = content.year {
                        Text(year)
                            .font(DSText.footnote)
                            .foregroundColor(DSColor.tertiary)
                    } else {
                        Text("").hidden()
                    }
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
            AlbumImageView(album: album, index: index, context: .card)
        case .artist(let artist):
            ArtistImageView(artist: artist, index: index, context: .artistCard)
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
