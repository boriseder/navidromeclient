//
//  ArtistDetailView.swift - CLEAN: Pure ViewModel-Routing
//  NavidromeClient
//
//   ELIMINIERT: Alle direkten Service-Zugriffe
//   SAUBER: Nur ViewModel/Manager-Routing
//   VOLLSTÄNDIG: Offline/Online-Integration
//

import SwiftUI

enum ArtistDetailContext {
    case artist(Artist)
    case genre(Genre)
}

struct ArtistDetailView: View {

    @EnvironmentObject var deps: AppDependencies
    
    let context: ArtistDetailContext
    
    
    @State private var albums: [Album] = []
    @State private var artistImage: UIImage?
    @State private var isLoading = false
    @State private var errorMessage: String?

    // MARK: -  COMPUTED PROPERTIES
    
    private var artist: Artist? {
        if case .artist(let a) = context { return a }
        return nil
    }
    
    private var isOfflineMode: Bool {
        !deps.networkMonitor.canLoadOnlineContent || deps.offlineManager.isOfflineMode
    }
    
    private var availableOfflineAlbums: [Album] {
        switch context {
        case .artist(let artist):
            return deps.offlineManager.getOfflineAlbums(for: artist)
        case .genre(let genre):
            return deps.offlineManager.getOfflineAlbums(for: genre)
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
    
    private var emptyMessageForContext: String {
        switch context {
        case .artist(let artist):
            return "No albums from \(artist.name) are downloaded for offline listening."
        case .genre(let genre):
            return "No \(genre.value) albums are downloaded for offline listening."
        }
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: DSLayout.screenGap) {
                headerView
                    .screenPadding()
                
                if isOfflineMode && availableOfflineAlbums.isEmpty {
                    EmptyStateView(
                        type: .artists,
                        customTitle: "No Downloaded Content",
                        customMessage: emptyMessageForContext,
                        primaryAction: EmptyStateAction("Browse Online Content") {
                            deps.offlineManager.switchToOnlineMode()
                        }
                    )
                    .screenPadding()
                } else if !displayAlbums.isEmpty {
                    ScrollView {
                        LazyVGrid(columns: GridColumns.two, spacing: DSLayout.contentGap) {
                            ForEach(albums, id: \.id) { album in
                                NavigationLink {
                                    AlbumDetailView(album: album)
                                } label: {
                                    CardItemContainer(content: .album(album), index: 0)
                                }
                            }
                        }
                        .screenPadding()
                        .padding(.bottom, 100) // Approx. DS applied - könnte Sizes.miniPlayer + Padding.s sein
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
        .accountToolbar()
    }
    
    // MARK: -  HEADER VIEW
    
    private var headerView: some View {
        VStack(spacing: DSLayout.sectionGap) {
            HStack(spacing: DSLayout.sectionGap) {
                artistAvatar()
                
                VStack(alignment: .leading, spacing: DSLayout.elementGap) {
                    Text(contextTitle)
                        .font(DSText.sectionTitle)
                        .lineLimit(2)
                    
                    albumCountView
                    
                    if !displayAlbums.isEmpty {
                        shuffleButton
                    }
                }
                
                Spacer()
            }
            
            if isOfflineMode && !availableOfflineAlbums.isEmpty {
                LibraryStatusHeader.artists(
                    count: availableOfflineAlbums.count,
                    isOnline: deps.networkMonitor.canLoadOnlineContent,
                    isOfflineMode: true
                )
            }
        }
        .cardStyle()
    }
    
    private func artistAvatar() -> some View {
        Group {
            if let image = artistImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: DSLayout.smallAvatar, height: DSLayout.smallAvatar)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: DSLayout.smallAvatar, height: DSLayout.smallAvatar)
                    .overlay(
                        Image(systemName: contextIcon)
                            .font(.system(size: DSLayout.largeIcon))
                            .foregroundStyle(DSColor.onDark)
                    )
            }
        }
        .cardStyle()
    }
    
    private var contextIcon: String {
        switch context {
        case .artist: return "music.mic"
        case .genre: return "music.note.list"
        }
    }
    
    private var albumCountView: some View {
        VStack(alignment: .leading, spacing: DSLayout.tightGap) {
            if !isOfflineMode && !albums.isEmpty {
                AlbumCountBadge(
                    count: albums.count,
                    label: "Total",
                    color: DSColor.accent
                )
            }
            
            if !availableOfflineAlbums.isEmpty {
                AlbumCountBadge(
                    count: availableOfflineAlbums.count,
                    label: "Downloaded",
                    color: DSColor.success
                )
            }
        }
    }
    
    private var shuffleButton: some View {
        Button {
            Task { await shufflePlayAllAlbums() }
        } label: {
            HStack(spacing: DSLayout.tightGap) {
                Image(systemName: "shuffle")
                    .font(DSText.metadata)
                Text("Shuffle All")
                    .font(DSText.metadata.weight(.semibold))
            }
            .foregroundStyle(DSColor.onDark)
            .padding(.horizontal, DSLayout.contentPadding)
            .padding(.vertical, DSLayout.elementPadding)
            .background(DSColor.accent, in: Capsule())
        }
    }
    
    // MARK: -  CONTENT LOADING (Pure ViewModel-Routing)
    
    private func loadContent() async {
        isLoading = true
        errorMessage = nil
        
        await withTaskGroup(of: Void.self) { group in
            // Albums via Manager laden
            group.addTask {
                await self.loadAlbumsViaManager()
            }
            
            // Artist Image via Manager laden
            group.addTask {
                await self.loadArtistImageViaManager()
            }
        }
        
        isLoading = false
    }
    
    ///  KORREKT: Direkt über MusicLibraryManager (existierende Methode nutzen)
    private func loadAlbumsViaManager() async {
        guard !isOfflineMode else {
            albums = availableOfflineAlbums
            return
        }
        
        do {
            //  KORREKT: Nutzt existierende loadAlbums(context:) Methode
            albums = try await deps.musicLibraryManager.loadAlbums(context: context)
            print(" Loaded \(albums.count) albums via MusicLibraryManager")
        } catch {
            print("❌ Failed to load albums: \(error)")
            errorMessage = "Failed to load albums: \(error.localizedDescription)"
            // Fallback zu Offline
            albums = availableOfflineAlbums
        }
    }
    
    ///  SAUBER: Nur Manager-Routing
    private func loadArtistImageViaManager() async {
        if case .artist(let artist) = context {
            artistImage = await deps.coverArtManager.loadArtistImage(
                artist: artist,
                size: Int(DSLayout.smallAvatar)
            )
        }
    }
    
    // MARK: -  SHUFFLE PLAY (Pure ViewModel-Routing)
    
    private func shufflePlayAllAlbums() async {
        let albumsToPlay = displayAlbums
        guard !albumsToPlay.isEmpty else { return }
        
        var allSongs: [Song] = []
        
        for album in albumsToPlay {
            //  DIRECT: MusicLibraryManager für Songs
            let songs = await deps.navidromeVM.loadSongs(for: album.id)
            allSongs.append(contentsOf: songs)
        }
        
        guard !allSongs.isEmpty else {
            print("❌ No songs found in albums")
            return
        }
        
        let shuffledSongs = allSongs.shuffled()
        await deps.playerVM.setPlaylist(shuffledSongs, startIndex: 0, albumId: nil)
        
        if !deps.playerVM.isShuffling {
            deps.playerVM.toggleShuffle()
        }
        
        print("🎵 Started shuffle play with \(shuffledSongs.count) songs")
    }
}
