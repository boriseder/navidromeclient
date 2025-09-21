//
//  FavoritesViewContent.swift - MIGRIERT: UnifiedLibraryContainer
//  NavidromeClient
//
//   MIGRIERT: Von ContentOnlyLibraryView zu UnifiedLibraryContainer
//   CLEAN: Single Container-Pattern
//

import SwiftUI

struct FavoritesViewContent: View {
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var playerVM: PlayerViewModel
    
    @StateObject private var favoritesManager = FavoritesManager.shared
    @State private var searchText = ""
    @StateObject private var debouncer = Debouncer()
    @State private var showingClearConfirmation = false

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
    
    var body: some View {
        NavigationStack {
            // ✅ MIGRIERT: Custom Layout für Favorites mit Header
            Group {
                if shouldShowLoading {
                    LoadingView()
                } else if isEmpty && !shouldShowLoading {
                    EmptyStateView(type: .favorites)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if isOfflineMode {
                                OfflineStatusBanner()
                                    .screenPadding()
                                    .padding(.bottom, DSLayout.elementGap)
                            }
                            
                            LazyVStack(spacing: DSLayout.elementGap) {
                                if !favoritesManager.favoriteSongs.isEmpty {
                                    FavoritesStatsHeader()
                                }
                                
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
                        .padding(.bottom, DSLayout.miniPlayerHeight)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search favorites...")
            .refreshable { await refreshFavorites() }
            .task {
                await favoritesManager.loadFavoriteSongs()
            }
            .onChange(of: searchText) { _, _ in
                handleSearchTextChange()
            }
            .navigationDestination(for: Album.self) { album in
                AlbumDetailViewContent(album: album)
            }
            .unifiedToolbar(favoritesToolbarConfig)
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
    }
    
    // Business Logic (unverändert)
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
    
    private var favoritesToolbarConfig: ToolbarConfiguration {
        let left: [ToolbarElement] = []
        
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
            title: "Favorites",
            displayMode: .large,
            showSettings: true
        )
    }
}
