//
//  ArtistDetailViewContent.swift - ENHANCED: Integration of Modern Header
//  NavidromeClient
//
//   ENHANCED: Uses new ArtistDetailHeader component
//   CLEAN: Simplified existing code, better separation of concerns
//

import SwiftUI

enum ArtistDetailContext {
    case artist(Artist)
    case genre(Genre)
}

struct ArtistDetailViewContent: View {
    let context: ArtistDetailContext
    
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
        if case .artist(let a) = context { return a }
        return nil
    }
    
    private var isOfflineMode: Bool {
        !networkMonitor.canLoadOnlineContent || offlineManager.isOfflineMode
    }
    
    private var availableOfflineAlbums: [Album] {
        switch context {
        case .artist(let artist):
            return offlineManager.getOfflineAlbums(for: artist)
        case .genre(let genre):
            return offlineManager.getOfflineAlbums(for: genre)
        }
    }
    
    private var contextTitle: String {
        switch context {
        case .artist(let artist): return artist.name
        case .genre(let genre): return genre.value
        }
    }
    
    private var displayAlbums: [Album] {
        return isOfflineMode ? availableOfflineAlbums : albums
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: DSLayout.screenGap) {
                // MARK: - Header
                VStack(spacing: 0) {
                    ZStack {
                        // Hintergrund aus Avatar (blur + gradient)
                        if let artistImage = artistImage {
                            Image(uiImage: artistImage)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 300)
                                .clipped()
                                .blur(radius: 30)
                                .overlay(
                                    LinearGradient(
                                        colors: [.black.opacity(0.5), .clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .ignoresSafeArea(edges: .top)
                        } else {
                            Color.gray.opacity(0.3)
                                .frame(height: 300)
                                .ignoresSafeArea(edges: .top)
                        }
                        
                        
                        
                        // Avatar + Name
                        VStack(spacing: 16) {
                            if let artistImage = artistImage {
                                Image(uiImage: artistImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 200, height: 200)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                LinearGradient(
                                                    colors: [.blue, .purple],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 4
                                            )
                                    )
                                    .shadow(radius: 8)
                            } else {
                                Circle()
                                    .fill(LinearGradient(colors: [.blue, .purple],
                                                         startPoint: .topLeading,
                                                         endPoint: .bottomTrailing))
                                    .frame(width: 140, height: 140)
                                    .overlay(
                                        Image(systemName: "music.mic")
                                            .font(.system(size: 50))
                                            .foregroundColor(.white)
                                    )
                            }
                            
                            if let name = artist?.name {
                                Text(name)
                                    .font(.title.bold())
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(.bottom, 24)
                    
                    // MARK: - Action Buttons
                    HStack(spacing: 16) {
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
                .screenPadding()
                
                // ENHANCED: Content section with better empty states
                if isLoading {
                    LoadingView(
                        title: "Loading Albums...",
                        subtitle: "Discovering \(contextTitle)'s music"
                    )
                    .screenPadding()
                } else if let error = errorMessage {
                    // ENHANCED: Error state with retry
                    VStack(spacing: DSLayout.contentGap) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(DSColor.warning)
                        
                        Text("Unable to Load Albums")
                            .font(DSText.itemTitle)
                            .foregroundStyle(DSColor.primary)
                        
                        Text(error)
                            .font(DSText.body)
                            .foregroundStyle(DSColor.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Try Again") {
                            Task { await loadContent() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .screenPadding()
                } else if isOfflineMode && availableOfflineAlbums.isEmpty {
                    // ENHANCED: Offline empty state
                    EmptyStateView(
                        type: .artists,
                        customTitle: "No Downloaded Content",
                        customMessage: emptyMessageForContext,
                        primaryAction: EmptyStateAction("Browse Online Content") {
                            offlineManager.switchToOnlineMode()
                        }
                    )
                    .screenPadding()
                } else if !displayAlbums.isEmpty {
                    // ENHANCED: Albums grid
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
                
                Color.clear.frame(height: DSLayout.miniPlayerHeight)
            }
        }
        .navigationTitle(contextTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadContent()
        }
        .refreshable {
            await loadContent()
        }
    }
    
    // MARK: - ENHANCED: Data Loading
    
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
        } catch {
            errorMessage = "Failed to load albums: \(error.localizedDescription)"
            albums = availableOfflineAlbums
        }
    }
    
    private func loadArtistImageViaManager() async {
        if case .artist(let artist) = context {
            artistImage = await coverArtManager.loadArtistImage(
                artist: artist,
                size: Int(DSLayout.avatar * 2) // Higher resolution for header
            )
        }
    }
    
    // ENHANCED: Shuffle functionality moved from header
    private func shufflePlayAllAlbums() async {
        let albumsToPlay = displayAlbums
        guard !albumsToPlay.isEmpty else { return }
        
        var allSongs: [Song] = []
        
        // Load songs from all albums
        for album in albumsToPlay {
            let songs = await navidromeVM.loadSongs(for: album.id)
            allSongs.append(contentsOf: songs)
        }
        
        guard !allSongs.isEmpty else { return }
        
        let shuffledSongs = allSongs.shuffled()
        await playerVM.setPlaylist(shuffledSongs, startIndex: 0, albumId: nil)
        
        if !playerVM.isShuffling {
            playerVM.toggleShuffle()
        }
    }
    
    // MARK: - Helper Properties
    
    private var emptyMessageForContext: String {
        switch context {
        case .artist(let artist):
            return "No albums from \(artist.name) are downloaded for offline listening."
        case .genre(let genre):
            return "No \(genre.value) albums are downloaded for offline listening."
        }
    }
    
    private var headerBackground: some View {
        ZStack {
            // Base background
            DSColor.surface
            
            // ENHANCED: Subtle gradient overlay
            LinearGradient(
                colors: [
                    DSColor.surface,
                    DSColor.surface.opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // ENHANCED: Artist image background blur (if available)
            if let artistImage = artistImage {
                Image(uiImage: artistImage)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 30)
                    .opacity(0.08)
                    .clipped()
            }
        }
    }

    private var totalAlbumCount: Int {
        isOfflineMode ? availableOfflineAlbums.count : albums.count
    }

}
