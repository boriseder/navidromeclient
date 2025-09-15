//
//  AlbumCard.swift - CLEAN Async Implementation
//  NavidromeClient
//
//  ✅ CORRECT: No UI blocking, proper async patterns
//

import SwiftUI

struct AlbumCard: View {
    let album: Album
    let accentColor: Color
    
    @EnvironmentObject var coverArtService: ReactiveCoverArtService
    
    // ✅ CORRECT: Local state for async loading
    @State private var coverImage: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            // Album Cover - CLEAN ASYNC
            ZStack {
                RoundedRectangle(cornerRadius: Radius.xs)
                    .fill(LinearGradient(
                        colors: [accentColor.opacity(0.3), accentColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: Sizes.card, height: Sizes.card)
                
                Group {
                    if let image = coverImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: Sizes.card, height: Sizes.card)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.xs))
                            .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                    } else {
                        Group {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(accentColor)
                            } else {
                                Image(systemName: "music.note")
                                    .font(.system(size: Sizes.iconLarge))
                                    .foregroundColor(accentColor.opacity(0.7))
                            }
                        }
                    }
                }
            }
            .cardShadow()
            .task(id: album.id) {
                await loadAlbumCover()
            }
            
            // Album Info (unchanged)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(album.name)
                    .font(Typography.bodyEmphasized)
                    .foregroundColor(TextColor.primary)
                    .lineLimit(1)
                
                Text(album.artist)
                    .font(Typography.caption)
                    .foregroundColor(TextColor.secondary)
                    .lineLimit(1)
                
                if let year = album.year {
                    Text(String(year))
                        .font(Typography.caption2)
                        .foregroundColor(TextColor.tertiary)
                } else {
                    Text(" ") // Spacer for consistent height
                        .font(Typography.caption2)
                        .foregroundColor(TextColor.tertiary)
                }
            }
            .frame(width: Sizes.card, alignment: .leading)
        }
    }
    
    // ✅ CORRECT: Proper async loading
    private func loadAlbumCover() async {
        // 1. Check cache first (fast, non-blocking)
        if let cached = coverArtService.getCachedAlbumCover(album, size: 200) {
            coverImage = cached
            return
        }
        
        // 2. Async loading with proper state management
        withAnimation(.easeInOut(duration: 0.2)) {
            isLoading = true
        }
        
        let loadedImage = await coverArtService.loadAlbumCover(album, size: 200)
        
        withAnimation(.easeInOut(duration: 0.3)) {
            coverImage = loadedImage
            isLoading = false
        }
    }
}
