import SwiftUI

struct CardItemContainer: View {
    @EnvironmentObject var deps: AppDependencies
    
    let content: CardContent
    let index: Int
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    
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
            
            if content.hasChevron {
                Image(systemName: "chevron.right")
                    .foregroundColor(DSColor.secondary)
            }
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

            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: DSCorners.tight))
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            } else if isLoading {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(.white)
            } else {
                Image(systemName: content.iconName)
                    .font(DSText.largeButton)
                    .foregroundColor(DSColor.primary.opacity(0.7))
            }
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
            loadedImage = await deps.coverArtManager.loadAlbumImage(
                album: album,
                size: imageSize,
                staggerIndex: index
            )
        case .artist(let artist):
            loadedImage = await deps.coverArtManager.loadArtistImage(
                artist: artist,
                size: imageSize,
                staggerIndex: index
            )
        case .genre:
            // Genres don't have images
            break
        }
    }
}
