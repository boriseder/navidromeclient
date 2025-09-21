//
//  FavoritesView.swift - Lieblingssongs UI
//  NavidromeClient
//
//  CLEAN: Nutzt bestehende Komponenten und Patterns
//

import SwiftUI
import CryptoKit

struct FavoritesView: View {
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var playerVM: PlayerViewModel
    
    @StateObject private var favoritesManager = FavoritesManager.shared
    
    @State private var searchText = ""
    @State private var showingClearConfirmation = false
    @StateObject private var debouncer = Debouncer()
    
    // MARK: - Computed Properties
    
    private var displayedSongs: [Song] {
        let songs = favoritesManager.favoriteSongs
        
        if searchText.isEmpty {
            return songs
        } else {
            return songs.filter { song in
                let titleMatches = song.title.localizedCaseInsensitiveContains(searchText)
                let artistMatches = (song.artist ?? "").localizedCaseInsensitiveContains(searchText)
                let albumMatches = (song.album ?? "").localizedCaseInsensitiveContains(searchText)
                return titleMatches || artistMatches || albumMatches
            }
        }
    }
    
    private var shouldShowLoading: Bool {
        return favoritesManager.isLoading && favoritesManager.favoriteSongs.isEmpty
    }
    
    private var isEmpty: Bool {
        return displayedSongs.isEmpty
    }
    
    private var isOfflineMode: Bool {
        return !networkMonitor.canLoadOnlineContent || offlineManager.isOfflineMode
    }
    
    // MARK: - Main View
    
    var body: some View {
        LibraryView(
            title: "Lieblingssongs",
            isLoading: shouldShowLoading,
            isEmpty: isEmpty && !shouldShowLoading,
            isOfflineMode: isOfflineMode,
            emptyStateType: .favorites,
            onRefresh: { await refreshFavorites() },
            searchText: $searchText,
            searchPrompt: "Search favorites...",
            toolbarConfig: favoritesToolbarConfig
        ) {
            FavoritesListContent()
        }
        .task {
            // Initial load
            await favoritesManager.loadFavoriteSongs()
        }
        .onChange(of: searchText) { _, _ in
            handleSearchTextChange()
        }
        .confirmationDialog(
            "Clear All Favorites?",
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All", role: .destructive) {
                Task { await clearAllFavorites() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all \(favoritesManager.favoriteCount) songs from your favorites.")
        }
    }
    
    // MARK: - Toolbar Configuration
    
    private var favoritesToolbarConfig: ToolbarConfiguration {
        let left: [ToolbarElement] = [
            .asyncCustom(icon: "arrow.clockwise") {
                await refreshFavorites()
            }
        ]
        
        let right: [ToolbarElement] = [
            .menu(icon: "ellipsis", items: [
                MenuAction(title: "Play All", icon: "play.fill") {
                    Task { await playAllFavorites() }
                },
                MenuAction(title: "Shuffle All", icon: "shuffle") {
                    Task { await shuffleAllFavorites() }
                },
                MenuAction(title: "Clear All Favorites", icon: "trash", isDestructive: true) {
                    showingClearConfirmation = true
                }
            ])
        ]

        return ToolbarConfiguration(
            leftItems: left,
            rightItems: right,
            title: "Lieblingssongs",
            displayMode: .large,
            showSettings: true
        )

    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private func FavoritesListContent() -> some View {
        LazyVStack(spacing: DSLayout.elementGap) {
            // Stats Header (wenn nicht leer)
            if !favoritesManager.favoriteSongs.isEmpty {
                FavoritesStatsHeader()
                    .screenPadding()
            }
            
            // Songs List
            ForEach(displayedSongs.indices, id: \.self) { index in
                let song = displayedSongs[index]
                
                FavoriteSongRow(
                    song: song,
                    index: index + 1,
                    isPlaying: playerVM.currentSong?.id == song.id && playerVM.isPlaying,
                    onPlay: {
                        Task {
                            await playerVM.setPlaylist(
                                displayedSongs,
                                startIndex: index,
                                albumId: nil
                            )
                        }
                    },
                    onToggleFavorite: {
                        Task {
                            await favoritesManager.toggleFavorite(song)
                        }
                    }
                )
            }
        }
        .screenPadding()
    }
    
    // MARK: - Actions
    
    private func refreshFavorites() async {
        await favoritesManager.loadFavoriteSongs(forceRefresh: true)
    }
    
    private func playAllFavorites() async {
        guard !displayedSongs.isEmpty else { return }
        
        await playerVM.setPlaylist(
            displayedSongs,
            startIndex: 0,
            albumId: nil
        )
    }
    
    private func shuffleAllFavorites() async {
        guard !displayedSongs.isEmpty else { return }
        
        let shuffledSongs = displayedSongs.shuffled()
        await playerVM.setPlaylist(
            shuffledSongs,
            startIndex: 0,
            albumId: nil
        )
        
        if !playerVM.isShuffling {
            playerVM.toggleShuffle()
        }
    }
    
    private func clearAllFavorites() async {
        await favoritesManager.clearAllFavorites()
    }
    
    private func handleSearchTextChange() {
        debouncer.debounce {
            // Search filtering happens automatically via computed property
        }
    }
}

// MARK: - Stats Header Component

struct FavoritesStatsHeader: View {
    @StateObject private var favoritesManager = FavoritesManager.shared
    
    var body: some View {
        let stats = favoritesManager.getFavoriteStats()
        
        VStack(spacing: DSLayout.elementGap) {
            HStack {
                Label("Your Favorites", systemImage: "heart.fill")
                    .font(DSText.prominent)
                    .foregroundStyle(DSColor.primary)
                
                Spacer()
                
                if let lastRefresh = stats.lastRefresh {
                    Text("Updated \(timeAgoString(from: lastRefresh))")
                        .font(DSText.metadata)
                        .foregroundStyle(DSColor.secondary)
                }
            }
            
            HStack {
                StatsItem(
                    icon: "music.note",
                    value: "\(stats.songCount)",
                    label: "Songs"
                )
                
                Spacer()
                
                StatsItem(
                    icon: "person.2",
                    value: "\(stats.uniqueArtists)",
                    label: "Artists"
                )
                
                Spacer()
                
                StatsItem(
                    icon: "record.circle",
                    value: "\(stats.uniqueAlbums)",
                    label: "Albums"
                )
                
                Spacer()
                
                StatsItem(
                    icon: "clock",
                    value: stats.formattedDuration,
                    label: "Duration"
                )
            }
        }
        .listItemPadding()
        .cardStyle()
    }
    
    private func timeAgoString(from date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m ago"
        } else {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h ago"
        }
    }
}

struct StatsItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: DSLayout.tightGap) {
            Image(systemName: icon)
                .font(DSText.body)
                .foregroundStyle(DSColor.accent)
            
