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
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @State private var coverImage: UIImage?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Album Cover
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearGradient(
                        colors: [accentColor.opacity(0.3), accentColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 140, height: 140)
                
                if let coverImage = coverImage {
                    Image(uiImage: coverImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 140, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        /*.overlay(
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .padding(6),
                            alignment: .topTrailing
                        )
                         */
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 32))
                        .foregroundColor(accentColor.opacity(0.7))
                }
            }
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            // Album Info
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
        .task {
            coverImage = await navidromeVM.loadCoverArt(for: album.id, size: 200)
        }
    }
}
