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
        HStack(spacing: DSLayout.sectionGap) {
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
    }
    
    @ViewBuilder
    private func coverImageOrIconView() -> some View {
        ZStack {
            // Background for the image/icon
            Circle()
                .fill(Color.gray)
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
                    .foregroundColor(DSColor.primary.opacity(0.7))
            }
        }
        .frame(width: DSLayout.smallAvatar, height: DSLayout.smallAvatar)
    }
    
    private func loadContentImage() async {
        switch content {
        case .album(let album):
            await coverArtManager.loadAlbumImage(
                album: album,
                size: Int(DSLayout.smallAvatar),
                staggerIndex: index
            )
        case .artist(let artist):
            await coverArtManager.loadArtistImage(
                artist: artist,
                size: Int(DSLayout.smallAvatar),
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
                .font(.system(size: 24))
                .foregroundColor(DSColor.error)
        } else {
            Image(systemName: content.iconName)
                .font(DSText.largeButton)
                .foregroundColor(DSColor.primary.opacity(0.7))
        }
    }
}

