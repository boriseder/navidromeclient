//
//  FullScreenPlayerView.swift - Enhanced with Audio Route Picker
//  NavidromeClient
//
//  ✅ ADDED: Audio Route Picker for AirPlay/Bluetooth selection
//

import SwiftUI
import AVKit

// MARK: - Full Screen Player (Enhanced with DS)
struct FullScreenPlayerView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var audioSessionManager: AudioSessionManager
    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var showingQueue = false
    @State private var showingSettings = false

    var body: some View {
        ZStack {
            BackgroundView(image: playerVM.coverArt)

            VStack(spacing: DSLayout.sectionGap) {
                PlayerTopBar(
                    dismiss: dismiss,
                    showingQueue: $showingQueue,
                    showingSettings: $showingSettings,
                    audioSessionManager: audioSessionManager
                )

                Spacer()

                CoverArtView(cover: playerVM.coverArt)
                    .frame(width: DSLayout.detailCover, height: DSLayout.detailCover)
                    .scaleEffect(isDragging ? 0.95 : 1.0)
                    .animation(Animations.spring, value: isDragging)

                if let song = playerVM.currentSong {
                    PlayerSongInfoView(
                        song: song,
                        isPlaying: playerVM.isPlaying,
                        isLoading: playerVM.isLoading
                    )
                }

                PlayerProgressView(playerVM: playerVM)

                PlaybackControls(playerVM: playerVM)
                
                VolumeSlider(playerVM: playerVM)
                
                Spacer()

                // ✅ ENHANCED: Bottom controls with Audio Route Picker
                EnhancedBottomControls(playerVM: playerVM)
                    .padding(.bottom, DSLayout.screenPadding)
            }
            .padding(.top, DSLayout.sectionGap)
            .screenPadding()
        }
        .statusBarHidden()
        .offset(y: dragOffset)
        .gesture(dismissDragGesture)
        .highPriorityGesture(longPressDismissGesture)
        .animation(Animations.interactive, value: dragOffset)
        .sheet(isPresented: $showingQueue) {
          //  QueueView()
           //     .environmentObject(playerVM)
        }
        .sheet(isPresented: $showingSettings) {
         //   AudioSettingsView()
           //     .environmentObject(audioSessionManager)
           //     .environmentObject(playerVM)
        }
    }

    // MARK: - Drag Down Gesture (unchanged)
    private var dismissDragGesture: some Gesture {
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
                    withAnimation(Animations.spring) {
                        dismiss()
                    }
                } else {
                    withAnimation(Animations.spring) {
                        dragOffset = 0
                    }
                }
            }
    }

    // MARK: - Long Press Gesture (unchanged)
    private var longPressDismissGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .onEnded { _ in
                withAnimation(Animations.spring) {
                    playerVM.stop()
                    dismiss()
                }
            }
    }
}

// MARK: - ✅ NEW: Enhanced Bottom Controls with Audio Route Picker
struct EnhancedBottomControls: View {
    @ObservedObject var playerVM: PlayerViewModel
    @StateObject private var audioSessionManager = AudioSessionManager.shared

