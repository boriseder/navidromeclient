//
//  FullScreenPlayerView.swift - FIXED: Use CoverArtManager Directly
//  NavidromeClient
//
//   FIXED: Removed dependency on playerVM.coverArt
//   CLEAN: Direct CoverArtManager integration for both regular and high-res images
//   CONSISTENT: Single source of truth for cover art
//

import SwiftUI
import AVKit

struct FullScreenPlayerView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var audioSessionManager: AudioSessionManager
    @EnvironmentObject var coverArtManager: CoverArtManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var showingQueue = false
    
    // Add cached cover art state
    @State private var cachedRegularCoverArt: UIImage?
    @State private var cachedHighResCoverArt: UIImage?
    @State private var cachedAlbumId: String?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 5) {
                    TopBar(dismiss: dismiss, showingQueue: $showingQueue)
                        .padding(.horizontal, 20)
                    Spacer(minLength: 30)
                    
                    SpotifyAlbumArt(cover: cachedHighResCoverArt ?? cachedRegularCoverArt, screenWidth: geometry.size.width)
                        .scaleEffect(isDragging ? 0.95 : 1.0)
                        .animation(.spring(response: 0.3), value: isDragging)

                    Spacer(minLength: 20)

                    if let song = playerVM.currentSong {
                        SpotifySongInfoView(song: song, screenWidth: geometry.size.width)
                    }
                                        
                    Spacer(minLength: 16)
                    
                    ProgressSection(playerVM: playerVM, screenWidth: geometry.size.width)
                    
                    Spacer(minLength: 24)
                    
                    MainControls(playerVM: playerVM)
                    
                    Spacer()
                    BottomControls(playerVM: playerVM, audioSessionManager: audioSessionManager, screenWidth: geometry.size.width)
                }
                .frame(maxWidth: geometry.size.width*0.95, maxHeight: geometry.size.height*0.95)
                .padding(.horizontal, 10)
                .padding(.top, 70)
                .padding(.bottom, 20)
                .background {
                    SpotifyBackground(image: cachedHighResCoverArt ?? cachedRegularCoverArt)
                }
            }
            .ignoresSafeArea(.container, edges: [.top, .bottom])
            .offset(y: dragOffset)
            .gesture(dismissGesture)
            .background(Color.black)
        }
        .animation(.interactiveSpring(), value: dragOffset)
        .sheet(isPresented: $showingQueue) {
            QueueView()
                .environmentObject(playerVM)
                .environmentObject(coverArtManager)
        }
        .onAppear {
            updateCoverArtCache()
        }
        .onChange(of: playerVM.currentSong?.albumId) { _, _ in
            updateCoverArtCache()
        }
    }
    
    private func updateCoverArtCache() {
        guard let albumId = playerVM.currentSong?.albumId else {
            cachedRegularCoverArt = nil
            cachedHighResCoverArt = nil
            cachedAlbumId = nil
            return
        }
        
        guard albumId != cachedAlbumId else { return }
        
        cachedRegularCoverArt = coverArtManager.getAlbumImage(for: albumId, size: 300)
        cachedHighResCoverArt = coverArtManager.getAlbumImage(for: albumId, size: 800)
        cachedAlbumId = albumId
    }
    
    // Keep existing gesture and other methods unchanged
    private var dismissGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if value.translation.height > 0 {
                    dragOffset = value.translation.height
                    isDragging = true
                }
            }
            .onEnded { value in
                isDragging = false
                if value.translation.height > 200 {
                    dismiss()
                } else {
                    withAnimation(.spring()) {
                        dragOffset = 0
                    }
                }
            }
    }
}
// MARK: - Background unchanged
struct SpotifyBackground: View {
    let image: UIImage?
    
