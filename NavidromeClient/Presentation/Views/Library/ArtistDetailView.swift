//
//  ArtistDetailView.swift - UPDATED for CoverArtManager
//  NavidromeClient
//
//  ✅ UPDATED: Uses unified CoverArtManager instead of ReactiveCoverArtService
//  ✅ SIMPLIFIED: Cleaner image loading integration
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
    // ✅ UPDATED: Uses CoverArtManager instead of ReactiveCoverArtService
    @EnvironmentObject var coverArtManager: CoverArtManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var downloadManager: DownloadManager
    
    @StateObject private var viewModel = ArtistDetailViewModel()

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
        .task {
            // ✅ UPDATED: Pass CoverArtManager instead of ReactiveCoverArtService
            await viewModel.loadContent(
                context: context,
                navidromeVM: navidromeVM,
                coverArtManager: coverArtManager,
                isOfflineMode: isOfflineMode,
                offlineManager: offlineManager
            )
        }
        .accountToolbar()
    }
       
    // MARK: - Header (Enhanced with DS)
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
            if let image = viewModel.artistImage {
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
            Text(viewModel.title(for: context))
                .font(Typography.title2)
                .lineLimit(2)
            
            albumCountView
            
            if !viewModel.albums.isEmpty {
                HStack {
                    shuffleButton
                }
            }
        }
    }
    
    private var albumCountView: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if !isOfflineMode {
                albumCountBadge(
                    count: viewModel.albums.count,
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
    
    private var shuffleButton: some View {
        Button(action: {
            Task {
                await shufflePlayAllAlbums()
            }
        }) {
            Label("Shuffle All", systemImage: "shuffle")
                .font(Typography.caption.weight(.medium))
                .foregroundStyle(TextColor.onDark)
                .padding(.horizontal, Padding.s)
                .padding(.vertical, Padding.xs)
                .background(
                    Capsule().fill(BrandColor.warning)
                )
                .miniShadow()
        }
        .disabled(viewModel.albums.isEmpty || viewModel.isLoading)
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
            if viewModel.isLoading {
                loadingView()
            } else {
                let albumsToShow = isOfflineMode ? availableOfflineAlbums : viewModel.albums
                
                if albumsToShow.isEmpty {
                    emptyStateView
                } else {
                    AlbumGridView(albums: albumsToShow)
                }
            }
        }
        .padding(.bottom, 120)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: Spacing.l) {
            Image(systemName: isOfflineMode ? "arrow.down.circle.slash" : "music.note.house")
                .font(.system(size: 60))
                .foregroundStyle(TextColor.secondary)
            
            VStack(spacing: Spacing.s) {
                Text(isOfflineMode ? "No Downloaded Albums" : "No Albums Found")
                    .font(Typography.title2)
                
                Text(isOfflineMode ?
                     "Download some albums to enjoy them offline" :
                     "This artist has no albums in your library")
                    .font(Typography.subheadline)
                    .foregroundStyle(TextColor.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if isOfflineMode && networkMonitor.isConnected {
                Button("Go Online") {
                    offlineManager.switchToOnlineMode()
                }
                .primaryButtonStyle()
            }
        }
        .padding(Padding.xl)
        .materialCardStyle()
    }
    
    @MainActor
    private func shufflePlayAllAlbums() async {
        let albumsToPlay = isOfflineMode ? availableOfflineAlbums : viewModel.albums
        guard !albumsToPlay.isEmpty else { return }
        
        viewModel.isLoadingSongs = true
        defer { viewModel.isLoadingSongs = false }
        
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
        if let cachedSongs = navidromeVM.albumSongs[album.id] {
            return cachedSongs
        }
        
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
