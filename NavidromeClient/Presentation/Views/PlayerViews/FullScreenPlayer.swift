import SwiftUI

// MARK: - Full Screen Player
struct FullScreenPlayerView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var audioSessionManager: AudioSessionManager
    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var showingQueue = false
    @State private var showingSettings = false

    private let maxContentWidth: CGFloat = 300

    var body: some View {
        ZStack {
            BackgroundView(image: playerVM.coverArt)

            VStack(spacing: 20) {
                PlayerTopBar(
                    dismiss: dismiss,
                    showingQueue: $showingQueue,
                    showingSettings: $showingSettings,
                    audioSessionManager: audioSessionManager
                )

                Spacer()

                CoverArtView(cover: playerVM.coverArt)
                    .frame(width: maxContentWidth, height: maxContentWidth)
                    .scaleEffect(isDragging ? 0.95 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isDragging)

                if let song = playerVM.currentSong {
                    PlayerSongInfoView(
                        song: song,
                        isPlaying: playerVM.isPlaying,
                        isLoading: playerVM.isLoading
                    )
                    .frame(maxWidth: maxContentWidth)
                    .multilineTextAlignment(.center)
                }

                PlayerProgressView(playerVM: playerVM)
                    .frame(width: maxContentWidth)

                PlaybackControls(playerVM: playerVM)
                    .frame(width: maxContentWidth)

                VolumeSlider(playerVM: playerVM)
                    .frame(width: maxContentWidth)

                Spacer()

                BottomControls(playerVM: playerVM)
                    .frame(width: maxContentWidth)
                    .padding(.bottom, 40)
            }
            .padding(.top, 20)
            .padding(.horizontal, 24)
        }
        .statusBarHidden()
        .offset(y: dragOffset)
        .gesture(dismissDragGesture)
        .highPriorityGesture(longPressDismissGesture)
        .animation(.interactiveSpring(), value: dragOffset)
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
                    withAnimation(.spring()) {
                        dismiss()
                    }
                } else {
                    withAnimation(.spring()) {
                        dragOffset = 0
                    }
                }
            }
    }

    // MARK: - Long Press Gesture
    private var longPressDismissGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .onEnded { _ in
                withAnimation(.spring()) {
                    playerVM.stop()
                    dismiss()
                }
            }
    }
}

// MARK: - Enhanced Top Bar
struct PlayerTopBar: View {
    var dismiss: DismissAction
    @Binding var showingQueue: Bool
    @Binding var showingSettings: Bool
    let audioSessionManager: AudioSessionManager

    var body: some View {
        HStack {
            CircleButton(icon: "chevron.down") { dismiss() }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("Playing from")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                
                HStack(spacing: 4) {
                    // Audio Route Indicator
                    if audioSessionManager.isHeadphonesConnected {
                        Image(systemName: audioRouteIcon)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    
                    Text(audioRouteText)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
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

// MARK: - Enhanced Cover Art
struct CoverArtView: View {
    let cover: UIImage?

    var body: some View {
        Group {
            if let cover = cover {
                Image(uiImage: cover)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 80))
                            .foregroundStyle(.white.opacity(0.6))
                    )
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .coverStyle()
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Enhanced Song Info
struct PlayerSongInfoView: View {
    let song: Song
    let isPlaying: Bool
    let isLoading: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(song.title)
                    .font(.title2.weight(isPlaying ? .semibold : .medium))
                    .foregroundStyle(isPlaying ? .blue : .white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
            }

            if let artist = song.artist {
                Text(artist)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
            
            // Additional metadata
            HStack(spacing: 8) {
                if let album = song.album {
                    Text(album)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
                
                if let year = song.year {
                    Text("•")
                        .foregroundStyle(.white.opacity(0.4))
                    Text(String(year))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }
}

// MARK: - Enhanced Progress View
struct PlayerProgressView: View {
    @ObservedObject var playerVM: PlayerViewModel
    @State private var isDragging = false
    @State private var dragValue: Double = 0

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white.opacity(0.3))
                    .frame(height: 4)
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white)
                    .frame(width: progressWidth, height: 4)
                
                Circle()
                    .fill(.white)
                    .frame(width: 12, height: 12)
                    .offset(x: progressWidth - 6)
                    .shadow(color: .black.opacity(0.3), radius: 2)
            }
            .gesture(progressDragGesture)

            HStack {
                Text(formatTime(isDragging ? dragValue * playerVM.duration : playerVM.currentTime))
                    .foregroundStyle(isDragging ? .blue : .white.opacity(0.7))
                
                Spacer()
                
                Text(formatTime(playerVM.duration))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .font(.caption2.monospacedDigit())
            .animation(.easeInOut(duration: 0.1), value: isDragging)
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

// MARK: - Enhanced Playback Controls
struct PlaybackControls: View {
    @ObservedObject var playerVM: PlayerViewModel

    var body: some View {
        HStack(spacing: 40) {
            Button {
                Task { await playerVM.playPrevious() }
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
            }
            .disabled(playerVM.isLoading)

            Button {
                playerVM.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 80, height: 80)
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    
                    if playerVM.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            .scaleEffect(1.2)
                    } else {
                        Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.black)
                    }
                }
            }
            .disabled(playerVM.isLoading)

            Button {
                Task { await playerVM.playNext() }
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
            }
            .disabled(playerVM.isLoading)
        }
    }
}

// MARK: - Enhanced Volume Slider
struct VolumeSlider: View {
    @ObservedObject var playerVM: PlayerViewModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
                .foregroundStyle(.white.opacity(0.7))

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
            .tint(.white)

            Image(systemName: "speaker.wave.3.fill")
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

// MARK: - Enhanced Bottom Controls
struct BottomControls: View {
    @ObservedObject var playerVM: PlayerViewModel

    var body: some View {
        HStack(spacing: 60) {
            Button { playerVM.toggleShuffle() } label: {
                Image(systemName: "shuffle")
                    .font(.title3)
                    .foregroundStyle(playerVM.isShuffling ? .blue : .white.opacity(0.7))
            }

            Spacer()

            Button { playerVM.toggleRepeat() } label: {
                Image(systemName: repeatIcon)
                    .font(.title3)
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
        case .all, .one: return .blue
        }
    }
}

// MARK: - Background View
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
                .fill(.black.opacity(0.4))
                .ignoresSafeArea()
        }
    }
}

// MARK: - Circle Button
struct CircleButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
    }
}

// MARK: - Queue View (Optional)
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
                                .font(.headline)
                                .foregroundStyle(index == playerVM.currentIndex ? .blue : .primary)
                            
                            if let artist = song.artist {
                                Text(artist)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if index == playerVM.currentIndex {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundStyle(.blue)
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

// MARK: - Audio Settings View (Optional)
struct AudioSettingsView: View {
    @EnvironmentObject var audioSessionManager: AudioSessionManager
    @EnvironmentObject var playerVM: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Audio Output") {
                    HStack {
                        Text("Current Route")
                        Spacer()
                        Text(audioSessionManager.audioRoute)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Headphones Connected")
                        Spacer()
                        Image(systemName: audioSessionManager.isHeadphonesConnected ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundStyle(audioSessionManager.isHeadphonesConnected ? .green : .secondary)
                    }
                }
                
                Section("Playback") {
                    HStack {
                        Text("Volume")
                        Spacer()
                        Text("\(Int(playerVM.volume * 100))%")
                            .foregroundStyle(.secondary)
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

// MARK: - Style Extension
extension View {
    func coverStyle() -> some View {
        self.clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}
