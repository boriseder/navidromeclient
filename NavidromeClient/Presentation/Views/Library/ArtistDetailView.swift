//
//  ArtistDetailViewContent.swift - MIGRIERT: UnifiedLibraryContainer
//  NavidromeClient
//
//   MIGRIERT: Album Grid nutzt jetzt UnifiedLibraryContainer
//   CLEAN: Single Container-Pattern
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
                            offlineManager.switchToOnlineMode()
                        }
                    )
                    .screenPadding()
                } else if !displayAlbums.isEmpty {
                    // ✅ MIGRIERT: UnifiedLibraryContainer für Album Grid
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
                    isOnline: networkMonitor.canLoadOnlineContent,
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
                size: Int(DSLayout.smallAvatar)
            )
        }
    }
    
    private func shufflePlayAllAlbums() async {
        let albumsToPlay = displayAlbums
        guard !albumsToPlay.isEmpty else { return }
        
        var allSongs: [Song] = []
        
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
}
