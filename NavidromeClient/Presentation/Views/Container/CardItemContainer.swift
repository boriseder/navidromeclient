import SwiftUI

struct CardItemContainer: View {
    @EnvironmentObject var coverArtManager: CoverArtManager

    let content: CardContent
    let index: Int
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.elementGap) {
            
            coverImageView()
                .task(id: content.id) {
                    await loadImage()
                }

            VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                Text(content.title)
                    .font(DSText.emphasized)
                    .foregroundColor(DSColor.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(content.subtitle)
                    .font(DSText.metadata)
                    .foregroundColor(DSColor.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if let year = content.year {
                    Text(year)
                        .font(DSText.footnote)
                        .foregroundColor(DSColor.tertiary)
                } else {
                    Text("").hidden()
                }
            }
            .frame(maxWidth: DSLayout.cardCover)
        }
        .padding(DSLayout.elementPadding)
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
    private func coverImageView() -> some View {
        ZStack {

            RoundedRectangle(cornerRadius: DSCorners.tight)
                .fill(LinearGradient(
                    colors: [DSColor.accent.opacity(0.3), DSColor.accent.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            // Content mit stabilem frame
            Group {
                if let image = loadedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if isLoading {
                    ProgressView().scaleEffect(0.7)
                } else if errorMessage != nil {
                    Image(systemName: "exclamationmark.triangle")
                } else {
                    Image(systemName: content.iconName)
                }
            }
            .frame(width: DSLayout.cardCover, height: DSLayout.cardCover) // CRITICAL: Stable frame
        }
        .frame(width: DSLayout.cardCover, height: DSLayout.cardCover)
        .clipShape(RoundedRectangle(cornerRadius: DSCorners.tight))
    }
    
    private func loadImage() async {
        let imageSize = Int(DSLayout.cardCover * 3) // High res for sharp display
        
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