    var body: some View {
        ZStack {
            if let cover = image {
                Image(uiImage: cover)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 20)
                    .opacity(0.9)
                    .scaleEffect(1.4)
                    .brightness(-0.4)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - TopBar unchanged
struct TopBar: View {
    let dismiss: DismissAction
    @Binding var showingQueue: Bool
    
    var body: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            
            Spacer()
            
            Button {
                showingQueue = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Album Art unchanged
struct SpotifyAlbumArt: View {
    let cover: UIImage?
    let screenWidth: CGFloat
    
    var body: some View {
        Group {
            if let cover = cover {
                Image(uiImage: cover)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 60))
                            .foregroundStyle(.gray)
                    )
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        //BORIS
        //.frame(width: min(280, screenWidth - 80), height: min(280, screenWidth - 80))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Song Info unchanged
struct SpotifySongInfoView: View {
    let song: Song
    let screenWidth: CGFloat
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                if let artist = song.artist {
                    Text(artist)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            HeartButton.fullScreen(song: song)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Progress Section unchanged
struct ProgressSection: View {
    @ObservedObject var playerVM: PlayerViewModel
    let screenWidth: CGFloat
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    
    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.3))
                        .frame(height: 4)
                    
                    // Progress track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white)
                        .frame(width: progressWidth(geometry.size.width), height: 4)
                    
                    Circle()
                        .fill(.white)
                        .frame(width: isDragging ? 16 : 12, height: isDragging ? 16 : 12)
                        .offset(x: progressWidth(geometry.size.width) - (isDragging ? 8 : 6))
                        .animation(.easeInOut(duration: 0.1), value: isDragging)
                }
                .gesture(progressGesture(geometry.size.width))
            }
            .frame(height: 20)
            
            // Time Labels
            HStack {
                Text(formatTime(isDragging ? dragValue * playerVM.duration : playerVM.currentTime))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                
                Spacer()
                
                Text(formatTime(playerVM.duration))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: screenWidth - 40)
        .padding(.horizontal, 20)
    }
    
    private func progressWidth(_ maxWidth: CGFloat) -> CGFloat {
        guard playerVM.duration > 0 else { return 0 }
        let progress = isDragging ? dragValue : (playerVM.currentTime / playerVM.duration)
        return min(maxWidth * progress, maxWidth)
    }
    
    private func progressGesture(_ maxWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isDragging = true
                let progress = max(0, min(value.location.x / maxWidth, 1))
                dragValue = progress
            }
            .onEnded { value in
                let progress = max(0, min(value.location.x / maxWidth, 1))
                playerVM.seek(to: progress * playerVM.duration)
                isDragging = false
            }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Main Controls unchanged
struct MainControls: View {
    @ObservedObject var playerVM: PlayerViewModel
    
    var body: some View {
        HStack(spacing: 30) {
            // Shuffle
            Button { playerVM.toggleShuffle() } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 22))
                    .foregroundStyle(playerVM.isShuffling ? .green : .white.opacity(0.7))
            }
            
            // Previous
            Button {
                Task { await playerVM.playPrevious() }
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
            }
            
            // Play/Pause
            Button {
                playerVM.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 64, height: 64)
                    
                    if playerVM.isLoading {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.black)
                            .offset(x: playerVM.isPlaying ? 0 : 2)
                    }
                }
            }
            
            // Next
            Button {
                Task { await playerVM.playNext() }
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
            }
            
            // Repeat
            Button { playerVM.toggleRepeat() } label: {
                Image(systemName: repeatIcon)
                    .font(.system(size: 22))
                    .foregroundStyle(repeatColor)
            }
        }
    }
    
    private var repeatIcon: String {
        switch playerVM.repeatMode {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
    
    private var repeatColor: Color {
        switch playerVM.repeatMode {
        case .off: return .white.opacity(0.7)
        case .all, .one: return .green
        }
    }
}

// MARK: - Bottom Controls unchanged
struct BottomControls: View {
    @ObservedObject var playerVM: PlayerViewModel
    let audioSessionManager: AudioSessionManager
    let screenWidth: CGFloat
    
    var body: some View {
        HStack {
            AudioSourceButton(audioSessionManager: audioSessionManager)
            
            Spacer()
        }
        .frame(maxWidth: screenWidth - 40)
        .padding(.horizontal, 20)
    }
}

// MARK: - Audio Source Button unchanged
struct AudioSourceButton: View {
    let audioSessionManager: AudioSessionManager
    
    var body: some View {
        ZStack {
            AudioRoutePickerViewRepresentable()
                .frame(width: 44, height: 44)
                .opacity(0.001)
            
            VStack(spacing: 4) {
                Image(systemName: audioSourceIcon)
                    .font(.system(size: 24))
                    .foregroundStyle(.white.opacity(0.7))
                
                Text(audioSourceText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
    
    private var audioSourceIcon: String {
        if audioSessionManager.isHeadphonesConnected {
            return "headphones"
        } else if audioSessionManager.audioRoute.contains("Bluetooth") {
            return "airpods"
        } else {
            return "speaker.wave.2"
        }
    }
    
    private var audioSourceText: String {
        if audioSessionManager.isHeadphonesConnected {
            return "Kopfhörer"
        } else if audioSessionManager.audioRoute.contains("Bluetooth") {
            return "Bluetooth"
        } else {
            return "iPhone"
        }
    }
}

// MARK: - AVRoutePickerView unchanged
struct AudioRoutePickerViewRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let routePickerView = AVRoutePickerView()
        routePickerView.backgroundColor = UIColor.clear
        routePickerView.tintColor = UIColor.white
        routePickerView.prioritizesVideoDevices = false
        return routePickerView
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
