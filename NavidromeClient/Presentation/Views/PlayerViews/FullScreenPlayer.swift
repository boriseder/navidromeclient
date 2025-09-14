//
//  FullScreenPlayerView.swift - Enhanced with Design System
//  NavidromeClient
//
//  ✅ ENHANCED: Vollständige Anwendung des Design Systems
//

import SwiftUI

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

            VStack(spacing: Spacing.l) {
                PlayerTopBar(
                    dismiss: dismiss,
                    showingQueue: $showingQueue,
                    showingSettings: $showingSettings,
                    audioSessionManager: audioSessionManager
                )

                Spacer()

                CoverArtView(cover: playerVM.coverArt)
                    .frame(width: Sizes.cover, height: Sizes.cover)
                    .scaleEffect(isDragging ? 0.95 : 1.0)
                    .animation(Animations.spring, value: isDragging)

                if let song = playerVM.currentSong {
                    PlayerSongInfoView(
                        song: song,
                        isPlaying: playerVM.isPlaying,
                        isLoading: playerVM.isLoading
                    )
                    .maxContentWidth()
                    .multilineTextAlignment(.center)
                }

                PlayerProgressView(playerVM: playerVM)
                    .maxContentWidth()

                PlaybackControls(playerVM: playerVM)
                    .maxContentWidth()

                VolumeSlider(playerVM: playerVM)
                    .maxContentWidth()

                Spacer()

                BottomControls(playerVM: playerVM)
                    .maxContentWidth()
                    .padding(.bottom, Padding.xl)
            }
            .padding(.top, Spacing.l)
            .screenPadding()
        }
        .statusBarHidden()
        .offset(y: dragOffset)
        .gesture(dismissDragGesture)
        .highPriorityGesture(longPressDismissGesture)
        .animation(Animations.interactive, value: dragOffset)
        .sheet(isPresented: $showingQueue) {
            QueueView()
                .environmentObject(playerVM)
        }
        .sheet(isPresented: $showingSettings) {
            AudioSettingsView()
                .environmentObject(audioSessionManager)
                .environmentObject(playerVM)
        }
    }

    // MARK: - Drag Down Gesture
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

    // MARK: - Long Press Gesture
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

// MARK: - Enhanced Top Bar (Enhanced with DS)
struct PlayerTopBar: View {
    var dismiss: DismissAction
    @Binding var showingQueue: Bool
    @Binding var showingSettings: Bool
    let audioSessionManager: AudioSessionManager

