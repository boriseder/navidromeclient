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

    // UNIFIED: Complete Offline Pattern
    private var connectionState: EffectiveConnectionState {
        networkMonitor.effectiveConnectionState
    }
    
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
    
    private var currentState: ViewState? {
        if favoritesManager.isLoading && favoritesManager.favoriteSongs.isEmpty {
            return .loading("Loading favorites")
        } else if displayedSongs.isEmpty {
            return .empty(type: .favorites)
        }
        return nil
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                DynamicMusicBackground()
                
                // UNIFIED: Single component handles all states
                if let state = currentState {
                    UnifiedStateView(
                        state: state,
                        primaryAction: StateAction("Refresh") {
                            Task {
                                guard connectionState.shouldLoadOnlineContent else { return }
                                await favoritesManager.loadFavoriteSongs(forceRefresh: true)
                            }
                        }
                    )
                } else {
                    contentView
                }
            }
            .searchable(text: $searchText, prompt: "Search favorites...")
            .refreshable {
                guard connectionState.shouldLoadOnlineContent else { return }
                await refreshFavorites()
            }
            .task {
                await favoritesManager.loadFavoriteSongs()
            }
            .onChange(of: searchText) { _, _ in
                handleSearchTextChange()
            }
            .navigationDestination(for: Album.self) { album in
                AlbumDetailViewContent(album: album)
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if connectionState.isEffectivelyOffline {
                    OfflineStatusBanner()
                        .padding(.horizontal, DSLayout.screenPadding)
                }
                
                LazyVStack(spacing: DSLayout.elementGap) {
                    if !favoritesManager.favoriteSongs.isEmpty {
                        FavoritesStatsHeader()
                            .padding(.top, DSLayout.tightGap)
                            .padding(.bottom, DSLayout.sectionGap)
                    }
                    
                    ForEach(displayedSongs.indices, id: \.self) { index in
                        let song = displayedSongs[index]
                        
                        SongRow(
                            song: song,
                            index: index + 1,
                            isPlaying: playerVM.currentSong?.id == song.id && playerVM.isPlaying,
                            action: {
                                Task {
                                    await playerVM.setPlaylist(
                                        displayedSongs,
                                        startIndex: index,
                                        albumId: nil
                                    )
                                }
                            },
                            onMore: { /* existing more action */ },
                            favoriteAction: {
                                Task {
                                    await favoritesManager.toggleFavorite(song)
                                }
                            }
                        )
                    }
                }
                .padding(.bottom, DSLayout.miniPlayerHeight)
            }
        }
        .padding(.horizontal, DSLayout.screenPadding)
        .navigationTitle("Your favorites")
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)  // dunkler Hintergrund
        .toolbarColorScheme(.dark, for: .navigationBar)        // Titel weiß

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
    /*
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
     */
}