            Text(value)
                .font(DSText.emphasized)
                .foregroundStyle(DSColor.primary)
            
            Text(label)
                .font(DSText.metadata)
                .foregroundStyle(DSColor.secondary)
        }
        .frame(minWidth: 60)
    }
}

// MARK: - Favorite Song Row Component

struct FavoriteSongRow: View {
    let song: Song
    let index: Int
    let isPlaying: Bool
    let onPlay: () -> Void
    let onToggleFavorite: () -> Void
    
    @State private var showingRemoveConfirmation = false
    
    var body: some View {
        HStack(spacing: DSLayout.elementGap) {
            // Track Number / Playing Indicator
            ZStack {
                if isPlaying {
                    EqualizerBars(isActive: true)
                } else {
                    Text("\(index)")
                        .font(DSText.metadata.weight(.medium))
                        .foregroundStyle(DSColor.secondary)
                        .frame(width: 28, height: 28)
                }
            }
            VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                Text(song.title)
                    .font(isPlaying ? DSText.emphasized : DSText.body)
                    .foregroundStyle(isPlaying ? DSColor.playing : DSColor.primary)
                    .lineLimit(1)
                
                HStack(spacing: DSLayout.tightGap) {
                    if let artist = song.artist {
                        Text(artist)
                            .font(DSText.metadata)
                            .foregroundStyle(DSColor.secondary)
                            .lineLimit(1)
                    }
                    
                    if let artist = song.artist, let album = song.album {
                        Text("•")
                            .font(DSText.metadata)
                            .foregroundStyle(DSColor.secondary)
                    }
                    
                    if let album = song.album {
                        Text(album)
                            .font(DSText.metadata)
                            .foregroundStyle(DSColor.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Duration & Heart Button
            HStack(spacing: DSLayout.elementGap) {
                if let duration = song.duration, duration > 0 {
                    Text(formatDuration(duration))
                        .font(DSText.numbers)
                        .foregroundStyle(DSColor.secondary)
                        .monospacedDigit()
                }
                
                Button(action: {
                    showingRemoveConfirmation = true
                }) {
                    Image(systemName: "heart.fill")
                        .font(DSText.body)
                        .foregroundStyle(DSColor.error)
                }
                .confirmationDialog(
                    "Remove from Favorites?",
                    isPresented: $showingRemoveConfirmation
                ) {
                    Button("Remove", role: .destructive) {
                        onToggleFavorite()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will remove \"\(song.title)\" from your favorites.")
                }
            }

        }
    }
    
    // Song Cover mit direktem coverArt für Favorites
    @ViewBuilder
    private func songCoverView(for song: Song, isPlaying: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: DSCorners.element)
                .fill(DSColor.surface.opacity(isPlaying ? 0.2 : 0.1))
                .frame(width: DSLayout.miniCover, height: DSLayout.miniCover)
            
            SongImageView(song: song, isPlaying: isPlaying)
            
            
            // Playing Overlay
            if isPlaying {
                RoundedRectangle(cornerRadius: DSCorners.element)
                    .fill(DSColor.playing.opacity(0.3))
                    .overlay(
                        Image(systemName: "speaker.wave.2.fill")
                            .font(DSText.metadata)
                            .foregroundStyle(DSColor.playing)
                    )
            }
        
        }
        .listItemPadding()
        .background(
            RoundedRectangle(cornerRadius: DSCorners.element)
                .fill(isPlaying ? DSColor.playing.opacity(0.1) : DSColor.background)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onPlay()
        }
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
