//
//  AlbumDetailView.swift - UPDATED for CoverArtManager
//  NavidromeClient
//
//  ✅ UPDATED: Uses unified CoverArtManager instead of ReactiveCoverArtService
//  ✅ SIMPLIFIED: Direct image loading without complex state management
//

import SwiftUI

struct AlbumDetailView: View {
    let album: Album
    @State private var scrollOffset: CGFloat = 0

    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var downloadManager: DownloadManager
    // ✅ UPDATED: Uses CoverArtManager instead of ReactiveCoverArtService
    @EnvironmentObject var coverArtManager: CoverArtManager
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
                
                // Enhanced: Offline Status Banner
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

    // ✅ UPDATED: Smart Album Data Loading with CoverArtManager
    @MainActor
    private func loadAlbumData() async {
        isOfflineAlbum = !networkMonitor.canLoadOnlineContent || offlineManager.isOfflineMode
        
        // ✅ UPDATED: Load cover art using CoverArtManager
        coverArt = await coverArtManager.loadAlbumImage(album: album, size: Int(Sizes.coverFull))
        
        // Load songs using NavidromeViewModel's smart loading method
        songs = await navidromeVM.loadSongs(for: album.id)
    }
}

// Enhanced: Offline Status Banner Component (unchanged)
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

// ✅ UPDATED: Album Header with CoverArtManager integration
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
                    
                    // Conditional: Only show download button if online
                    if !isOfflineAlbum {
                        DownloadButton(
                            album: album,
                            songs: songs,
                            navidromeVM: navidromeVM
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

// Compact Play Button (Enhanced with DS) - unchanged
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

// Album Cover (Enhanced with DS) - unchanged
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

// Shuffle Button (Enhanced with DS) - unchanged
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