    var body: some View {
        HStack(spacing: 40) { // Increased spacing for 3 buttons
            
            // Shuffle Button
            Button { playerVM.toggleShuffle() } label: {
                VStack(spacing: DSLayout.tightGap) {
                    Image(systemName: "shuffle")
                        .font(DSText.sectionTitle)
                        .foregroundStyle(playerVM.isShuffling ? DSColor.accent : DSColor.onDarkSecondary)
                    
                    Text("Shuffle")
                        .font(DSText.body)
                        .foregroundStyle(playerVM.isShuffling ? DSColor.accent : DSColor.onDarkSecondary)
                }
            }

            // ✅ NEW: Audio Route Picker Button
            AudioRoutePickerButton()
            
            // Repeat Button
            Button { playerVM.toggleRepeat() } label: {
                VStack(spacing: DSLayout.tightGap) {
                    Image(systemName: repeatIcon)
                        .font(DSText.sectionTitle)
                        .foregroundStyle(repeatColor)
                    
                    Text(repeatText)
                        .font(DSText.body)
                        .foregroundStyle(repeatColor)
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
        case .off: return DSColor.onDarkSecondary
        case .all, .one: return DSColor.accent
        }
    }
    
    private var repeatText: String {
        switch playerVM.repeatMode {
        case .off: return "Repeat"
        case .all: return "All"
        case .one: return "One"
        }
    }
}

// MARK: - ✅ NEW: Audio Route Picker Button
struct AudioRoutePickerButton: View {
    @StateObject private var audioSessionManager = AudioSessionManager.shared
    
    var body: some View {
        ZStack {
            // Hidden AVRoutePickerView for functionality
            AudioRoutePickerViewRepresentable()
                .frame(width: 44, height: 44) // Match button size
                .opacity(0.001) // Nearly invisible but still interactive
            
            // Custom UI Button
            VStack(spacing: DSLayout.tightGap) {
                Image(systemName: audioRouteIcon)
                    .font(DSText.sectionTitle)
                    .foregroundStyle(audioRouteColor)
                
                Text(audioRouteText)
                    .font(DSText.body)
                    .foregroundStyle(audioRouteColor)
            }
        }
    }
    
    private var audioRouteIcon: String {
        if audioSessionManager.audioRoute.contains("Bluetooth") {
            return "bluetooth"
        } else if audioSessionManager.isHeadphonesConnected {
            return "headphones"
        } else if audioSessionManager.audioRoute.contains("AirPlay") {
            return "airplayaudio"
        } else {
            return "speaker.wave.2"
        }
    }
    
    private var audioRouteColor: Color {
        if audioSessionManager.isHeadphonesConnected ||
           audioSessionManager.audioRoute.contains("Bluetooth") ||
           audioSessionManager.audioRoute.contains("AirPlay") {
            return DSColor.accent
        } else {
            return DSColor.onDarkSecondary
        }
    }
    
    private var audioRouteText: String {
        if audioSessionManager.audioRoute.contains("Bluetooth") {
            return "Bluetooth"
        } else if audioSessionManager.audioRoute.contains("AirPlay") {
            return "AirPlay"
        } else if audioSessionManager.isHeadphonesConnected {
            return "Headphones"
        } else {
            return "Speaker"
        }
    }
}

// MARK: - ✅ NEW: AVRoutePickerView UIKit Wrapper
struct AudioRoutePickerViewRepresentable: UIViewRepresentable {
    
    func makeUIView(context: Context) -> AVRoutePickerView {
        let routePickerView = AVRoutePickerView()
        
        // Customize appearance
        routePickerView.backgroundColor = UIColor.clear
        routePickerView.tintColor = UIColor.systemBlue
        
        // Hide the default button - we show our custom UI
        routePickerView.prioritizesVideoDevices = false
        
        return routePickerView
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        // Updates handled automatically by AVRoutePickerView
    }
}

// MARK: - Existing Components (unchanged but keeping for completeness)

// Enhanced Top Bar
struct PlayerTopBar: View {
    var dismiss: DismissAction
    @Binding var showingQueue: Bool
    @Binding var showingSettings: Bool
    let audioSessionManager: AudioSessionManager

    var body: some View {
        HStack {
            CircleButton(icon: "chevron.down") { dismiss() }
            
            Spacer()
            
            VStack(spacing: DSLayout.tightGap) {
                Text("Playing from")
                    .font(DSText.metadata)
                    .foregroundStyle(DSColor.onDarkSecondary)
                
                HStack(spacing: DSLayout.tightGap) {
                    // Audio Route Indicator
                    if audioSessionManager.isHeadphonesConnected {
                        Image(systemName: audioRouteIcon)
                            .font(DSText.body)
                            .foregroundStyle(DSColor.onDark.opacity(0.8))
                    }
                    
                    Text(audioRouteText)
                        .font(DSText.metadata.weight(.semibold))
                        .foregroundStyle(DSColor.onDark)
                }
            }
            
            Spacer()
            
            HStack(spacing: DSLayout.elementGap) {
                CircleButton(icon: "list.bullet") {
                    showingQueue = true
                }
                
                CircleButton(icon: "gear") {
                    showingSettings = true
                }
            }
        }
    }
    
    private var audioRouteIcon: String {
        if audioSessionManager.audioRoute.contains("Bluetooth") {
            return "bluetooth"
        } else if audioSessionManager.isHeadphonesConnected {
            return "headphones"
        } else {
            return "speaker.wave.2"
        }
    }
    
    private var audioRouteText: String {
        if audioSessionManager.audioRoute.contains("Bluetooth") {
            return "Bluetooth"
        } else if audioSessionManager.isHeadphonesConnected {
            return "Headphones"
        } else {
            return "Speaker"
        }
    }
}

// Cover Art View (unchanged)
struct CoverArtView: View {
    let cover: UIImage?

    var body: some View {
        Group {
            if let cover = cover {
                Image(uiImage: cover)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                RoundedRectangle(cornerRadius: DSCorners.comfortable)
                    .fill(DSColor.background)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 80))
                            .foregroundStyle(DSColor.onDark.opacity(0.6))
                    )
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .coverStyle()
        .overlay(
            RoundedRectangle(cornerRadius: DSCorners.comfortable)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// Song Info View (unchanged)
struct PlayerSongInfoView: View {
    let song: Song
    let isPlaying: Bool
    let isLoading: Bool

    var body: some View {
        VStack(spacing: DSLayout.elementGap) {
            HStack {
                Text(song.title)
                    .font(isPlaying ? DSText.sectionTitle : DSText.sectionTitle)
                    .foregroundStyle(isPlaying ? DSColor.playing : DSColor.onDark)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: DSColor.onDark))
                        .scaleEffect(0.8)
                        .frame(width: DSLayout.largeIcon, height: DSLayout.largeIcon)
                }
            }

            if let artist = song.artist {
                Text(artist)
                    .font(DSText.sectionTitle)
                    .foregroundStyle(DSColor.onDarkSecondary)
                    .lineLimit(1)
            }
            
            // Additional metadata
            HStack(spacing: DSLayout.elementGap) {
                if let album = song.album {
                    Text(album)
                        .font(DSText.metadata)
                        .foregroundStyle(DSColor.onDark.opacity(0.6))
                        .lineLimit(1)
                }
                
                if let year = song.year {
                    Text("•")
                        .foregroundStyle(DSColor.onDark.opacity(0.4))
                    Text(String(year))
                        .font(DSText.metadata)
                        .foregroundStyle(DSColor.onDark.opacity(0.6))
                }
            }
        }
    }
}

// Progress View (unchanged)
struct PlayerProgressView: View {
    @ObservedObject var playerVM: PlayerViewModel
    @State private var isDragging = false
    @State private var dragValue: Double = 0

