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
    
    // REAKTIVER Cover Art Service
    @EnvironmentObject var coverArtService: ReactiveCoverArtService
    
    var body: some View {
        HStack(spacing: 16) {
            // Artist Avatar - REAKTIV
            ZStack {
                Circle()
                    .fill(.black.opacity(0.1))
                    .frame(width: 70, height: 70)
                    .blur(radius: 1)
                
                Group {
                    // REAKTIV: Automatisches Update
                    if let image = coverArtService.artistImage(for: artist, size: 120) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 70, height: 70)
                            .clipShape(Circle())
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
                            .onAppear {
                                // FIRE-AND-FORGET Request
                                if let coverArt = artist.coverArt {
                                    coverArtService.requestImage(for: coverArt, size: 120)
                                }
                            }
                    }
                }
            }

            // Artist Info (unchanged)
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
}
