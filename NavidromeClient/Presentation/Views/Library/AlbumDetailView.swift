//
//
//  AlbumDetailView.swift - Enhanced with Offline Support
//

import SwiftUI

struct AlbumDetailView: View {
    let album: Album
    @State private var scrollOffset: CGFloat = 0

    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var coverArtService: ReactiveCoverArtService
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager

    @State private var songs: [Song] = []
    @State private var miniPlayerVisible = false
    @State private var coverArt: UIImage?
    @State private var isOfflineAlbum = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                AlbumHeaderView(
                    album: album,
                    cover: coverArt,
                    songs: songs,
                    isOfflineAlbum: isOfflineAlbum
                )
                
                // ✅ NEW: Offline Status Banner
                if isOfflineAlbum || !networkMonitor.canLoadOnlineContent {
                    OfflineStatusBanner(
                        isDownloaded: downloadManager.isAlbumDownloaded(album.id),
                        isOnline: networkMonitor.canLoadOnlineContent
                    )
                }
                
                AlbumSongsListView(
                    songs: songs,
                    album: album,
                    miniPlayerVisible: $miniPlayerVisible
                )
            }
            .screenPadding()
            .padding(.bottom, miniPlayerVisible ? Sizes.miniPlayer : 50)
            .navigationTitle(album.name)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadAlbumData()
            }
            .accountToolbar()
        }
    }

    // ✅ ENHANCED: Smart Album Data Loading with Offline Support
    @MainActor
    private func loadAlbumData() async {
        // Check if this is an offline scenario
        isOfflineAlbum = !networkMonitor.canLoadOnlineContent || offlineManager.isOfflineMode
        
        // Load cover art
        coverArt = await coverArtService.loadAlbumCover(album, size: Int(Sizes.coverFull))
        
        // ✅ NEW: Smart Song Loading with Offline Support
        songs = await loadSongsWithOfflineSupport()
    }
    
    // ✅ NEW: Unified Song Loading Logic
    private func loadSongsWithOfflineSupport() async -> [Song] {
        // 1. Check if album is downloaded (priority)
        if downloadManager.isAlbumDownloaded(album.id) {
            return await loadOfflineSongs()
        }
        
        // 2. Try online if available
        if networkMonitor.canLoadOnlineContent && !offlineManager.isOfflineMode {
            let onlineSongs = await navidromeVM.loadSongs(for: album.id)
            if !onlineSongs.isEmpty {
                return onlineSongs
            }
        }
        
        // 3. Fallback to offline if online failed
        return await loadOfflineSongs()
    }
    
    // ✅ NEW: Load Songs from Downloaded Files
    private func loadOfflineSongs() async -> [Song] {
        guard let downloadedAlbum = downloadManager.downloadedAlbums.first(where: { $0.albumId == album.id }) else {
            print("⚠️ Album \(album.id) not found in downloads")
            return []
        }
        
        // Get cached album metadata
        guard let cachedAlbum = AlbumMetadataCache.shared.getAlbum(id: album.id) else {
            print("⚠️ Album metadata not found for \(album.id)")
            return []
        }
        
        // Try to get songs from NavidromeVM cache first
        let cachedSongs = navidromeVM.albumSongs[album.id] ?? []
        if !cachedSongs.isEmpty {
            return cachedSongs.filter { downloadedAlbum.songIds.contains($0.id) }
        }
        
        // ✅ FALLBACK: Create minimal Song objects from downloaded files
        return downloadedAlbum.songIds.enumerated().map { index, songId in
            Song.createFromDownload(
                id: songId,
                title: "Track \(index + 1)", // Fallback title
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

// ✅ NEW: Offline Status Banner Component
struct OfflineStatusBanner: View {
    let isDownloaded: Bool
    let isOnline: Bool
    
    var body: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: bannerIcon)
                .foregroundStyle(bannerColor)
            
            Text(bannerText)
                .font(Typography.caption)
                .foregroundStyle(bannerColor)
            
            Spacer()
        }
        .listItemPadding()
        .background(bannerColor.opacity(0.1), in: RoundedRectangle(cornerRadius: Radius.s))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.s)
                .stroke(bannerColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var bannerIcon: String {
        if isDownloaded {
            return "checkmark.circle.fill"
        } else if !isOnline {
            return "wifi.slash"
        } else {
            return "icloud.slash"
        }
    }
    
    private var bannerColor: Color {
        if isDownloaded {
            return BrandColor.success
        } else if !isOnline {
            return BrandColor.error
        } else {
            return BrandColor.warning
        }
    }
    
    private var bannerText: String {
        if isDownloaded {
            return "Available offline"
        } else if !isOnline {
            return "No connection - offline content only"
        } else {
            return "Not downloaded - streaming only"
        }
    }
}

// ✅ ENHANCED: Album Header with Offline Support
struct AlbumHeaderView: View {
    let album: Album
    let cover: UIImage?
    let songs: [Song]
    let isOfflineAlbum: Bool
    
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var downloadManager: DownloadManager
    
    var body: some View {
        HStack(spacing: Spacing.l) {
            AlbumCoverView(cover: cover)
                .frame(width: Sizes.card, height: Sizes.card)
                .cardShadow()
                .scaleEffect(playerVM.currentAlbumId == album.id ? 1.02 : 1.0)
                .animation(Animations.spring, value: playerVM.currentAlbumId)
                .padding(.leading, 15)
            
            VStack(alignment: .leading, spacing: Spacing.s) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(album.name)
                        .font(Typography.title3)
                        .lineLimit(2)
                        .foregroundColor(TextColor.primary)
                    
                    Text(album.artist)
                        .font(Typography.bodyEmphasized)
                        .foregroundColor(TextColor.secondary)
                        .lineLimit(1)
                }
                
                Text(buildMetadataString())
                    .font(Typography.caption)
                    .foregroundColor(TextColor.tertiary)
                    .lineLimit(1)
                
                HStack(spacing: Spacing.s) {
                    CompactPlayButton(album: album, songs: songs)
                    ShuffleButton(album: album, songs: songs)
                    
                    // ✅ CONDITIONAL: Only show download button if online
                    if !isOfflineAlbum {
                        DownloadButton(
                            album: album,
                            songs: songs,
                            navidromeVM: navidromeVM,
                            playerVM: playerVM,
                            downloadManager: downloadManager
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Spacing.xl)
        .materialCardStyle()
    }
    
    private func buildMetadataString() -> String {
        var parts: [String] = []
        
        if !songs.isEmpty {
            parts.append("\(songs.count) Song\(songs.count != 1 ? "s" : "")")
        }
        if let duration = album.duration {
            parts.append(formatDuration(duration))
        }
        if let year = album.year {
            parts.append("\(year)")
        }
        
        return parts.joined(separator: " • ")
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remaining = seconds % 60
        return String(format: "%d:%02d", minutes, remaining)
    }
}
// ✅ NEW: Offline Status Banner Component

// MARK: - Kompakter Play Button (Enhanced with DS)
struct CompactPlayButton: View {
    let album: Album
    let songs: [Song]
    @EnvironmentObject var playerVM: PlayerViewModel

    var body: some View {
        Button {
            Task { await playerVM.setPlaylist(songs, startIndex: 0, albumId: album.id) }
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "play.fill")
                    .font(.system(size: Sizes.iconSmall, weight: .semibold))
                Text("Play")
                    .font(Typography.caption.weight(.semibold))
            }
            .foregroundColor(TextColor.onDark)
            .padding(.horizontal, Padding.s)
            .padding(.vertical, Padding.xs)
            .background(
                Capsule()
                    .fill(BrandColor.primary)
            )
        }
    }
}

// MARK: - Album Cover (Enhanced with DS)
struct AlbumCoverView: View {
    let cover: UIImage?
    
    var body: some View {
        Group {
            if let cover = cover {
                Image(uiImage: cover)
                    .resizable()
                    .scaledToFill()
                    .frame(width: Sizes.card, height: Sizes.card)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.xs))
                    .cardShadow()
            } else {
                RoundedRectangle(cornerRadius: Radius.xs)
                    .fill(BackgroundColor.secondary)
                    .frame(width: Sizes.card, height: Sizes.card)
                    .overlay(
                        Image(systemName: "record.circle.fill")
                            .font(.system(size: Sizes.iconLarge))
                            .foregroundStyle(TextColor.tertiary)
                    )
            }
        }
    }
}

// MARK: - Shuffle Button (Enhanced with DS)
struct ShuffleButton: View {
    let album: Album
    let songs: [Song]
    @EnvironmentObject var playerVM: PlayerViewModel

    var body: some View {
        Button {
            Task { await playerVM.setPlaylist(songs.shuffled(), startIndex: 0, albumId: album.id) }
        } label: {
            Image(systemName: playerVM.isShuffling ? "shuffle.circle.fill" : "shuffle")
                .resizable()
                .scaledToFit()
                .frame(width: Sizes.icon, height: Sizes.icon)
                .foregroundColor(TextColor.secondary)
        }
    }
}
