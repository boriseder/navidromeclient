//
//  ArtistDetailView.swift - REFACTORED to Pure UI
//  NavidromeClient
//
//  ✅ ELIMINATES: ArtistDetailViewModel completely
//  ✅ CLEAN: Direct manager calls instead of ViewModel wrapper
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
    @EnvironmentObject var downloadManager: DownloadManager
    
    @State private var albums: [Album] = []
    @State private var artistImage: UIImage?
    @State private var isLoading = false
    @State private var isLoadingSongs = false
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
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                headerView
                    .padding(.top, Spacing.s)
                
                if isOfflineMode || !availableOfflineAlbums.isEmpty {
                    offlineStatusSection
                        .padding(.top, Spacing.m)
                }
                
                albumsSection
                    .padding(.top, Spacing.m)
            }
        }
        .scrollIndicators(.hidden)
        .navigationTitle(contextTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadContent()
        }
        .accountToolbar()
    }
    
    private var headerView: some View {
        HStack(spacing: Spacing.l) {
            artistAvatar
            artistInfo
            Spacer()
        }
        .listItemPadding()
        .materialCardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: Radius.m)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var artistAvatar: some View {
        Group {
            if let image = artist.artistImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: Sizes.avatarLarge, height: Sizes.avatarLarge)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(BackgroundColor.secondary)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "music.mic")
                            .font(.system(size: Sizes.iconLarge))
                            .foregroundStyle(TextColor.onDark)
                    )
            }
        }
        .cardShadow()
    }
    
    private var artistInfo: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(artist.title(for: context))
                .font(Typography.title2)
                .lineLimit(2)
            
            // ✅ ENHANCED: Show both online and offline album counts
            albumCountView
            
            if artist.albums.isEmpty {
                HStack {
                    shuffleButton
                }
            }
        }
    }
    
    // ✅ NEW: Album Count View with Offline Support
    private var albumCountView: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if !isOfflineMode {
                albumCountBadge(
                    count: artist.albums.count,
                    label: "Total",
                    color: BrandColor.primary
                )
            }
            
            if !availableOfflineAlbums.isEmpty {
                albumCountBadge(
                    count: availableOfflineAlbums.count,
                    label: "Downloaded",
                    color: BrandColor.success
                )
            }
        }
    }
    
    private func albumCountBadge(count: Int, label: String, color: Color) -> some View {
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

    // ✅ FOCUSED: Route through ViewModels only
    private func loadContent() async {
        isLoading = true
        errorMessage = nil
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.loadAlbumsViaViewModel()
            }
            group.addTask {
                await self.loadArtistImageViaManager()
            }
        }
        
        isLoading = false
    }
    
    // ✅ ROUTE: Through NavidromeViewModel (no direct service access)
    private func loadAlbumsViaViewModel() async {
        do {
            if isOfflineMode {
                albums = availableOfflineAlbums
            } else {
                // ✅ ROUTE: Through NavidromeViewModel.loadAlbums()
                albums = try await navidromeVM.loadAlbums(context: context)
            }
            
            print("✅ Loaded \(albums.count) albums for \(contextTitle) via NavidromeViewModel")
        } catch {
            print("❌ Failed to load albums via NavidromeViewModel: \(error)")
            errorMessage = "Failed to load albums: \(error.localizedDescription)"
            
            // Fallback to offline
            albums = availableOfflineAlbums
        }
    }
    
    // ✅ ROUTE: Through CoverArtManager (no direct service access)
    private func loadArtistImageViaManager() async {
        if case .artist(let artist) = context {
            artistImage = await coverArtManager.loadArtistImage(artist: artist, size: 300)
        }
    }
    
   
    // ✅ SHUFFLE PLAY: Route through NavidromeViewModel for song loading
    @MainActor
    private func shufflePlayAllAlbums() async {
        let albumsToPlay = isOfflineMode ? availableOfflineAlbums : albums
        guard !albumsToPlay.isEmpty else { return }
        
        isLoadingSongs = true
        defer { isLoadingSongs = false }
        
        var allSongs: [Song] = []
        
        for album in albumsToPlay {
            // ✅ ROUTE: Through NavidromeViewModel.loadSongs()
            let songs = await navidromeVM.loadSongs(for: album.id)
            allSongs.append(contentsOf: songs)
        }
        
        guard !allSongs.isEmpty else {
            print("❌ No songs found in any albums")
            return
        }
        
        let shuffledSongs = allSongs.shuffled()
        print("🎵 Starting shuffle play with \(shuffledSongs.count) songs via NavidromeViewModel")
        
        await playerVM.setPlaylist(
            shuffledSongs,
            startIndex: 0,
            albumId: nil
        )
        
        if !playerVM.isShuffling {
            playerVM.toggleShuffle()
        }
    }

    private var offlineStatusSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Image(systemName: isOfflineMode ? "wifi.slash" : "arrow.down.circle.fill")
                    .foregroundStyle(isOfflineMode ? BrandColor.warning : BrandColor.success)
                
                Text(offlineStatusText)
                    .font(Typography.caption)
                    .foregroundStyle(isOfflineMode ? BrandColor.warning : BrandColor.success)
                
                Spacer()
                
                if !isOfflineMode && !availableOfflineAlbums.isEmpty {
                    Button("View Downloads Only") {
                        offlineManager.switchToOfflineMode()
                    }
                    .font(Typography.caption)
                    .foregroundStyle(BrandColor.primary)
                }
            }
        }
        .listItemPadding()
        .background(
            (isOfflineMode ? BrandColor.warning : BrandColor.success).opacity(0.1),
            in: RoundedRectangle(cornerRadius: Radius.s)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.s)
                .stroke((isOfflineMode ? BrandColor.warning : BrandColor.success).opacity(0.3), lineWidth: 1)
        )
        .screenPadding()
    }
    
    private var offlineStatusText: String {
        if isOfflineMode {
            return availableOfflineAlbums.isEmpty ?
                "No offline content available" :
                "Showing \(availableOfflineAlbums.count) downloaded albums"
        } else {
            return "\(availableOfflineAlbums.count) albums available offline"
        }
    }
    
    private var albumsSection: some View {
        VStack(spacing: Spacing.l) {
            if isLoading {
                LoadingView()
            } else if let error = errorMessage {
                errorView(error)
            } else {
                let albumsToShow = isOfflineMode ? availableOfflineAlbums : albums
                
                if albumsToShow.isEmpty {
                    EmptyStateView.artists()
                } else {
                    AlbumGridView(albums: albumsToShow)
                }
            }
        }
        .padding(.bottom, 120)
    }
        
    private func errorView(_ error: String) -> some View {
        VStack(spacing: Spacing.l) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundStyle(BrandColor.error)
            
            VStack(spacing: Spacing.s) {
                Text("Error Loading Content")
                    .font(Typography.headline)
                
                Text(error)
                    .font(Typography.subheadline)
                    .foregroundStyle(TextColor.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Retry") {
                Task {
                    await loadContent()
                }
            }
            .primaryButtonStyle()
        }
        .padding(Padding.xl)
        .materialCardStyle()
    }
    
    // MARK: - ✅ SHUFFLE PLAY LOGIC (direct implementation)
    
    @MainActor
    private func shufflePlayAllAlbums() async {
        let albumsToPlay = isOfflineMode ? availableOfflineAlbums : albums
        guard !albumsToPlay.isEmpty else { return }
        
        isLoadingSongs = true
        defer { isLoadingSongs = false }
        
        var allSongs: [Song] = []
        
        for album in albumsToPlay {
            do {
                let songs = try await loadSongsForAlbumWithOfflineSupport(album)
                allSongs.append(contentsOf: songs)
            } catch {
                print("⚠️ Failed to load songs for album \(album.name): \(error)")
            }
        }
        
        guard !allSongs.isEmpty else {
            print("❌ No songs found in any albums")
            return
        }
        
        let shuffledSongs = allSongs.shuffled()
        print("🎵 Starting shuffle play with \(shuffledSongs.count) songs (offline: \(isOfflineMode))")
        
        await playerVM.setPlaylist(
            shuffledSongs,
            startIndex: 0,
            albumId: nil
        )
        
        if !playerVM.isShuffling {
            playerVM.toggleShuffle()
        }
    }
    
    private func loadSongsForAlbumWithOfflineSupport(_ album: Album) async throws -> [Song] {
        // 1. If we're in offline mode or album is downloaded, prefer offline
        if isOfflineMode || downloadManager.isAlbumDownloaded(album.id) {
            let offlineSongs = await loadOfflineSongsForAlbum(album)
            if !offlineSongs.isEmpty {
                return offlineSongs
            }
        }
        
        // 2. Try online if available
        if networkMonitor.canLoadOnlineContent && !offlineManager.isOfflineMode {
            guard let service = navidromeVM.getService() else {
                throw URLError(.networkConnectionLost)
            }
            return try await service.getSongs(for: album.id)
        }
        
        // 3. Fallback to offline again
        return await loadOfflineSongsForAlbum(album)
    }
    
    private func loadOfflineSongsForAlbum(_ album: Album) async -> [Song] {
        // ✅ DIRECT CALL: Use NavidromeVM song cache
        if let cachedSongs = navidromeVM.albumSongs[album.id] {
            return cachedSongs
        }
        
        // ✅ DIRECT CALL: Use download manager
        guard let downloadedAlbum = downloadManager.downloadedAlbums.first(where: { $0.albumId == album.id }) else {
            return []
        }
        
        return downloadedAlbum.songIds.enumerated().map { index, songId in
            Song.createFromDownload(
                id: songId,
                title: "Track \(index + 1)",
                duration: nil,
                coverArt: album.id,
                artist: album.artist,
                album: album.name,
                albumId: album.id,
                track: index + 1,
                year: album.year,
                genre: album.genre,
                contentType: "audio/mpeg"
            )
        }
    }
}
