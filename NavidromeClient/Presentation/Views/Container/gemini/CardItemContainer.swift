//
//  CardContent.swift
//  NavidromeClient
//
//  Created by Boris Eder on 18.09.25.
//


import SwiftUI

//
//  CardContent.swift
//  NavidromeClient
//
//  Created by Boris Eder on 18.09.25.
//


import SwiftUI

struct CardItemContainer: View {
    @EnvironmentObject var coverArtManager: CoverArtManager
    let content: CardContent
    let index: Int
        
    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.elementGap) {
            coverImageOrIconView()
                .task(id: content.id) {
                    await loadContentImage()
                }

            VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                Text(content.title)
                    .font(DSText.emphasized)
                    .foregroundColor(DSColor.primary)
                    .lineLimit(1)

                Text(content.subtitle)
                    .font(DSText.metadata)
                    .foregroundColor(DSColor.secondary)
                    .lineLimit(1)
                
                if let year = content.year {
                    Text(year)
                        .font(DSText.footnote)
                        .foregroundColor(DSColor.tertiary)
                } else {
                    Text("").hidden() // konsistenter Spacer
                }
            }
            
            if content.hasChevron {
                Image(systemName: "chevron.right")
                    .foregroundColor(DSColor.secondary)
            }
        }
        .padding(DSLayout.elementPadding)
        .background(
            Color(DSColor.surfaceLight) // hellgrau
                .opacity(0.5)   // leicht transparent
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSCorners.tight) // abgerundete Ecken
                .stroke(Color(.systemGray4), lineWidth: 0.5) // Haarlinie
        )
        .cornerRadius(DSCorners.tight) // sorgt für das Clipping der Background

    }
    
    @ViewBuilder
    private func coverImageOrIconView() -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: DSCorners.tight)
                .fill(LinearGradient(
                    colors: [DSColor.accent.opacity(0.3), DSColor.accent.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            switch content {
            case .album:
                imageDisplayView(image: coverArtManager.getAlbumImage(for: content.id))
            case .artist:
                imageDisplayView(image: coverArtManager.getArtistImage(for: content.id))
            case .genre:
                Image(systemName: content.iconName)
                    .foregroundColor(DSColor.primary.opacity(0.7))
            }
        }
        .frame(width: DSLayout.cardCover, height: DSLayout.cardCover)
        .clipShape(RoundedRectangle(cornerRadius: DSCorners.tight))
    }
    
    private func loadContentImage() async {
        switch content {
        case .album(let album):
            await coverArtManager.loadAlbumImage(
                album: album,
                size: Int(DSLayout.cardCover),
                staggerIndex: index
            )
        case .artist(let artist):
            await coverArtManager.loadArtistImage(
                artist: artist,
                size: Int(DSLayout.cardCover),
                staggerIndex: index
            )
        case .genre:
            // Genres don't have images to load, so we do nothing here
            return
        }

    }
    
    @ViewBuilder
    private func imageDisplayView(image: UIImage?) -> some View {
        if let loadedImage = image {
            Image(uiImage: loadedImage)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: DSCorners.tight))
                .transition(.opacity)
        } else if coverArtManager.loadingStates[content.id] ?? false {
            ProgressView()
                .scaleEffect(0.7)
                .tint(.white)
        } else if coverArtManager.errorStates[content.id] != nil {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundColor(DSColor.error)
        } else {
            Image(systemName: content.iconName)
                .font(DSText.largeButton)
                .foregroundColor(DSColor.primary.opacity(0.7))
        }
    }
}

