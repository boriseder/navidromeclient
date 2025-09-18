//
//  MiniPlayerView.swift - Spotify-Style Design
//  NavidromeClient
//
//   SPOTIFY-STYLE: Clean, minimal design with full background tap
//   ENHANCED: Better visual hierarchy and interaction zones
//

import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var audioSessionManager: AudioSessionManager
    @State private var showFullScreen = false
    @State private var isDragging = false
    
    var body: some View {
        if let song = playerVM.currentSong {
            VStack(spacing: 0) {
                // Progress Bar (Spotify-style: thin, prominent)
                ProgressBarView(playerVM: playerVM, isDragging: $isDragging)
                
                // Main Player Content
                HStack(spacing: DSLayout.contentGap) {
                    // Left: Album Art + Song Info
                    HStack(spacing: DSLayout.contentGap) {
                        AlbumArtView(cover: playerVM.coverArt)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(DSColor.primary)
                                .lineLimit(1)
                            
                            if let artist = song.artist {
                                Text(artist)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(DSColor.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer()
                    
                    // Right: Controls (Spotify-style: minimal)
                    HStack(spacing: 16) {
                        // Heart/Like button (Spotify has this)
                        Button {
                            // TODO: Implement favorite functionality
                        } label: {
                            Image(systemName: "heart")
                                .font(.system(size: 18))
                                .foregroundStyle(DSColor.secondary)
                        }
                        
                        // Play/Pause (Primary control)
                        Button {
                            playerVM.togglePlayPause()
                        } label: {
                            if playerVM.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .frame(width: 32, height: 32)
                            } else {
                                Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(DSColor.primary)
                                    .frame(width: 32, height: 32)
                            }
                        }
                        .disabled(playerVM.isLoading)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    ZStack {
                        // Blurred Cover Art Background
                        if let cover = playerVM.coverArt {
                            Image(uiImage: cover)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .blur(radius: 20)
                                .opacity(0.3)
                                .clipped()
                        }
                        
                        // Dark overlay for readability
                        DSColor.surface.opacity(0.8)
                    }
                )
                .contentShape(Rectangle()) // Makes entire area tappable
                .onTapGesture {
                    showFullScreen = true
                }
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            if value.translation.height < -50 {
                                // Swipe up to open full screen
                                showFullScreen = true
                            } else if value.translation.height > 50 {
                                // Swipe down to dismiss
                                playerVM.stop()
                            }
                        }
                )
            }
            .background(
                ZStack {
                    // Blurred Cover Art Background
                    if let cover = playerVM.coverArt {
                        Image(uiImage: cover)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .blur(radius: 20)
                            .opacity(0.3)
                            .clipped()
                    }
                    
                    // Dark overlay
                    DSColor.surface.opacity(0.8)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 0))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -2)
            .fullScreenCover(isPresented: $showFullScreen) {
                FullScreenPlayerView()
                    .environmentObject(playerVM)
                    .environmentObject(audioSessionManager)
            }
        }
    }
}

// MARK: - Progress Bar (Spotify-style)
struct ProgressBarView: View {
    @ObservedObject var playerVM: PlayerViewModel
    @Binding var isDragging: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 2)
                
                // Progress track (Spotify green when playing)
                Rectangle()
                    .fill(playerVM.isPlaying ? Color.green : Color.gray)
                    .frame(width: geometry.size.width * progressPercentage, height: 2)
                    .animation(isDragging ? nil : .linear(duration: 0.1), value: progressPercentage)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let progress = max(0, min(value.location.x / geometry.size.width, 1))
                        let newTime = progress * playerVM.duration
                        playerVM.seek(to: newTime)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
        .frame(height: 2)
    }
    
    private var progressPercentage: Double {
        guard playerVM.duration > 0 else { return 0 }
        return playerVM.currentTime / playerVM.duration
    }
}

// MARK: - Album Art (Spotify-style)
struct AlbumArtView: View {
    let cover: UIImage?
    
    var body: some View {
        Group {
            if let cover = cover {
                Image(uiImage: cover)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 20))
                            .foregroundStyle(.gray)
                    )
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
