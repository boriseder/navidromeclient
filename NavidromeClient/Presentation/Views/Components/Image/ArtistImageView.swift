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
    @State private var hasRequestedLoad = false

    let artist: Artist
    let index: Int
    let size: CGFloat?
    
    // Computed property for actual size
    private var actualSize: CGFloat {
        size ?? DSLayout.smallAvatar
    }
    
    // Computed property for image size (3x for high resolution)
    private var imageSize: Int {
        Int(actualSize * 3)
    }
    
    // Initializer with optional size parameter
    init(artist: Artist, index: Int, size: CGFloat? = nil) {
        self.artist = artist
        self.index = index
        self.size = size
    }
    
    //  UPDATED: Uses CoverArtManager instead of ReactiveCoverArtService
    // MIGRATED to AppDependencies
    
    var body: some View {
        ZStack {
            Circle()
                .fill(DSColor.surface)
                .frame(width: actualSize, height: actualSize)
            
            Group {
                if let image = coverArtManager.getArtistImage(for: artist.id, size: imageSize) {
                    //  REACTIVE: Uses centralized state
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
        .onAppear {
            if !hasRequestedLoad {
                hasRequestedLoad = true
                Task {
                    await coverArtManager.loadArtistImage(
                        artist: artist,
                        size: imageSize,
                        staggerIndex: index
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private var artistImageOverlay: some View {
        if coverArtManager.isLoadingImage(for: artist.id, size: imageSize) {
            //  REACTIVE: Uses centralized loading state
            ProgressView()
                .scaleEffect(0.7)
                .tint(.white)
        } else if let error = coverArtManager.getImageError(for: artist.id, size: imageSize) {
            //  NEW: Error state handling
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
