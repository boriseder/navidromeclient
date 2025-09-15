//
//  ArtistCard.swift - CLEAN Async Implementation
//  NavidromeClient
//
//  ✅ CORRECT: No UI blocking, proper async patterns
//

import SwiftUI

struct ArtistCard: View {
    let artist: Artist
    let index: Int
    
    @EnvironmentObject var coverArtService: ReactiveCoverArtService
    
    // ✅ CORRECT: Local state for async loading
    @State private var artistImage: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        HStack(spacing: Spacing.m) {
            // Artist Avatar - CLEAN ASYNC
            ZStack {
                Circle()
                    .fill(BackgroundColor.secondary)
                    .frame(width: Sizes.avatarLarge, height: Sizes.avatarLarge)
                    .blur(radius: 1)
                
                Group {
                    if let image = artistImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: Sizes.avatarLarge, height: Sizes.avatarLarge)
                            .clipShape(Circle())
                            .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.red, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: Sizes.avatar, height: Sizes.avatar)
                            .overlay(
                                Group {
                                    if isLoading {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "music.mic")
                                            .font(.system(size: Sizes.icon))
                                            .foregroundStyle(TextColor.onDark)
                                    }
                                }
                            )
                    }
                }
            }
            .task(id: artist.id) {
                await loadArtistImage()
            }

            // Artist Info (unchanged)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(artist.name)
                    .font(Typography.bodyEmphasized)
                    .foregroundColor(TextColor.primary)
                    .lineLimit(1)

                HStack(spacing: Spacing.xs) {
                    Image(systemName: "record.circle")
                        .font(Typography.caption)
                        .foregroundColor(TextColor.secondary)

                    if let count = artist.albumCount {
                        Text("\(count) Album\(count != 1 ? "s" : "")")
                            .font(Typography.caption)
                            .foregroundColor(TextColor.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(TextColor.tertiary)
        }
        .listItemPadding()
        .materialCardStyle()
    }
    
    // ✅ CORRECT: Proper async loading
    private func loadArtistImage() async {
        // 1. Check cache first (fast, non-blocking)
        if let cached = coverArtService.getCachedArtistImage(artist, size: 120) {
            artistImage = cached
            return
        }
        
        // 2. Only proceed if we have coverArt
        guard artist.coverArt != nil else { return }
        
        // 3. Async loading with proper state management
        withAnimation(.easeInOut(duration: 0.2)) {
            isLoading = true
        }
        
        // Add staggered delay to prevent thundering herd
        let delay = UInt64(min(index * 50_000_000, 500_000_000)) // Max 500ms
        try? await Task.sleep(nanoseconds: delay)
        
        let loadedImage = await coverArtService.loadArtistImage(artist, size: 120)
        
        withAnimation(.easeInOut(duration: 0.3)) {
            artistImage = loadedImage
            isLoading = false
        }
    }
}
