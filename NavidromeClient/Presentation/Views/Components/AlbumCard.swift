//
//  AlbumCard.swift
//  NavidromeClient
//
//  Created by Boris Eder on 12.09.25.
//

import SwiftUI

struct AlbumCard: View {
    let album: Album
    let accentColor: Color
    
    // REAKTIVER Cover Art Service
    @EnvironmentObject var coverArtService: ReactiveCoverArtService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Album Cover - REAKTIV
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearGradient(
                        colors: [accentColor.opacity(0.3), accentColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 140, height: 140)
                
                // REAKTIV: Automatisches Update wenn Bild geladen
                if let coverImage = coverArtService.coverImage(for: album, size: 200) {
                    Image(uiImage: coverImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 140, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 32))
                        .foregroundColor(accentColor.opacity(0.7))
                        .onAppear {
                            // FIRE-AND-FORGET Request
                            coverArtService.requestImage(for: album.id, size: 200)
                        }
                }
            }
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            
            // Album Info (unchanged)
            VStack(alignment: .leading, spacing: 2) {
                Text(album.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.black.opacity(0.9))
                    .lineLimit(1)
                
                Text(album.artist)
                    .font(.caption)
                    .foregroundColor(.black.opacity(0.6))
                    .lineLimit(1)
                
                if let year = album.year {
                    Text(String(year))
                        .font(.caption2)
                        .foregroundColor(.black.opacity(0.5))
                } else {
                    Text(String(" "))
                        .font(.caption2)
                        .foregroundColor(.black.opacity(0.5))
                }
            }
            .frame(width: 140, alignment: .leading)
        }
    }
}
