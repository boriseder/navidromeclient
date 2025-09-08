import SwiftUI

// MARK: - Full Screen Player
struct FullScreenPlayerView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    private let maxContentWidth: CGFloat = 300

    var body: some View {
        ZStack {
            BackgroundView(image: playerVM.coverArt)

            VStack(spacing: 20) {
                PlayerTopBar(dismiss: dismiss)

                Spacer()

                CoverArtView(cover: playerVM.coverArt)
                    .frame(width: maxContentWidth, height: maxContentWidth)
                    .scaleEffect(isDragging ? 0.95 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isDragging)

                if let song = playerVM.currentSong {
                    PlayerSongInfoView(song: song, isPlaying: playerVM.isPlaying)
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
    }

    // MARK: - Drag Down Gesture
    private var dismissDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if value.translation.height > 0 {
                    dragOffset = value.translation.height
                }
            }
            .onEnded { value in
                if value.translation.height > 200 {
                    withAnimation(.spring()) {
                        //playerVM.stop()
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

// MARK: - Reusable Modifiers
extension View {
    func coverStyle() -> some View {
        self.clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Background
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

// MARK: - Cover Art
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
    }
}
// MARK: - Volume Slider
struct VolumeSlider: View {
    @ObservedObject var playerVM: PlayerViewModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
                .foregroundStyle(.white.opacity(0.7))

            Slider(
                value: Binding(
                    get: { Double(playerVM.volume ?? 0) },
                    set: { newValue in
                        let floatValue = Float(newValue)
                        playerVM.volume = floatValue
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

// MARK: - Background
/*
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
*/

// MARK: - Top Bar
struct PlayerTopBar: View {
    var dismiss: DismissAction

    var body: some View {
        HStack {
            CircleButton(icon: "chevron.down") { dismiss() }
            Spacer()
            VStack(spacing: 2) {
                Text("Playing from")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                Text("Album")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
            Spacer()
            CircleButton(icon: "heart") { }
        }
    }
}

// MARK: - Cover Art
/*struct CoverArtView: View {
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
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}
 */

// MARK: - Song Info
struct PlayerSongInfoView: View {
    let song: Song
    let isPlaying: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(song.title)
                .font(.title2.weight(isPlaying ? .semibold : .medium))
                .foregroundStyle(isPlaying ? .blue : .white)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            if let artist = song.artist {
                Text(artist)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Progress
struct PlayerProgressView: View {
    @ObservedObject var playerVM: PlayerViewModel
    @State private var isDragging = false

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
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let p = max(0, min(1, value.location.x / UIScreen.main.bounds.width))
                        playerVM.seek(to: p * playerVM.duration)
                    }
                    .onEnded { _ in isDragging = false }
            )

            HStack {
                Text(formatTime(playerVM.currentTime))
                Spacer()
                Text(formatTime(playerVM.duration))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var progressWidth: CGFloat {
        guard playerVM.duration > 0 else { return 0 }
        return UIScreen.main.bounds.width * CGFloat(playerVM.currentTime / playerVM.duration)
    }

    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Playback Controls
struct PlaybackControls: View {
    @ObservedObject var playerVM: PlayerViewModel

    var body: some View {
        HStack(spacing: 40) {
            Button { Task { await playerVM.playPrevious() } } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
            }

            Button { playerVM.togglePlayPause() } label: {
                Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.black)
                    .frame(width: 80, height: 80)
                    .background(Circle().fill(.white).shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4))
            }

            Button { Task { await playerVM.playNext() } } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Bottom Controls
// MARK: - Bottom Controls
struct BottomControls: View {
    @ObservedObject var playerVM: PlayerViewModel

    var body: some View {
        HStack(spacing: 60) {
            Button { playerVM.toggleShuffle() } label: {
                Image(systemName: "shuffle")
                    .foregroundStyle(playerVM.isShuffling ? .blue : .white.opacity(0.7))
            }

            Spacer()

            Button { playerVM.toggleRepeat() } label: {
                Image(systemName: repeatIcon)
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
