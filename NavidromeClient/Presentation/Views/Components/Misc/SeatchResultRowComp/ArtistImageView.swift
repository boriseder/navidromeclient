//
//  ArtistImageView.swift
//  NavidromeClient
//
//  Created by Boris Eder on 21.09.25.
//
import SwiftUI

struct ArtistImageView: View {
    @EnvironmentObject var coverArtManager: CoverArtManager

    let artist: Artist
    let index: Int
    
    //  UPDATED: Uses CoverArtManager instead of ReactiveCoverArtService
    // MIGRATED to AppDependencies
    
    var body: some View {
        ZStack {
            Circle()
                .fill(DSColor.surface)
                .frame(width: DSLayout.smallAvatar, height: DSLayout.smallAvatar)
            
            Group {
                if let image = coverArtManager.getArtistImage(for: artist.id, size: Int(DSLayout.smallAvatar*3)) {
                    //  REACTIVE: Uses centralized state
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: DSLayout.smallAvatar, height: DSLayout.smallAvatar)
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
                        .frame(width: DSLayout.smallAvatar, height: DSLayout.smallAvatar)
                        .overlay(artistImageOverlay)
                }
            }
        }
        .task(id: artist.id) {
            //  SINGLE LINE: Manager handles staggering, caching, state
            await coverArtManager.loadArtistImage(
                artist: artist,
                size: Int(DSLayout.smallAvatar*3),
                staggerIndex: index
            )
        }
    }
    
    @ViewBuilder
    private var artistImageOverlay: some View {
        if coverArtManager.isLoadingImage(for: artist.id, size: Int(DSLayout.smallAvatar*3)) {
            //  REACTIVE: Uses centralized loading state
            ProgressView()
                .scaleEffect(0.7)
                .tint(.white)
        } else if let error = coverArtManager.getImageError(for: artist.id, size: Int(DSLayout.smallAvatar*3)) {
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