    var body: some View {
        HStack {
            CircleButton(icon: "chevron.down") { dismiss() }
            
            Spacer()
            
            VStack(spacing: Spacing.xs) {
                Text("Playing from")
                    .font(Typography.caption)
                    .foregroundStyle(TextColor.onDarkSecondary)
                
                HStack(spacing: Spacing.xs) {
                    // Audio Route Indicator
                    if audioSessionManager.isHeadphonesConnected {
                        Image(systemName: audioRouteIcon)
                            .font(Typography.caption2)
                            .foregroundStyle(TextColor.onDark.opacity(0.8))
                    }
                    
                    Text(audioRouteText)
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(TextColor.onDark)
                }
            }
            
            Spacer()
            
            HStack(spacing: Spacing.s) {
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

// MARK: - Enhanced Cover Art (Enhanced with DS)
struct CoverArtView: View {
    let cover: UIImage?

    var body: some View {
        Group {
            if let cover = cover {
                Image(uiImage: cover)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                RoundedRectangle(cornerRadius: Radius.l)
                    .fill(BackgroundColor.thin)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 80)) // Approx. DS applied
                            .foregroundStyle(TextColor.onDark.opacity(0.6))
                    )
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .coverStyle()
        .overlay(
            RoundedRectangle(cornerRadius: Radius.l)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Enhanced Song Info (Enhanced with DS)
struct PlayerSongInfoView: View {
    let song: Song
    let isPlaying: Bool
    let isLoading: Bool

    var body: some View {
        VStack(spacing: Spacing.s) {
            HStack {
                Text(song.title)
                    .font(isPlaying ? Typography.title2 : Typography.title3)
                    .foregroundStyle(isPlaying ? BrandColor.playing : TextColor.onDark)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: TextColor.onDark))
                        .scaleEffect(0.8)
                        .frame(width: Sizes.iconLarge, height: Sizes.iconLarge)
                }
            }

            if let artist = song.artist {
                Text(artist)
                    .font(Typography.title3)
                    .foregroundStyle(TextColor.onDarkSecondary)
                    .lineLimit(1)
            }
            
            // Additional metadata
            HStack(spacing: Spacing.s) {
                if let album = song.album {
                    Text(album)
                        .font(Typography.caption)
                        .foregroundStyle(TextColor.onDark.opacity(0.6))
                        .lineLimit(1)
                }
                
                if let year = song.year {
                    Text("•")
                        .foregroundStyle(TextColor.onDark.opacity(0.4))
                    Text(String(year))
                        .font(Typography.caption)
                        .foregroundStyle(TextColor.onDark.opacity(0.6))
                }
            }
        }
    }
}

// MARK: - Enhanced Progress View (Enhanced with DS)
struct PlayerProgressView: View {
    @ObservedObject var playerVM: PlayerViewModel
    @State private var isDragging = false
    @State private var dragValue: Double = 0

    var body: some View {
        VStack(spacing: Spacing.s) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: Radius.xs)
                    .fill(TextColor.onDark.opacity(0.3))
                    .frame(height: 4)
                
                RoundedRectangle(cornerRadius: Radius.xs)
                    .fill(TextColor.onDark)
                    .frame(width: progressWidth, height: 4)
                
                Circle()
                    .fill(TextColor.onDark)
                    .frame(width: 12, height: 12) // Approx. DS applied
                    .offset(x: progressWidth - 6)
                    .miniShadow()
            }
            .gesture(progressDragGesture)

            HStack {
                Text(formatTime(isDragging ? dragValue * playerVM.duration : playerVM.currentTime))
                    .foregroundStyle(isDragging ? BrandColor.primary : TextColor.onDarkSecondary)
                
                Spacer()
                
                Text(formatTime(playerVM.duration))
                    .foregroundStyle(TextColor.onDarkSecondary)
            }
            .font(Typography.monospacedNumbers)
            .animation(Animations.easeQuick, value: isDragging)
        }
    }

    private var progressWidth: CGFloat {
        let maxWidth = UIScreen.main.bounds.width - 48 // Approx. DS applied
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
                let maxWidth = UIScreen.main.bounds.width - 48 // Approx. DS applied
                let progress = max(0, min(1, value.location.x / maxWidth))
                dragValue = progress
            }
            .onEnded { value in
                let maxWidth = UIScreen.main.bounds.width - 48 // Approx. DS applied
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

// MARK: - Enhanced Playback Controls (Enhanced with DS)
struct PlaybackControls: View {
    @ObservedObject var playerVM: PlayerViewModel

    var body: some View {
        HStack(spacing: Padding.xl) {
            Button {
                Task { await playerVM.playPrevious() }
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: Sizes.icon))
                    .foregroundStyle(TextColor.onDark)
            }
            .disabled(playerVM.isLoading)

            Button {
                playerVM.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(TextColor.onDark)
                        .frame(width: 80, height: 80) // Approx. DS applied
                        .largeShadow()
                    
                    if playerVM.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: TextColor.onLight))
                            .scaleEffect(1.2)
                    } else {
                        Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 28)) // Approx. DS applied
                            .foregroundStyle(TextColor.onLight)
                    }
                }
            }
            .disabled(playerVM.isLoading)

            Button {
                Task { await playerVM.playNext() }
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: Sizes.icon))
                    .foregroundStyle(TextColor.onDark)
            }
            .disabled(playerVM.isLoading)
        }
    }
}

