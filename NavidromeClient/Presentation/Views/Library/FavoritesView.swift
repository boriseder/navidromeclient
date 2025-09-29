//
//  FavoritesViewContent.swift - MIGRATED: Unified State System
//  NavidromeClient
//
//   UNIFIED: Single ContentLoadingStrategy for consistent state
//   CLEAN: Proper offline favorites handling
//   FIXED: Consistent state management pattern
//

import SwiftUI

struct FavoritesViewContent: View {
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    
    @StateObject private var favoritesManager = FavoritesManager.shared
    @StateObject private var debouncer = Debouncer()
    
    @State private var searchText = ""
    @State private var showingClearConfirmation = false

    // Single state logic following the pattern
    private var displayedSongs: [Song] {
        let songs = switch networkMonitor.contentLoadingStrategy {
        case .online:
            favoritesManager.favoriteSongs
        case .offlineOnly:
            // In offline mode, show only favorites that are downloaded
            favoritesManager.favoriteSongs.filter { song in
                DownloadManager.shared.isSongDownloaded(song.id)
            }
        }
        
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
        if appConfig.isInitializingServices {
            return .loading("Setting up your music library")
        } else if favoritesManager.isLoading && favoritesManager.favoriteSongs.isEmpty {
            return .loading("Loading favorites")
        } else if displayedSongs.isEmpty && !favoritesManager.isLoading && favoritesManager.lastRefresh != nil {
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
                                guard networkMonitor.contentLoadingStrategy.shouldLoadOnlineContent else { return }
                                await favoritesManager.loadFavoriteSongs(forceRefresh: true)
                            }
                        }
                    )
                } else {
                    contentView
                }
            }
            .navigationTitle("Your favorites")
            .navigationBarTitleDisplayMode(.automatic)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .searchable(text: $searchText, prompt: "Search favorites...")
            .refreshable {
                guard networkMonitor.contentLoadingStrategy.shouldLoadOnlineContent else { return }
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

           /* .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Play All") {
                            Task { await playAllFavorites() }
                        }
                        
                        Button("Shuffle All") {
                            Task { await shuffleAllFavorites() }
                        }
                        
                        if networkMonitor.contentLoadingStrategy.shouldLoadOnlineContent {
                            Divider()
                            
                            Button("Clear All Favorites", role: .destructive) {
                                showingClearConfirmation = true
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.primary)
                    }
                }
            }
            .alert("Clear All Favorites?", isPresented: $showingClearConfirmation) {
                Button("Clear", role: .destructive) {
                    Task { await clearAllFavorites() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove all songs from your favorites.")
            }
            */
        }
    }

    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DSLayout.contentGap) {

                if case .offlineOnly(let reason) = networkMonitor.contentLoadingStrategy {
                    OfflineReasonBanner(reason: reason)
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
    }

    // MARK: - Business Logic (unchanged)
    
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
