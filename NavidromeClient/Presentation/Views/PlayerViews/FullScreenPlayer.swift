//
//  FullScreenPlayerView.swift - Spotify-Style Design
//  NavidromeClient
//
//   SPOTIFY-STYLE: Clean, minimal full-screen player
//   ENHANCED: Better visual hierarchy and gesture handling
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
    @State private var highResCoverArt: UIImage?
    
    var body: some View {
        ZStack {
            // Background (Spotify uses dark with subtle album art blur)
            SpotifyBackground(image: highResCoverArt ?? playerVM.coverArt)
            
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 16) {
                        // Top Bar
                        TopBar(dismiss: dismiss, showingQueue: $showingQueue, audioSessionManager: audioSessionManager)
                        
                        // Album Art (kompakt)
                        SpotifyAlbumArt(cover: highResCoverArt ?? playerVM.coverArt)
                            .scaleEffect(isDragging ? 0.95 : 1.0)
                            .animation(.spring(response: 0.3), value: isDragging)
                        
                        // Song Info
                        if let song = playerVM.currentSong {
                            SpotifySongInfoView(song: song, isPlaying: playerVM.isPlaying)
                        }
                        
                        // Progress Section
                        ProgressSection(playerVM: playerVM)
                            .padding(.horizontal, 8)
                        
                        // Main Controls
                        MainControls(playerVM: playerVM)
                        
                        // Bottom Controls - jetzt sichtbar
                        BottomControls(playerVM: playerVM)
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, max(0, geometry.safeAreaInsets.top))
                    .padding(.bottom, max(16, geometry.safeAreaInsets.bottom))
                    .frame(minHeight: geometry.size.height)
                }
            }
            .ignoresSafeArea(.container, edges: .top)
            .offset(y: dragOffset)
            .gesture(dismissGesture)
        }
        .statusBarHidden(false) // StatusBar wieder sichtbar
        .animation(.interactiveSpring(), value: dragOffset)
        .task(id: playerVM.currentSong?.id) {
            await loadHighResCoverArt()
        }
    }
    
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
    
    // MARK: - High-Res Cover Art Loading
    private func loadHighResCoverArt() async {
        guard let song = playerVM.currentSong,
              let albumId = song.albumId else { return }
        
        // Load high-resolution cover art for full screen
        if let cachedAlbum = AlbumMetadataCache.shared.getAlbum(id: albumId) {
            // Request 800x800 for sharp full-screen display
            highResCoverArt = await coverArtManager.loadAlbumImage(
                album: cachedAlbum,
                size: 800
            )
        }
    }
}

// MARK: - Spotify-Style Background
struct SpotifyBackground: View {
    let image: UIImage?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let cover = image {
                Image(uiImage: cover)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                    .blur(radius: 60)
                    .opacity(0.3)
                    .scaleEffect(1.2)
            }
        }
    }
}

// MARK: - Top Bar (zeigt Audio Route)
struct TopBar: View {
    let dismiss: DismissAction
    @Binding var showingQueue: Bool
    let audioSessionManager: AudioSessionManager
    
    var body: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("Abspielen auf")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                
                Text(audioOutputText)
                    .font(.system(size: 14, weight: .semibold))
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
    
    private var audioOutputText: String {
        if audioSessionManager.audioRoute.contains("Bluetooth") {
            return "Bluetooth"
        } else if audioSessionManager.audioRoute.contains("AirPlay") {
            return "AirPlay"
        } else if audioSessionManager.isHeadphonesConnected {
            return "Kopfhörer"
        } else {
            return "iPhone"
        }
    }
}

// MARK: - Spotify Album Art
struct SpotifyAlbumArt: View {
    let cover: UIImage?
    
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
        .frame(maxWidth: 280, maxHeight: 280)  // Kompakter
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Song Info Section (Spotify-style)
struct SpotifySongInfoView: View {
    let song: Song
    let isPlaying: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    if let artist = song.artist {
                        Text(artist)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Heart button (Spotify has this in top-right of song info)
                Button {
                    // TODO: Implement favorite
                } label: {
                    Image(systemName: "heart")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }
}

// MARK: - Progress Section (Spotify-style)
struct ProgressSection: View {
    @ObservedObject var playerVM: PlayerViewModel
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    
    var body: some View {
        VStack(spacing: 8) {
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.3))
                        .frame(height: 4)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white)
                        .frame(width: progressWidth(geometry.size.width), height: 4)
                    
