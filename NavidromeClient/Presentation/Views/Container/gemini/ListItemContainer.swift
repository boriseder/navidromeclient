import SwiftUI

enum CardContent {
    case album(Album)
    case artist(Artist)
    case genre(Genre)
}
struct ListItemContainer: View {
    @EnvironmentObject var coverArtManager: CoverArtManager
    let content: CardContent
    let index: Int
    
    var body: some View {
        HStack(spacing: DSLayout.tightGap) {
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
            }
            
            Spacer()
            
            if content.hasChevron {
                Image(systemName: "chevron.right")
                    .foregroundColor(DSColor.secondary)
            }
        }
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
            // Background for the image/icon
            Circle()
                .fill(DSColor.overlayLight)
                .frame(width: DSLayout.smallAvatar, height: DSLayout.smallAvatar)
            
            switch content {
            case .album:
                let image = coverArtManager.getAlbumImage(for: content.id)
                imageDisplayView(image: image)
            case .artist:
                let image = coverArtManager.getArtistImage(for: content.id)
                imageDisplayView(image: image)
            case .genre:
                // Genres have no images to load
                Image(systemName: content.iconName)
                    .font(.system(size: DSLayout.smallAvatar * 0.5))
                    .frame(width: DSLayout.smallAvatar, height: DSLayout.smallAvatar)
                    .foregroundColor(DSColor.onDark)
            }
        }
        .frame(width: DSLayout.avatar, height: DSLayout.avatar)
    }
    
    private func loadContentImage() async {
        switch content {
        case .album(let album):
            await coverArtManager.loadAlbumImage(
                album: album,
                size: Int(DSLayout.avatar),
                staggerIndex: index
            )
        case .artist(let artist):
            await coverArtManager.loadArtistImage(
                artist: artist,
                size: Int(DSLayout.avatar),
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
                .frame(width: DSLayout.smallAvatar, height: DSLayout.smallAvatar)
                .clipShape(content.clipShape)
                .transition(.opacity.animation(.easeInOut(duration: 0.3)))
        } else if coverArtManager.loadingStates[content.id] ?? false {
            ProgressView()
                .scaleEffect(0.7)
                .tint(.white)
        } else if coverArtManager.errorStates[content.id] != nil {
            Image(systemName: "exclamationmark.triangle")
                .font(DSText.largeButton)
                .foregroundColor(DSColor.error)
        } else {
            Image(systemName: content.iconName)
                .font(.system(size: DSLayout.smallAvatar * 0.8))
                .frame(width: DSLayout.smallAvatar, height: DSLayout.smallAvatar)
                .scaledToFill()
                .foregroundColor(DSColor.primary.opacity(0.7))
        }
    }
}

