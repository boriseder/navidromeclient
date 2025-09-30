//
//
//  ArtistImageView.swift - EXTENDED VERSION
//  NavidromeClient
//
//  Created by Boris Eder on 21.09.25.
//
import SwiftUI

struct ArtistImageView: View {
    @EnvironmentObject var coverArtManager: CoverArtManager
    
    let artist: Artist
    let index: Int
    let size: CGFloat?
    
    // Remove hasRequestedLoad state
    
    private var actualSize: CGFloat {
        size ?? DSLayout.smallAvatar
    }
    
    private var imageSize: Int {
        Int(actualSize * 3)
    }
    
    init(artist: Artist, index: Int, size: CGFloat? = nil) {
        self.artist = artist
        self.index = index
        self.size = size
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(DSColor.surface)
                .frame(width: actualSize, height: actualSize)
            
            Group {
                if let image = coverArtManager.getArtistImage(for: artist.id, size: imageSize) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: actualSize, height: actualSize)
                        .clipShape(Circle())
                        .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: actualSize, height: actualSize)
                        .overlay(artistImageOverlay)
                }
            }
        }
        // ✅ Use .task instead of .onAppear
        .task(id: artist.id) {
            await coverArtManager.loadArtistImage(
                artist: artist,
                size: imageSize,
                staggerIndex: index
            )
        }
    }
    
    @ViewBuilder
    private var artistImageOverlay: some View {
        if coverArtManager.isLoadingImage(for: artist.id, size: imageSize) {
            ProgressView()
                .scaleEffect(0.7)
                .tint(.white)
        } else if let error = coverArtManager.getImageError(for: artist.id, size: imageSize) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: DSLayout.smallIcon))
                .foregroundStyle(.orange)
        } else {
            Image(systemName: "music.mic")
                .font(.system(size: DSLayout.icon))
                .foregroundStyle(DSColor.onDark)
        }
    }
}
