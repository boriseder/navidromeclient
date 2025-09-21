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
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        HStack(spacing: DSLayout.tightGap) {
            coverImageOrIconView()
                .task(id: content.id) {
                    await loadImage()
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
    private func coverImageOrIconView() -> some View {
        ZStack {
            Circle()
                .fill(DSColor.overlayLight)
                .frame(width: DSLayout.smallAvatar, height: DSLayout.smallAvatar)
            
            switch content {
            case .artist, .album:
                if let loadedImage = loadedImage {
                    Image(uiImage: loadedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: DSLayout.smallAvatar, height: DSLayout.smallAvatar)
                        .clipShape(content.clipShape)
                        .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                } else if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.white)
                } else if errorMessage != nil {
                    Image(systemName: "exclamationmark.triangle")
                        .font(DSText.largeButton)
                        .foregroundColor(DSColor.error)
                } else {
                    Image(systemName: content.iconName)
                        .font(.system(size: DSLayout.largeIcon))
                        .frame(width: DSLayout.smallAvatar, height: DSLayout.smallAvatar)
                        .scaledToFill()
                        .foregroundColor(DSColor.primary.opacity(0.7))
                }
            case .genre:
                Image(systemName: content.iconName)
                    .font(.system(size: DSLayout.largeIcon))
                    .frame(width: DSLayout.smallAvatar, height: DSLayout.smallAvatar)
                    .scaledToFill()
                    .foregroundColor(DSColor.primary.opacity(0.7))
            }
                
        }
        .frame(width: DSLayout.avatar, height: DSLayout.avatar)
    }
    
    
    private func loadImage() async {
        let imageSize = Int(DSLayout.smallAvatar * 3) // High res for sharp display

        isLoading = true
        defer { isLoading = false }

        switch content {
        case .album(let album):
            loadedImage = await coverArtManager.loadAlbumImage(
                album: album,
                size: imageSize,
                staggerIndex: index
            )
        case .artist(let artist):
            loadedImage = await coverArtManager.loadArtistImage(
                artist: artist,
                size: imageSize,
                staggerIndex: index
            )
        case .genre:
            // Genres don't have images
            break
        }
        
        if loadedImage == nil {
            errorMessage = "Image load failed"
        }
        isLoading = false

    }
}