                    // Drag handle
                    if isDragging {
                        Circle()
                            .fill(.white)
                            .frame(width: 14, height: 14)
                            .offset(x: progressWidth(geometry.size.width) - 7)
                    }
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
    }
    
    private func progressWidth(_ maxWidth: CGFloat) -> CGFloat {
        guard playerVM.duration > 0 else { return 0 }
        let progress = isDragging ? dragValue : (playerVM.currentTime / playerVM.duration)
        return maxWidth * progress
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

// MARK: - Main Controls (kompakter)
struct MainControls: View {
    @ObservedObject var playerVM: PlayerViewModel
    
    var body: some View {
        HStack(spacing: 32) {  // Weniger Abstand
            // Shuffle
            Button { playerVM.toggleShuffle() } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 20))  // Kleiner
                    .foregroundStyle(playerVM.isShuffling ? DSColor.accent : .white.opacity(0.7))
            }
            
            // Previous
            Button {
                Task { await playerVM.playPrevious() }
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 26))  // Kleiner
                    .foregroundStyle(.white)
            }
            
            // Play/Pause (kompakter)
            Button {
                playerVM.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 56, height: 56)  // Kleiner
                    
                    if playerVM.isLoading {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 22))  // Kleiner
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
                    .font(.system(size: 26))  // Kleiner
                    .foregroundStyle(.white)
            }
            
            // Repeat
            Button { playerVM.toggleRepeat() } label: {
                Image(systemName: repeatIcon)
                    .font(.system(size: 20))  // Kleiner
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
        case .all, .one: return DSColor.accent
        }
    }
}

// MARK: - Bottom Controls (jetzt mit mehr Platz)
struct BottomControls: View {
    @ObservedObject var playerVM: PlayerViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // Shuffle und Repeat
            HStack(spacing: 60) {
                // Shuffle
                Button { playerVM.toggleShuffle() } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 22))
                            .foregroundStyle(playerVM.isShuffling ? DSColor.accent : .white.opacity(0.7))
                        Text("Shuffle")
                            .font(.system(size: 11))
                            .foregroundStyle(playerVM.isShuffling ? DSColor.accent : .white.opacity(0.7))
                    }
                }
                
                // Repeat
                Button { playerVM.toggleRepeat() } label: {
                    VStack(spacing: 4) {
                        Image(systemName: repeatIcon)
                            .font(.system(size: 22))
                            .foregroundStyle(repeatColor)
                        Text(repeatText)
                            .font(.system(size: 11))
                            .foregroundStyle(repeatColor)
                    }
                }
            }
            
            // Audio Route und Share
            HStack {
                // Audio Route
                AudioRouteButton()
                
                Spacer()
                
                // Like Button
                Button {
                    // TODO: Implement favorite
                } label: {
                    Image(systemName: "heart")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.7))
                }
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
        case .all, .one: return DSColor.accent
        }
    }
    
    private var repeatText: String {
        switch playerVM.repeatMode {
        case .off: return "Repeat"
        case .all: return "Repeat"
        case .one: return "Repeat 1"
        }
    }
}

// MARK: - Audio Route Button (mit Label)
struct AudioRouteButton: View {
    var body: some View {
        ZStack {
            AudioRoutePickerViewRepresentable()
                .frame(width: 44, height: 44)
                .opacity(0.001)
            
            VStack(spacing: 4) {
                Image(systemName: "hifispeaker")
                    .font(.system(size: 22))
                    .foregroundStyle(.white.opacity(0.7))
                Text("Geräte")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}

// MARK: - AVRoutePickerView Wrapper
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
