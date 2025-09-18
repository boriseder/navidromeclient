//
//  SongRow.swift - Enhanced with Design System
//  NavidromeClient
//
//   ENHANCED: Vollständige Anwendung des Design Systems
//

import SwiftUI

struct SongRow: View {
    let song: Song
    let index: Int
    let isPlaying: Bool
    let action: () -> Void
    let onMore: () -> Void
    
    @State private var showPlayIndicator = false
    
    var body: some View {
        HStack(spacing: DSLayout.elementGap) {
            trackNumberView
            songInfoView
            Spacer()
            durationView
        }
        .listItemPadding()
        .background(backgroundView)
        .overlay(separatorLine, alignment: .bottom)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(DSAnimations.easeQuick) { action() }
        }
        .scaleEffect(isPlaying ? 1.02 : 1.0)
        .animation(DSAnimations.ease, value: isPlaying)
        .clipShape(RoundedRectangle(cornerRadius: DSCorners.element))
        .shadow(color: .black.opacity(isPlaying ? 0.08 : 0.03), radius: 3, x: 0, y: 2)
        .onAppear {
            if isPlaying {
                withAnimation(DSAnimations.ease.delay(0.1)) {
                    showPlayIndicator = true
                }
            }
        }
        .onChange(of: isPlaying) { _, newValue in
            withAnimation(DSAnimations.ease) { showPlayIndicator = newValue }
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
            .tint(DSColor.accent)
        }
    }

    // MARK: - Track Number or Equalizer (Enhanced)
    private var trackNumberView: some View {
        ZStack {
            if isPlaying && showPlayIndicator {
                EqualizerBars(isActive: showPlayIndicator)
                    .transition(.opacity.combined(with: .scale))
            } else {
                Text("\(index)")
                    .font(DSText.body.weight(.medium))
                    .foregroundStyle(DSColor.onLight)
                    .frame(width: 28, height: 28) // Approx. DS applied - könnte DSLayout.iconLarge + 4 sein
                    .background(
                        Circle()
                            .fill(DSColor.background.opacity(0.9))
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.5), lineWidth: 1)
                            )
                            .scaleEffect(isPlaying ? 1.1 : 1.0)
                    )
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(DSAnimations.ease, value: isPlaying)
    }

    // MARK: - Song Info (Enhanced)
    private var songInfoView: some View {
        VStack(alignment: .leading, spacing: DSLayout.tightGap) {
            Text(song.title)
                .font(isPlaying ? DSText.emphasized : DSText.body)
                .foregroundStyle(isPlaying ? DSColor.playing : DSColor.primary)
                .lineLimit(1)
                .transition(.opacity.combined(with: .slide))
                .animation(DSAnimations.ease, value: isPlaying)
        }
    }
    
    // MARK: - Duration (Enhanced)
    private var durationView: some View {
        Group {
            if let duration = song.duration, duration > 0 {
                Text(formatDuration(duration))
                    .font(DSText.numbers)
                    .foregroundStyle(DSColor.onLight)
                    .monospacedDigit()
            } else {
                EmptyView()
            }
        }
    }

    // MARK: - Background (Enhanced)
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: DSCorners.element)
            .fill(isPlaying ? DSColor.playing.opacity(0.15) : DSColor.background.opacity(0.3))
            .overlay(
                RoundedRectangle(cornerRadius: DSCorners.tight) // Approx. DS applied
                    .stroke(isPlaying ? DSColor.playing.opacity(0.1) : Color.white.opacity(0.1), lineWidth: 1)
            )
            .animation(DSAnimations.ease, value: isPlaying)
    }

    // MARK: - Separator (Enhanced)
    private var separatorLine: some View {
        Rectangle()
            .frame(height: 0.5)
            .foregroundColor(DSColor.quaternary)
    }

    // MARK: - Helper (unchanged but using DS)
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Equalizerbar-animation (Enhanced with DS)
struct EqualizerBars: View {
    @State private var barScales: [CGFloat] = [0.3, 0.3, 0.3]
    let isActive: Bool
    
    private let timer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(DSColor.onLight)
                    .frame(width: 3, height: 12)
                    .scaleEffect(y: barScales[index], anchor: .bottom)
                    .animation(.interpolatingSpring(stiffness: 80, damping: 10), value: barScales[index])
            }
        }
        .frame(width: 28, height: 28) // Konsistent mit trackNumberView
        .background(
            Circle()
                .fill(DSColor.background.opacity(0.9))
                .overlay(
                    Circle().stroke(Color.white.opacity(0.5), lineWidth: 1)
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
