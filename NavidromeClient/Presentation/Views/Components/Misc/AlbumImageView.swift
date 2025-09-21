//
//  AlbumImageView.swift
//  NavidromeClient
//
//  Created by Boris Eder on 21.09.25.
//


struct AlbumImageView: View {
    @EnvironmentObject var coverArtManager: CoverArtManager

    let album: Album
    let index: Int
        
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DSCorners.element)
                .fill(DSColor.surface)
                .frame(width: DSLayout.listCover, height: DSLayout.listCover)
            
            Group {
                if let image = coverArtManager.getAlbumImage(for: album.id, size: Int(DSLayout.listCover*3)) {
                    //  REACTIVE: Uses centralized state
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: DSLayout.listCover, height: DSLayout.listCover)
                        .clipShape(RoundedRectangle(cornerRadius: DSCorners.element))
                        .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                } else {
                    RoundedRectangle(cornerRadius: DSCorners.element)
                        .fill(
                            LinearGradient(
                                colors: [.orange, .pink.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: DSLayout.smallAvatar, height: DSLayout.smallAvatar)
                        .overlay(albumImageOverlay)
                }
            }
        }
        .task(id: album.id) {
            //  SINGLE LINE: Manager handles staggering, caching, state
            await coverArtManager.loadAlbumImage(
                album: album,
                size: Int(DSLayout.listCover*3),
                staggerIndex: index
            )
        }
    }
    
    @ViewBuilder
    private var albumImageOverlay: some View {
        if coverArtManager.isLoadingImage(for: album.id, size: Int(DSLayout.listCover*3)) {
            //  REACTIVE: Uses centralized loading state
            ProgressView()
                .scaleEffect(0.7)
                .tint(.white)
        } else if let error = coverArtManager.getImageError(for: album.id, size: Int(DSLayout.listCover*3)) {
            //  NEW: Error state handling
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: DSLayout.smallIcon))
                .foregroundStyle(.orange)
        } else {
            Image(systemName: "record.circle.fill")
                .font(.system(size: DSLayout.icon))
                .foregroundStyle(DSColor.onDark)
        }
    }
}
