//
//  AlbumCollectionView.swift - MIGRATED: Unified State System
//  NavidromeClient
//
//   ELIMINATED: Custom LoadingView, EmptyStateView (~40 LOC)
//   UNIFIED: Complete offline pattern with 4-line state logic
//   CLEAN: Single state component handles all scenarios
//

import SwiftUI

enum AlbumCollectionContext {
    case byArtist(Artist)
    case byGenre(Genre)
}

struct AlbumCollectionView: View {
    let context: AlbumCollectionContext
    
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var songManager: SongManager
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var coverArtManager: CoverArtManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var musicLibraryManager: MusicLibraryManager
    
    @State private var albums: [Album] = []
    @State private var artistImage: UIImage?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private var displayedAlbums: [Album] {
        return networkMonitor.shouldLoadOnlineContent ? albums : availableOfflineAlbums
    }
    
    private var currentState: ViewState? {
        if isLoading && displayedAlbums.isEmpty {
            return .loading("Loading albums")
        } else if let error = errorMessage {
            return .serverError
        } else if displayedAlbums.isEmpty && musicLibraryManager.hasLoadedInitialData {
            return .empty(type: .albums)
        }
        return nil
    }

    private var artist: Artist? {
        if case .byArtist(let a) = context { return a }
        return nil
    }
    
    private var availableOfflineAlbums: [Album] {
        switch context {
        case .byArtist(let artist):
            return offlineManager.getOfflineAlbums(for: artist)
        case .byGenre(let genre):
            return offlineManager.getOfflineAlbums(for: genre)
        }
    }
    
    private var contextTitle: String {
        switch context {
        case .byArtist(let artist): return artist.name
        case .byGenre(let genre): return genre.value
        }
    }
    
    var body: some View {
        ZStack {
            DynamicMusicBackground()
            
            ScrollView {
                LazyVStack(spacing: DSLayout.screenGap) {
                    // MARK: - Header Section
                    AlbumCollectionHeaderView(
                        context: context,
                        artistImage: artistImage,
                        contextTitle: contextTitle,
                        albumCountText: albumCountText,
                        contextIcon: contextIcon,
                        onPlayAll: { Task { await playAllAlbums() } },
                        onShuffle: { Task { await shuffleAllAlbums() } }
                    )
                    
                    // UNIFIED: Single component handles all states
                    if let state = currentState {
                        UnifiedStateView(
                            state: state,
                            primaryAction: StateAction("Try Again") {
                                Task {
                                    await loadContent()
                                }
                            }                        )
                        .padding(.horizontal, DSLayout.screenPadding)
                    } else {
                        contentView
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Album.self) { album in
                AlbumDetailViewContent(album: album)
            }
            .task {
                await loadContent()
            }
            .refreshable {
                guard networkMonitor.shouldLoadOnlineContent else { return }
                await loadContent()
            }
        }
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if !networkMonitor.shouldLoadOnlineContent {
                    OfflineStatusBanner()
                        .padding(.horizontal, DSLayout.screenPadding)
                        .padding(.bottom, DSLayout.elementGap)
                }
                
                LazyVGrid(
                    columns: GridColumns.two,
                    alignment: .leading,
                    spacing: DSLayout.elementGap
                ) {
                    ForEach(displayedAlbums.indices, id: \.self) { index in
                        let album = displayedAlbums[index]
                        
                        NavigationLink(value: album) {
                            CardItemContainer(content: .album(album), index: index)
                        }
                    }
                }
                .padding(.horizontal, DSLayout.screenPadding)
                .padding(.bottom, DSLayout.miniPlayerHeight)
            }
        }
    }
    
    // MARK: - Button Action Methods
    
    /// Play all albums sequentially
    private func playAllAlbums() async {
        let albumsToPlay = displayedAlbums
        guard !albumsToPlay.isEmpty else {
            print("⚠️ No albums to play")
            return
        }
        
        print("🎵 Playing all albums for \(contextTitle) (\(albumsToPlay.count) albums)")
        
        var allSongs: [Song] = []
        
        // Load songs from all albums
        for album in albumsToPlay {
            let songs = await songManager.loadSongs(for: album.id)
            allSongs.append(contentsOf: songs)
        }
        
        guard !allSongs.isEmpty else {
            print("⚠️ No songs found in albums")
            return
        }
        
        print("🎵 Starting playback with \(allSongs.count) songs")
        await playerVM.setPlaylist(allSongs, startIndex: 0, albumId: nil)
        
        // Ensure shuffle is OFF for play all
        if playerVM.isShuffling {
            playerVM.toggleShuffle()
        }
    }
    
    /// Shuffle all albums
    private func shuffleAllAlbums() async {
        let albumsToPlay = displayedAlbums
        guard !albumsToPlay.isEmpty else {
            print("⚠️ No albums to shuffle")
            return
        }
        
        print("🔀 Shuffling all albums for \(contextTitle) (\(albumsToPlay.count) albums)")
        
        var allSongs: [Song] = []
        
        // Load songs from all albums
        for album in albumsToPlay {
            let songs = await songManager.loadSongs(for: album.id)
            allSongs.append(contentsOf: songs)
        }
        
        guard !allSongs.isEmpty else {
            print("⚠️ No songs found in albums")
            return
        }
        
        // Shuffle the complete song list
        let shuffledSongs = allSongs.shuffled()
        
        print("🔀 Starting shuffled playback with \(shuffledSongs.count) songs")
        await playerVM.setPlaylist(shuffledSongs, startIndex: 0, albumId: nil)
        
        // Ensure shuffle is ON for shuffle all
        if !playerVM.isShuffling {
            playerVM.toggleShuffle()
        }
    }
    
    // MARK: - Data Loading
    
    @MainActor
    private func loadContent() async {
        isLoading = true
        errorMessage = nil
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.loadAlbumsViaManager()
            }
            
            group.addTask {
                await self.loadArtistImageViaManager()
            }
        }
        
        isLoading = false
    }
    
    private func loadAlbumsViaManager() async {
        guard networkMonitor.shouldLoadOnlineContent else {
            albums = availableOfflineAlbums
            return
        }
        
        do {
            albums = try await musicLibraryManager.loadAlbums(context: context)
            print("Loaded \(albums.count) albums for \(contextTitle)")
        } catch {
            errorMessage = "Failed to load albums: \(error.localizedDescription)"
            albums = availableOfflineAlbums
            print("❌ Failed to load albums: \(error)")
        }
    }
    
    private func loadArtistImageViaManager() async {
        if case .byArtist(let artist) = context {
            artistImage = await coverArtManager.loadArtistImage(
                artist: artist,
                size: Int(DSLayout.avatar * 2) // Higher resolution for header
            )
        }
    }
    
    // MARK: - Helper Properties
    
    private var contextIcon: String {
        switch context {
        case .byArtist: return "music.mic"
        case .byGenre: return "music.note.list"
        }
    }
    
    private var albumCountText: String {
        let count = displayedAlbums.count
        switch context {
        case .byArtist:
            return "\(count) Album\(count != 1 ? "s" : "")"
        case .byGenre:
            return "\(count) Album\(count != 1 ? "s" : "") in this genre"
        }
    }
}