    var body: some View {
        VStack(spacing: DSLayout.elementGap) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: DSCorners.tight)
                    .fill(DSColor.onDark.opacity(0.3))
                    .frame(height: 4)
                
                RoundedRectangle(cornerRadius: DSCorners.tight)
                    .fill(DSColor.onDark)
                    .frame(width: progressWidth, height: 4)
                
                Circle()
                    .fill(DSColor.onDark)
                    .frame(width: 12, height: 12)
                    .offset(x: progressWidth - 6)
            }
            .gesture(progressDragGesture)

            HStack {
                Text(formatTime(isDragging ? dragValue * playerVM.duration : playerVM.currentTime))
                    .foregroundStyle(isDragging ? DSColor.accent : DSColor.onDarkSecondary)
                
                Spacer()
                
                Text(formatTime(playerVM.duration))
                    .foregroundStyle(DSColor.onDarkSecondary)
            }
            .font(DSText.numbers)
            .animation(Animations.easeQuick, value: isDragging)
        }
    }

    private var progressWidth: CGFloat {
        let maxWidth = UIScreen.main.bounds.width - 48
        guard playerVM.duration > 0 else { return 0 }
        
        if isDragging {
            return maxWidth * CGFloat(dragValue)
        } else {
            return maxWidth * CGFloat(playerVM.currentTime / playerVM.duration)
        }
    }
    
    private var progressDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isDragging = true
                let maxWidth = UIScreen.main.bounds.width - 48
                let progress = max(0, min(1, value.location.x / maxWidth))
                dragValue = progress
            }
            .onEnded { value in
                let maxWidth = UIScreen.main.bounds.width - 48
                let progress = max(0, min(1, value.location.x / maxWidth))
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

// Playback Controls (unchanged)
struct PlaybackControls: View {
    @ObservedObject var playerVM: PlayerViewModel

    var body: some View {
        HStack(spacing: DSLayout.screenPadding) {
            Button {
                Task { await playerVM.playPrevious() }
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: DSLayout.icon))
                    .foregroundStyle(DSColor.onDark)
            }
            .disabled(playerVM.isLoading)

            Button {
                playerVM.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(DSColor.onDark)
                        .frame(width: 80, height: 80)
                    
                    if playerVM.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: DSColor.onLight))
                            .scaleEffect(1.2)
                    } else {
                        Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(DSColor.onLight)
                    }
                }
            }
            .disabled(playerVM.isLoading)

            Button {
                Task { await playerVM.playNext() }
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: DSLayout.icon))
                    .foregroundStyle(DSColor.onDark)
            }
            .disabled(playerVM.isLoading)
        }
    }
}

// Volume Slider (unchanged)
struct VolumeSlider: View {
    @ObservedObject var playerVM: PlayerViewModel

    var body: some View {
        HStack(spacing: DSLayout.elementGap) {
            Image(systemName: "speaker.fill")
                .foregroundStyle(DSColor.onDarkSecondary)

            Slider(
                value: Binding(
                    get: { Double(playerVM.volume) },
                    set: { newValue in
                        let floatValue = Float(newValue)
                        playerVM.setVolume(floatValue)
                    }
                ),
                in: 0...1
            )
            .tint(DSColor.onDark)

            Image(systemName: "speaker.wave.3.fill")
                .foregroundStyle(DSColor.onDarkSecondary)
        }
    }
}

// Background View (unchanged)
struct BackgroundView: View {
    let image: UIImage?

    var body: some View {
        ZStack {
            if let cover = image {
                Image(uiImage: cover)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                    .blur(radius: 40)
                    .scaleEffect(1.2)
            }
            Rectangle()
                .fill(DSColor.overlay)
                .ignoresSafeArea()
        }
    }
}

// Circle Button (unchanged)
struct CircleButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(DSText.sectionTitle)
                .foregroundStyle(DSColor.onDark)
                .frame(width: DSLayout.buttonHeight, height: DSLayout.buttonHeight)
                .background(DSColor.background)
                .clipShape(Circle())
        }
    }
}

// Style Extension (unchanged)
extension View {
    func coverStyle() -> some View {
        self.clipShape(RoundedRectangle(cornerRadius: DSCorners.comfortable))
    }
}

// Queue View and Audio Settings View would remain the same...
