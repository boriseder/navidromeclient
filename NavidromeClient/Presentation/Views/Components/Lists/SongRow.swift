//
//  SongRow.swift - ENHANCED: Modern UX Patterns & Accessibility
//  NavidromeClient
//
//   ENHANCED: Better interaction patterns, visual hierarchy, accessibility
//   SUSTAINABLE: Uses existing HeartButton, design system, no new dependencies
//

import SwiftUI

struct SongRow: View {
    let song: Song
    let index: Int
    let isPlaying: Bool
    let action: () -> Void
    let onMore: () -> Void
    let favoriteAction: (() -> Void)?
    
    // ENHANCED: Interaction states for better UX
    @State private var isPressed = false
    @State private var playIndicatorPhase = 0.0
    
    // ENHANCED: Animation states
    @State private var showPlayIndicator = false
    private let animationTimer = Timer.publish(every: 0.8, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: DSLayout.elementGap) {
            // ENHANCED: Track number with better visual feedback
            trackNumberSection
            
            // ENHANCED: Song info with better typography
            songInfoSection
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // ENHANCED: Duration with better layout
            durationSection
            
            // ENHANCED: Actions with improved spacing
            actionsSection
        }
        .padding(.horizontal, DSLayout.contentPadding)
        .padding(.vertical, DSLayout.elementPadding)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSCorners.element))
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .shadow(
            color: DSColor.overlay.opacity(isPlaying ? 0.15 : 0.08),
            radius: isPlaying ? 8 : 4,
            x: 0,
            y: 2
        )
        .animation(DSAnimations.spring, value: isPressed)
        .animation(DSAnimations.ease, value: isPlaying)
        .onReceive(animationTimer) { _ in
            updatePlayIndicatorAnimation()
        }
        .onAppear {
            if isPlaying { showPlayIndicator = true }
        }
        .onChange(of: isPlaying) { _, newValue in
            withAnimation(DSAnimations.springSnappy) {
                showPlayIndicator = newValue
            }
        }
        // ENHANCED: Better gesture handling
        .contentShape(Rectangle())
        .onTapGesture {
            triggerHapticFeedback()
            withAnimation(DSAnimations.easeQuick) {
                action()
            }
        }
        .pressEvents {
            withAnimation(DSAnimations.easeQuick) { isPressed = true }
        } onRelease: {
            withAnimation(DSAnimations.easeQuick) { isPressed = false }
        }
        // ENHANCED: Improved context menu
        .contextMenu {
            enhancedContextMenu
        }
        // ENHANCED: Accessibility
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAction {
            action()
        }
    }
    
    // MARK: - ENHANCED: Track Number Section
    
    @ViewBuilder
    private var trackNumberSection: some View {
        ZStack {
            if isPlaying && showPlayIndicator {
                // ENHANCED: More sophisticated playing indicator
                EnhancedEqualizerBars(
                    isActive: showPlayIndicator,
                    accentColor: DSColor.playing
                )
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            } else {
                // ENHANCED: Better track number design
                Text("\(index)")
                    .font(DSText.body.weight(.medium).monospacedDigit())
                    .foregroundStyle(trackNumberColor)
                    .frame(width: 28, height: 28)
                    .background(trackNumberBackground)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
            }
        }
        .animation(DSAnimations.springSnappy, value: showPlayIndicator)
    }
    
    // ENHANCED: Dynamic track number styling
    private var trackNumberColor: Color {
        if isPlaying {
            return DSColor.playing
        }
        return DSColor.secondary
    }
    
    private var trackNumberBackground: some View {
        Circle()
            .fill(isPlaying ? DSColor.playing.opacity(0.15) : DSColor.surface)
            .overlay(
                Circle()
                    .stroke(
                        isPlaying ? DSColor.playing.opacity(0.3) : DSColor.quaternary.opacity(0.5),
                        lineWidth: 1
                    )
            )
    }
    
    // MARK: - ENHANCED: Song Info Section
    
    private var songInfoSection: some View {
        VStack(alignment: .leading, spacing: DSLayout.tightGap) {
            // ENHANCED: Song title with better styling
            Text(song.title)
                .font(songTitleFont)
                .foregroundStyle(songTitleColor)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            // ENHANCED: Artist with better hierarchy
            if let artist = song.artist, !artist.isEmpty {
                Text(artist)
                    .font(DSText.body)
                    .foregroundStyle(DSColor.secondary)
                    .lineLimit(1)
            }
        }
    }
    
    // ENHANCED: Dynamic song title styling
    private var songTitleFont: Font {
        if isPlaying {
            return DSText.emphasized.weight(.semibold)
        }
        return DSText.emphasized
    }
    
    private var songTitleColor: Color {
        if isPlaying {
            return DSColor.playing
        }
        return DSColor.primary
    }
    
    // MARK: - ENHANCED: Duration Section
    
    @ViewBuilder
    private var durationSection: some View {
        if let duration = song.duration, duration > 0 {
            Text(formatDuration(duration))
                .font(DSText.numbers.weight(.medium))
                .foregroundStyle(durationColor)
                .monospacedDigit()
        }
    }
    
    private var durationColor: Color {
        if isPlaying {
            return DSColor.playing.opacity(0.8)
        }
        return DSColor.tertiary
    }
    
    // MARK: - ENHANCED: Actions Section
    
    private var actionsSection: some View {
        HStack(spacing: DSLayout.tightGap) {
            // ENHANCED: Heart button with proper context
            if let favoriteAction = favoriteAction {
                HeartButton.songRow(song: song)
                    .onTapGesture {
                        triggerHapticFeedback(.light)
                        favoriteAction()
                    }
            }
            
        }
    }
    
    // MARK: - ENHANCED: Row Background
    
    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: DSCorners.element)
            .fill(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: DSCorners.element)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
    }
    
    // ENHANCED: Dynamic background styling
    private var backgroundColor: Color {
        if isPressed {
            return DSColor.accent.opacity(0.1)
        } else if isPlaying {
            return DSColor.playing.opacity(0.08)
        } else {
            return DSColor.background
        }
    }
    
    private var borderColor: Color {
        if isPlaying {
            return DSColor.playing.opacity(0.2)
        } else {
            return DSColor.quaternary.opacity(0.3)
        }
    }
    
    private var borderWidth: CGFloat {
        isPlaying ? 1 : 0.5
    }
    
    // MARK: - ENHANCED: Context Menu
    
    @ViewBuilder
    private var enhancedContextMenu: some View {
        VStack {
            Button {
                action()
            } label: {
                Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill")
            }
            
            if let favoriteAction = favoriteAction {
                Button(action: favoriteAction) {
                    Label("Toggle Favorite", systemImage: "heart.fill")
                }
            }
            
            Button {
                // Add to playlist functionality could go here
            } label: {
                Label("Add to Playlist", systemImage: "plus")
            }
            
            Divider()
            
            Button {
                onMore()
            } label: {
                Label("More Options", systemImage: "ellipsis")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func updatePlayIndicatorAnimation() {
        if isPlaying {
            withAnimation(
                .easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true)
            ) {
                playIndicatorPhase += 1.0
            }
        }
    }
    
    private func triggerHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    // ENHANCED: Accessibility
    private var accessibilityLabel: String {
        var label = "Track \(index): \(song.title)"
        if let artist = song.artist {
            label += " by \(artist)"
        }
        if let duration = song.duration {
            label += ", \(formatDuration(duration))"
        }
        if isPlaying {
            label += ", currently playing"
        }
        return label
    }
    
    private var accessibilityHint: String {
        return "Double tap to \(isPlaying ? "pause" : "play")"
    }
}

// MARK: - ENHANCED: Supporting Components

struct EnhancedEqualizerBars: View {
    let isActive: Bool
    let accentColor: Color
    
    @State private var barScales: [CGFloat] = [0.3, 0.5, 0.8]
    
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(accentColor)
                    .frame(width: 3, height: maxHeight)
                    .scaleEffect(y: barScales[index], anchor: .bottom)
                    .animation(
                        .interpolatingSpring(stiffness: 100, damping: 12)
                        .delay(Double(index) * 0.1),
                        value: barScales[index]
                    )
            }
        }
        .frame(width: 28, height: 28)
        .background(
            Circle()
                .fill(accentColor.opacity(0.15))
                .overlay(
                    Circle()
                        .stroke(accentColor.opacity(0.3), lineWidth: 1)
                )
        )
        .onReceive(timer) { _ in
            updateBars()
        }
        .onAppear {
            if isActive { updateBars() }
        }
    }
    
    private var maxHeight: CGFloat { 14 }
    
    private func updateBars() {
        guard isActive else {
            barScales = [0.3, 0.3, 0.3]
            return
        }
        
        barScales = (0..<3).map { _ in
            CGFloat.random(in: 0.2...1.0)
        }
    }
}

// MARK: - ENHANCED: Press Events ViewModifier

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    onPress()
                }
                .onEnded { _ in
                    onRelease()
                }
        )
    }
}

// MARK: - Convenience Initializers (unchanged)

extension SongRow {
    init(song: Song, index: Int, isPlaying: Bool, action: @escaping () -> Void, onMore: @escaping () -> Void) {
        self.init(song: song, index: index, isPlaying: isPlaying, action: action, onMore: onMore, favoriteAction: nil)
    }
}
