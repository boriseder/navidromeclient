//
//  ArtistCard.swift
//  NavidromeClient
//
//  Created by Boris Eder on 12.09.25.
//
import SwiftUI

// MARK: - Enhanced Artist Card
struct ArtistCard: View {
    let artist: Artist
    let index: Int
    
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @State private var artistImage: UIImage?
    @State private var isLoadingImage = false
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Artist Avatar with glow
            ZStack {
                Circle()
                    .fill(.black.opacity(0.1))
                    .frame(width: 70, height: 70)
                    .blur(radius: 1)
                
                // Main avatar
                Group {
                    if let image = artistImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 70, height: 70)
                            .clipShape(Circle())
                    } else if isLoadingImage {
                        Circle()
                            .fill(.regularMaterial)
                            .frame(width: 70, height: 70)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.primary)
                            )
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.red, Color.blue.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "music.mic")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.white.opacity(0.9))
                                )
                        }
                    }
                }
                .task {
                    await loadArtistImage()
                }

            // Artist Info
            VStack(alignment: .leading, spacing: 6) {
                Text(artist.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.black.opacity(0.9))
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Image(systemName: "record.circle")
                        .font(.caption)
                        .foregroundColor(.black.opacity(0.6))

                    if let count = artist.albumCount {
                        Text("\(count) Album\(count != 1 ? "s" : "")")
                            .font(.caption)
                            .foregroundColor(.black.opacity(0.6))
                            .lineLimit(1)

                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
        )
    }
    
    // MARK: - Helper Methods
    private func loadArtistImage() async {
        guard let coverId = artist.coverArt, !isLoadingImage else { return }
        isLoadingImage = true
        
        // This already goes through cache via NavidromeVM -> Service -> PersistentImageCache
        artistImage = await navidromeVM.loadCoverArt(for: coverId)
        
        isLoadingImage = false
    }
}
