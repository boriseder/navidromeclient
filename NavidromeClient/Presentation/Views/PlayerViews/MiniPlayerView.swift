import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var audioSessionManager: AudioSessionManager
    @State private var isDragging = false
    @State private var showFullScreen = false
    
    var body: some View {
        if let song = playerVM.currentSong {
            VStack(spacing: 0) {
                // MARK: Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(.quaternary)
                            .frame(height: 4)
                            .cornerRadius(2)
                        
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: geometry.size.width * progressPercentage, height: 4)
                            .cornerRadius(2)
                            .animation(isDragging ? nil : .linear(duration: 0.1), value: progressPercentage)
                        
                        // Drag Zone
                        Rectangle()
                            .fill(Color.clear)
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
                }
                .frame(height: 4)
                
                // MARK: Player HStack
                HStack(spacing: 16) {
                    // Cover + Song Info
                    HStack(spacing: 16) {
                        // Cover Art with Audio Route Indicator
                        ZStack {
                            Group {
                                if let cover = playerVM.coverArt {
                                    Image(uiImage: cover)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else {
                                    Rectangle()
                                        .fill(LinearGradient(
                                            colors: [.gray.opacity(0.3), .gray.opacity(0.5)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                        .overlay(
                                            Image(systemName: "music.note")
                                                .font(.title3)
                                                .foregroundStyle(.secondary)
                                        )
                                }
                            }
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            // Audio Route Indicator
                            if audioSessionManager.isHeadphonesConnected {
                                VStack {
                                    HStack {
                                        Spacer()
                                        Image(systemName: audioSessionManager.audioRoute.contains("Bluetooth") ? "bluetooth" : "headphones")
                                            .font(.caption2)
                                            .foregroundStyle(.white)
                                            .padding(2)
                                            .background(Circle().fill(.blue))
                                    }
                                    Spacer()
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.title)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .foregroundStyle(.primary)
                            
                            HStack(spacing: 4) {
                                if let artist = song.artist {
                                    Text(artist)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                
                                // Loading indicator
                                if playerVM.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .frame(width: 12, height: 12)
                                }
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showFullScreen = true
                    }
                    
                    Spacer()
                    
                    // MARK: Controls
                    HStack(spacing: 20) {
                        Button {
                            Task { await playerVM.playPrevious() }
                        } label: {
                            Image(systemName: "backward.fill")
                                .font(.title3)
                                .foregroundStyle(.primary)
                        }
                        .disabled(playerVM.isLoading)
                        
                        Button {
                            playerVM.togglePlayPause()
                        } label: {
                            ZStack {
                                if playerVM.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.title2)
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                            )
                            .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                        .disabled(playerVM.isLoading)
                        
                        Button {
                            Task { await playerVM.playNext() }
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.title3)
                                .foregroundStyle(.primary)
                        }
                        .disabled(playerVM.isLoading)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(.regularMaterial)
                
                // MARK: Audio Session Status Bar (Debug - entfernbar in Production)
                if ProcessInfo.processInfo.environment["DEBUG_AUDIO"] == "1" {
                    AudioStatusBar()
                        .environmentObject(audioSessionManager)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        playerVM.stop()
                    }
            )
            .gesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .local)
                    .onEnded { value in
                        if value.translation.height > 50 { // Swipe nach unten
                            playerVM.stop()
                        }
                    }
            )
            .clipShape(RoundedRectangle(cornerRadius: 0))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -2)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: playerVM.currentSong?.id)
            .fullScreenCover(isPresented: $showFullScreen) {
                FullScreenPlayerView()
                    .environmentObject(playerVM)
                    .environmentObject(navidromeVM)
                    .environmentObject(audioSessionManager)
            }
        }
    }
    
    private var progressPercentage: Double {
        guard playerVM.duration > 0 else { return 0 }
        return playerVM.currentTime / playerVM.duration
    }
}

// MARK: - Audio Status Bar (Debug)
struct AudioStatusBar: View {
    @EnvironmentObject var audioSessionManager: AudioSessionManager
    
    var body: some View {
        HStack(spacing: 8) {
            // Audio Session Status
            Circle()
                .fill(audioSessionManager.isAudioSessionActive ? .green : .red)
                .frame(width: 6, height: 6)
            
            Text("Audio: \(audioSessionManager.audioRoute)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            if audioSessionManager.isHeadphonesConnected {
                Image(systemName: "headphones")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
    }
}
