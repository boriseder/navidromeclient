import SwiftUI

struct SongRow: View {
    let song: Song
    let index: Int
    let isPlaying: Bool
    let action: () -> Void
    let onMore: () -> Void
    
    @State private var showPlayIndicator = false
    
    var body: some View {
        HStack(spacing: 12) {
            trackNumberView
            songInfoView
            Spacer()
            durationView
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(backgroundView)
        .overlay(separatorLine, alignment: .bottom)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.1)) { action() }
        }
        .scaleEffect(isPlaying ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isPlaying)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(isPlaying ? 0.08 : 0.03), radius: 3, x: 0, y: 2)
        .onAppear {
            if isPlaying {
                withAnimation(.easeInOut(duration: 0.3).delay(0.1)) {
                    showPlayIndicator = true
                }
            }
        }
        .onChange(of: isPlaying) { _, newValue in
            withAnimation(.easeInOut(duration: 0.3)) { showPlayIndicator = newValue }
        }
        .contextMenu {
            Button("Add to playlist") {
                // Dummy action, noch nicht implementiert
            }
            Button("More Options") {
                onMore()
            }
        }
        .swipeActions(edge: .trailing) {
            Button {
                onMore()
            } label: {
                Label("More", systemImage: "ellipsis")
            }
            .tint(.blue)
        }
    }

    // MARK: - Track Number or Equalizer
    // MARK: - Track Number or Equalizer
    private var trackNumberView: some View {
        ZStack {
            if isPlaying && showPlayIndicator {
                EqualizerBars(isActive: showPlayIndicator)
                    .transition(.opacity.combined(with: .scale))
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
                            .scaleEffect(isPlaying ? 1.1 : 1.0)
                    )
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isPlaying)
    }

    // MARK: - Song Info
    private var songInfoView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(song.title)
                .font(.body.weight(isPlaying ? .semibold : .medium))
                .foregroundStyle(isPlaying ? Color.blue : .primary)
                .lineLimit(1)
                .transition(.opacity.combined(with: .slide))
                .animation(.easeInOut(duration: 0.25), value: isPlaying)
        }
    }
    
    // MARK: - Duration
    private var durationView: some View {
        Group {
            if let duration = song.duration, duration > 0 {
                Text(formatDuration(duration))
                    .font(.caption)
                    .foregroundStyle(.black)
                    .monospacedDigit()
            } else {
                EmptyView()
            }
        }
    }

    // MARK: - Background
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isPlaying ? Color.blue.opacity(0.15) : Color.white.opacity(0.3))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isPlaying ? Color.blue.opacity(0.1) : Color.white.opacity(0.1), lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.3), value: isPlaying)
    }

    // MARK: - Separator
    private var separatorLine: some View {
        Rectangle()
            .frame(height: 0.5)
            .foregroundColor(.gray.opacity(0.2))
    }

    // MARK: - Helper
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Equalizerbar-animation when song is playing
struct EqualizerBars: View {
    @State private var barScales: [CGFloat] = [0.3, 0.3, 0.3]
    let isActive: Bool
    
    private let timer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(.black)
                    .frame(width: 3, height: 12)
                    .scaleEffect(y: barScales[index], anchor: .bottom)
                    .animation(.interpolatingSpring(stiffness: 80, damping: 10), value: barScales[index])
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
        .onReceive(timer) { _ in
            if isActive {
                barScales = (0..<barScales.count).map { _ in CGFloat.random(in: 0.2...1.0) }
            } else {
                barScales = Array(repeating: 0.3, count: barScales.count)
            }
        }
    }
}
