import SwiftUI

struct SongRow: View {
    let song: Song
    let index: Int
    let isPlaying: Bool
    let action: () -> Void
    let onLongPressOrSwipe: () -> Void
    
    @State private var showPlayIndicator = false
    
    var body: some View {
        HStack(spacing: 10) {
            trackNumberView
            songInfoView
            Spacer()
            durationView
        }
        .frame(maxWidth: UIScreen.main.bounds.width, alignment: .leading)
        .padding(.horizontal, 0) // Padding außerhalb vermeiden
        .padding(.vertical, 6)
        .background(backgroundView)
        .contentShape(Rectangle()) // gesamte Fläche tappable
        .onTapGesture { action() }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in onLongPressOrSwipe() }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.height > 50 {
                        onLongPressOrSwipe()
                    }
                }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
        .onAppear {
            if isPlaying {
                withAnimation(.easeInOut(duration: 0.3).delay(0.1)) {
                    showPlayIndicator = true
                }
            }
        }
        .onChange(of: isPlaying) { _, newValue in
            withAnimation(.easeInOut(duration: 0.3)) {
                showPlayIndicator = newValue
            }
        }
    }

    // MARK: - Track Number View
    private var trackNumberView: some View {
        ZStack {
            if isPlaying && showPlayIndicator {
                EqualizerBars(isActive: showPlayIndicator)
            } else {
                Text("\(index)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.black)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.9))
                            .overlay(
                                Circle().stroke(.white.opacity(0.5), lineWidth: 1)
                            )
                    )
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Song Info
    private var songInfoView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(song.title)
                .font(.body.weight(isPlaying ? .semibold : .medium))
                .foregroundStyle(isPlaying ? .black : .primary)
                .lineLimit(1)
                .animation(.easeInOut(duration: 0.2), value: isPlaying)
        }
    }

    // MARK: - Duration
    private var durationView: some View {
        HStack {
            if let duration = song.duration, duration > 0 {
                Text(formatDuration(duration))
                    .font(.caption)
                    .foregroundStyle(.black)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, -50)

    }

    // MARK: - Background
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isPlaying ? Color.blue.opacity(0.06) : Color.white.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isPlaying ? Color.blue.opacity(0.1) : Color.white.opacity(0.05), lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.3), value: isPlaying)
    }

    // MARK: - Helper
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
// MARK: - Custom Button Styles
struct ModernSongButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    let scale: CGFloat
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Animation Extensions
extension View {
    func pulsingScale(isActive: Bool) -> some View {
        self.scaleEffect(isActive ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isActive)
    }
}

// MARK: Equalizerbar-animation when song is playing
struct EqualizerBars: View {
    @State private var barScales: [CGFloat] = [0.3, 0.3, 0.3]
    let isActive: Bool
    
    // Timer, der alle 0.3s feuert
    private let timer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(.black)
                    .frame(width: 3, height: 12)
                    .scaleEffect(y: barScales[index], anchor: .bottom)
                    .animation(.easeInOut(duration: 0.3), value: barScales[index])
            }
        }
        .frame(width: 28, height: 28)
        .background(
            Circle()
                .fill(.white.opacity(0.9))
                .overlay(
                    Circle().stroke(.white.opacity(0.5), lineWidth: 1)
                )
        )
        // Bei jedem Tick neuen Zufallswert erzeugen
        .onReceive(timer) { _ in
            if isActive {
                barScales = (0..<barScales.count).map { _ in
                    CGFloat.random(in: 0.2...1.0)
                }
            } else {
                // Wenn nicht aktiv, Balken klein halten
                barScales = Array(repeating: 0.3, count: barScales.count)
            }
        }
    }
}
