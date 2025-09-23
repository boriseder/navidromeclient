//
//  ArtistDetailViewContent.swift - FIXED: Button Actions & View Issues
//  NavidromeClient
//
//   FIXED: Play All and Shuffle All button implementations
//   FIXED: Navigation destinations and view structure
//   CLEAN: Proper error handling and loading states
//

import SwiftUI

enum AlbumCollectionContext {
    case byArtist(Artist)
    case byGenre(Genre)
}

struct AlbumCollectionView: View {
    let context: AlbumCollectionContext
    
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var coverArtManager: CoverArtManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var musicLibraryManager: MusicLibraryManager
    
    @State private var albums: [Album] = []
    @State private var artistImage: UIImage?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var artist: Artist? {
        if case .byArtist(let a) = context { return a }
        return nil
    }
    
    private var isOfflineMode: Bool {
        !networkMonitor.canLoadOnlineContent || offlineManager.isOfflineMode
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
    
    private var displayAlbums: [Album] {
        return isOfflineMode ? availableOfflineAlbums : albums
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: DSLayout.screenGap) {
                // MARK: - Header Section
                AlbumCollectionHeaderView(
                    context: context,
                    artistImage: artistImage,
                    contextTitle: contextTitle,
                    albumCountText: albumCountText,
                    contextIcon: contextIcon
                )

                // MARK: - Action Buttons (FIXED)
                if !displayAlbums.isEmpty {
                    HStack(spacing: DSLayout.contentGap) {
                        Button {
                            Task { await playAllAlbums() }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Play All")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(.green)
                            .clipShape(Capsule())
                            .shadow(radius: 4)
                        }
                        
                        // Shuffle All Button with correct implementation
                        Button {
                            Task { await shuffleAllAlbums() }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "shuffle")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Shuffle All")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(.orange)
                            .clipShape(Capsule())
                            .shadow(radius: 4)
                        }
                    }
                    .padding(.horizontal, DSLayout.screenPadding)

                }
                
                // MARK: - Content Section
                contentSection
                
                Color.clear.frame(height: DSLayout.miniPlayerHeight)
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
            await loadContent()
        }
    }
        
    
    // MARK: - Content Section
    
    @ViewBuilder
    private var contentSection: some View {
            if isLoading {
                LoadingView(
                    title: "Loading Albums...",
                    subtitle: "Discovering \(contextTitle)'s music"
                )
                .screenPadding()
            } else if let error = errorMessage {
                errorStateView
            } else if isOfflineMode && availableOfflineAlbums.isEmpty {
                offlineEmptyStateView
            } else if !displayAlbums.isEmpty {
                albumsGridView
            } else {
                EmptyStateView(
                    type: .albums,
                    customTitle: "No Albums Found",
                    customMessage: "No albums available for \(contextTitle)"
                )
                .screenPadding()
            }
    }
    
    @ViewBuilder
    private var errorStateView: some View {
        VStack(spacing: DSLayout.contentGap) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(DSColor.warning)
            
            Text("Unable to Load Albums")
                .font(DSText.itemTitle)
                .foregroundStyle(DSColor.primary)
            
            Text(errorMessage ?? "Unknown error occurred")
                .font(DSText.body)
                .foregroundStyle(DSColor.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                Task { await loadContent() }
            }
            .buttonStyle(.borderedProminent)
        }
        .screenPadding()
    }
    
    @ViewBuilder
    private var offlineEmptyStateView: some View {
        EmptyStateView(
            type: .artists,
            customTitle: "No Downloaded Content",
            customMessage: emptyMessageForContext,
            primaryAction: EmptyStateAction("Browse Online Content") {
                offlineManager.switchToOnlineMode()
            }
        )
        .screenPadding()
    }
    
    @ViewBuilder
    private var albumsGridView: some View {
        UnifiedLibraryContainer(
            items: displayAlbums,
            isLoading: false,
            isEmpty: false,
            isOfflineMode: isOfflineMode,
            emptyStateType: .albums,
            layout: .twoColumnGrid
        ) { album, index in
            NavigationLink(value: album) {
                CardItemContainer(content: .album(album), index: index)
            }
        }
    }
    
    // MARK: - Button Action Methods
    
    /// Play all albums sequentially
    private func playAllAlbums() async {
        let albumsToPlay = displayAlbums
        guard !albumsToPlay.isEmpty else {
            print("⚠️ No albums to play")
            return
        }
        
        print("🎵 Playing all albums for \(contextTitle) (\(albumsToPlay.count) albums)")
        
        var allSongs: [Song] = []
        
        // Load songs from all albums
        for album in albumsToPlay {
            let songs = await navidromeVM.loadSongs(for: album.id)
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
        let albumsToPlay = displayAlbums
        guard !albumsToPlay.isEmpty else {
            print("⚠️ No albums to shuffle")
            return
        }
        
        print("🔀 Shuffling all albums for \(contextTitle) (\(albumsToPlay.count) albums)")
        
        var allSongs: [Song] = []
        
        // Load songs from all albums
        for album in albumsToPlay {
            let songs = await navidromeVM.loadSongs(for: album.id)
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
        guard !isOfflineMode else {
            albums = availableOfflineAlbums
            return
        }
        
        do {
            albums = try await musicLibraryManager.loadAlbums(context: context)
            print("✅ Loaded \(albums.count) albums for \(contextTitle)")
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
        let count = displayAlbums.count
        switch context {
        case .byArtist:
            return "\(count) Album\(count != 1 ? "s" : "")"
        case .byGenre:
            return "\(count) Album\(count != 1 ? "s" : "") in this genre"
        }
    }
    
    private var emptyMessageForContext: String {
        switch context {
        case .byArtist(let artist):
            return "No albums from \(artist.name) are downloaded for offline listening."
        case .byGenre(let genre):
            return "No \(genre.value) albums are downloaded for offline listening."
        }
    }
}
