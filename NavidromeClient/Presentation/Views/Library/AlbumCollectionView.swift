//
//  AlbumCollectionView.swift - FIXED: Action buttons and simplified logic
//  NavidromeClient
//
//   FIXED: Play All and Shuffle buttons now functional
//   CLEANED: Removed unused properties and redundant logic
//   SIMPLIFIED: Direct manager usage without view state duplication
//

import SwiftUI

enum AlbumCollectionContext {
    case byArtist(Artist)
    case byGenre(Genre)
}

struct AlbumCollectionView: View {
    let context: AlbumCollectionContext
    
    @EnvironmentObject var songManager: SongManager
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var coverArtManager: CoverArtManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var musicLibraryManager: MusicLibraryManager
    @EnvironmentObject var theme: ThemeManager

    @State private var albums: [Album] = []

    private var displayedAlbums: [Album] {
        return networkMonitor.shouldLoadOnlineContent ? albums : availableOfflineAlbums
    }
    
    private var currentState: ViewState? {
        if albums.isEmpty && !musicLibraryManager.hasLoadedInitialData {
            return .loading("Loading albums")
        } else if albums.isEmpty {
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
            // Background Layer
            if case .byArtist = context {
                artistBlurredBackground
            }
            
            theme.backgroundColor.opacity(0.3).ignoresSafeArea()

            
            ScrollView {
                LazyVStack(spacing: DSLayout.screenGap) {
                    // Header Section
                    ZStack {
                        VStack(spacing: DSLayout.screenGap) {
                            if case .byArtist = context {
                                artistHeroHeader
                            } else if case .byGenre = context {
                                genreHeroHeader
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .ignoresSafeArea(edges: .top)

                    // Unified State View or Content
                    if let state = currentState {
                        UnifiedStateView(
                            state: state,
                            primaryAction: StateAction("Try Again") {
                                Task {
                                    await loadContent()
                                }
                            }
                        )
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
    
    // MARK: - Data Loading
    
    @MainActor
    private func loadContent() async {
        do {
            albums = try await musicLibraryManager.loadAlbums(context: context)
            AppLogger.ui.info("Loaded \(albums.count) albums for \(contextTitle)")
        } catch {
            albums = availableOfflineAlbums
            AppLogger.ui.error("Failed to load albums: \(error)")
        }
    }
    
    // MARK: - Playback Actions
    
    private func playAllAlbums() async {
        let albumsToPlay = displayedAlbums
        guard !albumsToPlay.isEmpty else {
            AppLogger.ui.info("No albums to play")
            return
        }
        
        AppLogger.ui.info("Playing all albums for \(contextTitle) (\(albumsToPlay.count) albums)")
        
        var allSongs: [Song] = []
        
        for album in albumsToPlay {
            let songs = await songManager.loadSongs(for: album.id)
            allSongs.append(contentsOf: songs)
        }
        
        guard !allSongs.isEmpty else {
            AppLogger.ui.info("No songs found in albums")
            return
        }
        
        AppLogger.ui.info("Starting playback with \(allSongs.count) songs")
        await playerVM.setPlaylist(allSongs, startIndex: 0, albumId: nil)
        
        if playerVM.isShuffling {
            playerVM.toggleShuffle()
        }
    }
    
    private func shuffleAllAlbums() async {
        let albumsToPlay = displayedAlbums
        guard !albumsToPlay.isEmpty else {
            AppLogger.ui.info("No albums to shuffle")
            return
        }
        
        AppLogger.ui.info("Shuffling all albums for \(contextTitle) (\(albumsToPlay.count) albums)")
        
        var allSongs: [Song] = []
        
        for album in albumsToPlay {
            let songs = await songManager.loadSongs(for: album.id)
            allSongs.append(contentsOf: songs)
        }
        
        guard !allSongs.isEmpty else {
            AppLogger.ui.info("No songs found in albums")
            return
        }
        
        let shuffledSongs = allSongs.shuffled()
        
        AppLogger.ui.info("Starting shuffled playback with \(shuffledSongs.count) songs")
        await playerVM.setPlaylist(shuffledSongs, startIndex: 0, albumId: nil)
        
        if !playerVM.isShuffling {
            playerVM.toggleShuffle()
        }
    }
    
    // MARK: - Helper Properties
    
    private var albumCountText: String {
        let count = displayedAlbums.count
        switch context {
        case .byArtist:
            return "\(count) Album\(count != 1 ? "s" : "")"
        case .byGenre:
            return "\(count) Album\(count != 1 ? "s" : "") in this genre"
        }
    }
    
    @ViewBuilder
    private var artistBlurredBackground: some View {
        GeometryReader { geo in
            if let artist {
                ArtistImageView(artist: artist, index: 0, context: .fullscreen)
                    .contentShape(Rectangle())
                    .blur(radius: 20)
                    .offset(
                        x: -1 * (CGFloat(ImageContext.fullscreen.size) - geo.size.width) / 2,
                        y: -geo.size.height * 0.15
                    )
                    .overlay(
                        LinearGradient(
                            colors: [
                                .black.opacity(0.7),
                                .black.opacity(0.35),
                                .black.opacity(0.2),
                                .black.opacity(0.3),
                                .black.opacity(0.7),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .offset(
                            x: -1 * (CGFloat(ImageContext.fullscreen.size) - geo.size.width) / 2,
                            y: -geo.size.height * 0.15)
                    )
                    .ignoresSafeArea(edges: .top)
            }
        }
    }
    
    // MARK: - Artist Hero Content
    
    @ViewBuilder
    private var artistHeroHeader: some View {
        VStack(spacing: DSLayout.elementPadding) {
            if let artist {
                ArtistImageView(artist: artist, index: 0, context: .detail)
                    .clipShape(
                        RoundedRectangle(cornerRadius: DSCorners.tight)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DSCorners.tight)
                            .stroke(
                                .white.opacity(0.25),
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: .black.opacity(0.6),
                        radius: 20,
                        x: 0,
                        y: 10
                    )
                    .shadow(
                        color: .black.opacity(0.3),
                        radius: 40,
                        x: 0,
                        y: 20
                    )
            }
                
            VStack(spacing: DSLayout.tightGap) {
                Text(contextTitle)
                    .font(DSText.pageTitle)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                    .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                Text(albumCountText)
                    .font(DSText.detail)
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                    .lineLimit(1)
            }
            .padding(.horizontal, DSLayout.screenPadding)

            actionButtonsFloating
            
            Spacer()
        }
    }
    
    // MARK: - Genre Content
    
    @ViewBuilder
    private var genreHeroHeader: some View {
        VStack(spacing: DSLayout.elementGap) {
            Text(contextTitle)
                .font(DSText.pageTitle)
                .foregroundStyle(DSColor.onDark)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            Text(albumCountText)
                .font(DSText.detail)
                .foregroundStyle(DSColor.onDark)
                .lineLimit(1)
        }
        .padding(.horizontal, DSLayout.screenPadding)
        .padding(.top, DSLayout.screenPadding)
    }
    
    // MARK: - Floating Action Buttons
    
    @ViewBuilder
    private var actionButtonsFloating: some View {
        HStack(spacing: DSLayout.contentGap) {
            
            // Play All Button - Primary action
            Button {
                Task { await playAllAlbums() }
            } label: {
                HStack(spacing: DSLayout.contentGap) {
                    Image(systemName: "play.fill")
                        .font(DSText.emphasized)
                    Text("Play All")
                        .font(DSText.emphasized)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, DSLayout.contentPadding)
                .padding(.vertical, DSLayout.elementPadding)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.2, green: 0.8, blue: 0.2),
                                    Color(red: 0.15, green: 0.7, blue: 0.15)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
                        .shadow(color: .green.opacity(0.3), radius: 12, x: 0, y: 6)
                )
            }
            
            // Shuffle Button - Secondary action
            Button {
                Task { await shuffleAllAlbums() }
            } label: {
                HStack(spacing: DSLayout.contentGap) {
                    Image(systemName: "shuffle")
                        .font(DSText.emphasized)
                    Text("Shuffle")
                        .font(DSText.emphasized)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, DSLayout.contentPadding)
                .padding(.vertical, DSLayout.elementPadding)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.25),
                                    .white.opacity(0.15)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            Capsule()
                                .stroke(.white.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
                )
            }
        }
    }
}
