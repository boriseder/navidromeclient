//
//  ListItemContainer.swift - REFACTORED: Eliminated Custom Loading
//  NavidromeClient
//
//  ELIMINATED: Custom image loading states and logic
//  CLEAN: Delegates to specialized image views
//

import SwiftUI

enum CardContent {
    case album(Album)
    case artist(Artist)
    case genre(Genre)
}

struct ListItemContainer: View {
    let content: CardContent
    let index: Int
    
    var body: some View {
        HStack(spacing: DSLayout.tightGap) {
            imageView
            
            VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                Text(content.title)
                    .font(DSText.emphasized)
                    .foregroundColor(DSColor.primary)
                    .lineLimit(1)
                
                Text(content.subtitle)
                    .font(DSText.metadata)
                    .foregroundColor(DSColor.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if content.hasChevron {
                Image(systemName: "chevron.right")
                    .foregroundColor(DSColor.secondary)
            }
        }
        .background(
            Color(DSColor.surfaceLight)
                .opacity(0.5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSCorners.tight)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
        .cornerRadius(DSCorners.tight)
    }
    
    @ViewBuilder
    private var imageView: some View {
        switch content {
        case .album(let album):
            AlbumImageView(album: album, index: index, size: DSLayout.smallAvatar)
                .clipShape(RoundedRectangle(cornerRadius: DSCorners.tight))
        case .artist(let artist):
            ArtistImageView(artist: artist, index: index, size: DSLayout.smallAvatar)
        case .genre:
            staticGenreIcon
        }
    }
    
    @ViewBuilder
    private var staticGenreIcon: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [DSColor.accent.opacity(0.3), DSColor.accent.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            
            Image(systemName: "music.note.list")
                .font(.system(size: DSLayout.icon))
                .foregroundColor(DSColor.primary.opacity(0.7))
        }
        .frame(width: DSLayout.smallAvatar, height: DSLayout.smallAvatar)
    }
}
