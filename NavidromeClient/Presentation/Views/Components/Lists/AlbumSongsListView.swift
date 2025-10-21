//
//  AlbumSongsListView.swift
//  NavidromeClient
//
//  Created by Boris Eder on 11.09.25.
//

import SwiftUI

// MARK: - Album Songs List
struct AlbumSongsListView: View {
    let songs: [Song]
    let album: Album
    
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    
    var body: some View {
        ForEach(songs.indices, id: \.self) { index in
            let song = songs[index]
            SongRow(
                song: song,
                index: index + 1,
                isPlaying: playerVM.currentSong?.id == song.id && playerVM.isPlaying,
                action: {
                    Task { await playerVM.setPlaylist(songs, startIndex: index, albumId: album.id) }
                },
                onMore: {
                    playerVM.stop()
                }
            )
        }
    }
}

struct SongRow: View {
    let song: Song
    let index: Int
    let isPlaying: Bool
    let action: () -> Void
    let onMore: () -> Void
    let favoriteAction: (() -> Void)?
    
    // Interaction states for better UX
    @State private var isPressed = false
    @State private var playIndicatorPhase = 0.0
    
    // Animation states
    @State private var showPlayIndicator = false
    private let animationTimer = Timer.publish(every: 0.8, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack (spacing: DSLayout.elementGap){
            HStack (spacing: DSLayout.elementGap){
                trackNumberSection
                    .padding(.leading, DSLayout.elementGap)

                songInfoSection
                    .frame(maxWidth: .infinity, alignment: .leading)

                durationSection

                actionsSection
                    .padding(.trailing, DSLayout.elementGap)
            }
            .padding(.vertical, DSLayout.contentPadding) // oder 10–12 für bequemes Tappen
            .background(rowBackground)
            .contentShape(Rectangle())
        }
        
        .scaleEffect(isPressed ? 0.98 : 1.0)
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
        .contentShape(Rectangle())
        .onTapGesture {
            triggerHapticFeedback()
            withAnimation(DSAnimations.easeQuick) {
                action()
            }
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(DSAnimations.easeQuick) {
                isPressed = pressing
            }
        }, perform: {})
        .contextMenu {
            enhancedContextMenu
        }
        // Accessibility
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAction {
            action()
        }
    }
    
    // MARK: - Track Number Section
    
    @ViewBuilder
    private var trackNumberSection: some View {
        ZStack {
            if isPlaying && showPlayIndicator {
                EqualizerBars(
                    isActive: showPlayIndicator,
                    accentColor: DSColor.playing
                )
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            } else {
                Text("\(song.track ?? index).")
                    .font(DSText.emphasized)
                    .foregroundStyle(isPlaying ? DSColor.playing : DSColor.onDark)
                    .frame(width: DSLayout.largeIcon, height: DSLayout.largeIcon)
                   /*
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        DSColor.onLight.opacity(0.15),
                                        DSColor.onLight.opacity(0.0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Circle()
                                    .stroke(
                                        DSColor.onLight.opacity(0.2),
                                        lineWidth: 0.2
                                    )
                            )
                            .shadow(color: .black.opacity(0.32), radius: 3, x: 0, y: 1)
                    )
                    */
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                
                
            }
        }
        .animation(DSAnimations.springSnappy, value: showPlayIndicator)
        .frame(width: DSLayout.largeIcon, height: DSLayout.largeIcon)
        .scaledToFit()

    }
    
    
    // MARK: - Song Info Section
    
    private var songInfoSection: some View {
        VStack(alignment: .leading, spacing: DSLayout.tightGap) {
            // Song title
            Text(song.title)
                .font(DSText.emphasized)
                .foregroundStyle(DSColor.onDark)
                .lineLimit(1)
            
            // Artist
            // TODO: only display song.artist when song.artist != album.artist
            /*if let artist = song.artist, !artist.isEmpty {
                Text(artist)
                    .font(DSText.metadata)
                    .foregroundStyle(songTitleColor)
                    .lineLimit(1)
            }
             */
        }
    }
      
    private var songColor: Color {
        if isPlaying {
            return DSColor.playing
        }
        return DSColor.onDark
    }
    
    // MARK: - Duration Section
    
    @ViewBuilder
    private var durationSection: some View {
        if let duration = song.duration, duration > 0 {
            Text(formatDuration(duration))
                .font(DSText.emphasized)
                .foregroundStyle(songColor)

        }
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        HStack(spacing: DSLayout.tightGap) {
            // Heart button with proper context
            if let favoriteAction = favoriteAction {
                HeartButton.songRow(song: song)
                    .onTapGesture {
                        triggerHapticFeedback(.light)
                        favoriteAction()
                    }
            }
            
        }
    }
    
    // MARK: - Row Background
    
    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: DSCorners.tight)
            .fill(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: DSCorners.tight)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
    }
    
    // Dynamic background styling
    private var backgroundColor: Color {
        if isPressed {
            return DSColor.accent.opacity(0.45)
        } else if isPlaying {
            return DSColor.background
        } else {
            return DSColor.background.opacity(0.60)
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
    
    // MARK: - Context Menu
    
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
    
    // Accessibility
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

// MARK: - Convenience Initializers (unchanged)

extension SongRow {
    init(song: Song, index: Int, isPlaying: Bool, action: @escaping () -> Void, onMore: @escaping () -> Void) {
        self.init(song: song, index: index, isPlaying: isPlaying, action: action, onMore: onMore, favoriteAction: nil)
    }
}