// MARK: - Enhanced Volume Slider (Enhanced with DS)
struct VolumeSlider: View {
    @ObservedObject var playerVM: PlayerViewModel

    var body: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: "speaker.fill")
                .foregroundStyle(TextColor.onDarkSecondary)

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
            .tint(TextColor.onDark)

            Image(systemName: "speaker.wave.3.fill")
                .foregroundStyle(TextColor.onDarkSecondary)
        }
    }
}

// MARK: - Enhanced Bottom Controls (Enhanced with DS)
struct BottomControls: View {
    @ObservedObject var playerVM: PlayerViewModel

    var body: some View {
        HStack(spacing: 60) { // Approx. DS applied
            Button { playerVM.toggleShuffle() } label: {
                Image(systemName: "shuffle")
                    .font(Typography.title3)
                    .foregroundStyle(playerVM.isShuffling ? BrandColor.primary : TextColor.onDarkSecondary)
            }

            Spacer()

            Button { playerVM.toggleRepeat() } label: {
                Image(systemName: repeatIcon)
                    .font(Typography.title3)
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
        case .off: return TextColor.onDarkSecondary
        case .all, .one: return BrandColor.primary
        }
    }
}

// MARK: - Background View (Enhanced with DS)
struct BackgroundView: View {
    let image: UIImage?

    var body: some View {
        ZStack {
            if let cover = image {
                Image(uiImage: cover)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                    .blur(radius: 40) // Approx. DS applied
                    .scaleEffect(1.2)
            }
            Rectangle()
                .fill(BackgroundColor.overlay)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Circle Button (Enhanced with DS)
struct CircleButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(Typography.title2)
                .foregroundStyle(TextColor.onDark)
                .frame(width: Sizes.buttonHeight, height: Sizes.buttonHeight)
                .background(BackgroundColor.thin)
                .clipShape(Circle())
        }
    }
}

// MARK: - Queue View (Enhanced with DS)
struct QueueView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(Array(playerVM.currentPlaylist.enumerated()), id: \.element.id) { index, song in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(song.title)
                                .font(Typography.headline)
                                .foregroundStyle(index == playerVM.currentIndex ? BrandColor.playing : TextColor.primary)
                            
                            if let artist = song.artist {
                                Text(artist)
                                    .font(Typography.caption)
                                    .foregroundStyle(TextColor.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if index == playerVM.currentIndex {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundStyle(BrandColor.playing)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Task {
                            await playerVM.setPlaylist(
                                playerVM.currentPlaylist,
                                startIndex: index,
                                albumId: playerVM.currentAlbumId
                            )
                        }
                        dismiss()
                    }
                }
            }
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Audio Settings View (Enhanced with DS)
struct AudioSettingsView: View {
    @EnvironmentObject var audioSessionManager: AudioSessionManager
    @EnvironmentObject var playerVM: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Audio Output") {
                    SettingsRow(
                        title: "Current Route",
                        value: audioSessionManager.audioRoute
                    )
                    
                    HStack {
                        Text("Headphones Connected")
                            .font(Typography.body)
                        Spacer()
                        Image(systemName: audioSessionManager.isHeadphonesConnected ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundStyle(audioSessionManager.isHeadphonesConnected ? BrandColor.success : TextColor.secondary)
                    }
                }
                
                Section("Playback") {
                    HStack {
                        Text("Volume")
                            .font(Typography.body)
                        Spacer()
                        Text("\(Int(playerVM.volume * 100))%")
                            .font(Typography.body)
                            .foregroundStyle(TextColor.secondary)
                    }
                    
                    Slider(
                        value: Binding(
                            get: { Double(playerVM.volume) },
                            set: { playerVM.setVolume(Float($0)) }
                        ),
                        in: 0...1
                    )
                }
            }
            .navigationTitle("Audio Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Style Extension (Enhanced with DS)
extension View {
    func coverStyle() -> some View {
        self.clipShape(RoundedRectangle(cornerRadius: Radius.l))
            .largeShadow()
    }
}
