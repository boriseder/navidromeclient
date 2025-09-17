//
//  ArtistDetailView.swift - CLEAN: Pure ViewModel-Routing
//  NavidromeClient
//
//  ✅ ELIMINIERT: Alle direkten Service-Zugriffe
//  ✅ SAUBER: Nur ViewModel/Manager-Routing
//  ✅ VOLLSTÄNDIG: Offline/Online-Integration
//

import SwiftUI

enum ArtistDetailContext {
    case artist(Artist)
    case genre(Genre)
}

struct ArtistDetailView: View {
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

    // MARK: - ✅ COMPUTED PROPERTIES
    
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
            LazyVStack(spacing: Spacing.xl) {
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
                    AlbumGridView(albums: displayAlbums)
                }
                
                Color.clear.frame(height: Sizes.miniPlayer)
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
    
    // MARK: - ✅ HEADER VIEW
    
    private var headerView: some View {
        VStack(spacing: Spacing.l) {
            HStack(spacing: Spacing.l) {
                artistAvatar
                
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text(contextTitle)
                        .font(Typography.title2)
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
        .materialCardStyle()
    }
    
    private var artistAvatar: some View {
        Group {
            if let image = artistImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: Sizes.avatarLarge, height: Sizes.avatarLarge)
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
                    .frame(width: Sizes.avatarLarge, height: Sizes.avatarLarge)
                    .overlay(
                        Image(systemName: contextIcon)
                            .font(.system(size: Sizes.iconLarge))
                            .foregroundStyle(TextColor.onDark)
                    )
            }
        }
        .avatarStyle()
    }
    
    private var contextIcon: String {
        switch context {
        case .artist: return "music.mic"
        case .genre: return "music.note.list"
        }
    }
    
    private var albumCountView: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if !isOfflineMode && !albums.isEmpty {
                AlbumCountBadge(
                    count: albums.count,
                    label: "Total",
                    color: BrandColor.primary
                )
            }
            
            if !availableOfflineAlbums.isEmpty {
                AlbumCountBadge(
                    count: availableOfflineAlbums.count,
                    label: "Downloaded",
                    color: BrandColor.success
                )
            }
        }
    }
    
    private var shuffleButton: some View {
        Button {
            Task { await shufflePlayAllAlbums() }
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "shuffle")
                    .font(Typography.caption)
                Text("Shuffle All")
                    .font(Typography.caption.weight(.semibold))
            }
            .foregroundStyle(TextColor.onDark)
            .padding(.horizontal, Padding.m)
            .padding(.vertical, Padding.s)
            .background(BrandColor.primary, in: Capsule())
        }
    }
    
    // MARK: - ✅ CONTENT LOADING (Pure ViewModel-Routing)
    
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
    
    /// ✅ KORREKT: Direkt über MusicLibraryManager (existierende Methode nutzen)
    private func loadAlbumsViaManager() async {
        guard !isOfflineMode else {
            albums = availableOfflineAlbums
            return
        }
        
        do {
            // ✅ KORREKT: Nutzt existierende loadAlbums(context:) Methode
            albums = try await musicLibraryManager.loadAlbums(context: context)
            print("✅ Loaded \(albums.count) albums via MusicLibraryManager")
        } catch {
            print("❌ Failed to load albums: \(error)")
            errorMessage = "Failed to load albums: \(error.localizedDescription)"
            // Fallback zu Offline
            albums = availableOfflineAlbums
        }
    }
    
    /// ✅ SAUBER: Nur Manager-Routing
    private func loadArtistImageViaManager() async {
        if case .artist(let artist) = context {
            artistImage = await coverArtManager.loadArtistImage(
                artist: artist,
                size: Int(Sizes.avatarLarge)
            )
        }
    }
    
    // MARK: - ✅ SHUFFLE PLAY (Pure ViewModel-Routing)
    
    private func shufflePlayAllAlbums() async {
        let albumsToPlay = displayAlbums
        guard !albumsToPlay.isEmpty else { return }
        
        var allSongs: [Song] = []
        
        for album in albumsToPlay {
            // ✅ DIRECT: MusicLibraryManager für Songs
            let songs = await navidromeVM.loadSongs(for: album.id)
            allSongs.append(contentsOf: songs)
        }
        
        guard !allSongs.isEmpty else {
            print("❌ No songs found in albums")
            return
        }
        
        let shuffledSongs = allSongs.shuffled()
        await playerVM.setPlaylist(shuffledSongs, startIndex: 0, albumId: nil)
        
        if !playerVM.isShuffling {
            playerVM.toggleShuffle()
        }
        
        print("🎵 Started shuffle play with \(shuffledSongs.count) songs")
    }
}

// MARK: - ✅ SUPPORTING COMPONENTS

struct AlbumCountBadge: View {
    let count: Int
    let label: String
    let color: Color
    
    var body: some View {
        Text("\(count) \(label) Album\(count != 1 ? "s" : "")")
            .font(Typography.caption)
            .foregroundStyle(color)
            .padding(.horizontal, Padding.s)
            .padding(.vertical, Padding.xs)
            .background(color.opacity(0.1), in: Capsule())
            .overlay(
                Capsule().stroke(color.opacity(0.3), lineWidth: 1)
            )
    }
}
