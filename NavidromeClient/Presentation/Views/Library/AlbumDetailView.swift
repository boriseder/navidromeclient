//
//  AlbumDetailView.swift - Enhanced with Design System
//  NavidromeClient
//
//  ✅ ENHANCED: Vollständige Anwendung des Design Systems
//

import SwiftUI

struct AlbumDetailView: View {
    let album: Album
    @State private var scrollOffset: CGFloat = 0

    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var coverArtService: ReactiveCoverArtService

    @State private var songs: [Song] = []
    @State private var miniPlayerVisible = false
    @State private var coverArt: UIImage?

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                AlbumHeaderView(
                    album: album,
                    cover: coverArt,
                    songs: songs
                )
                
                AlbumSongsListView(
                    songs: songs,
                    album: album,
                    miniPlayerVisible: $miniPlayerVisible
                )
            }
            .screenPadding()
            .padding(.bottom, miniPlayerVisible ? Sizes.miniPlayer : 50) // Approx. DS applied
            .navigationTitle(album.name)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadAlbumData()
            }
            .accountToolbar()
        }
    }

    @MainActor
    private func loadAlbumData() async {
        // Load cover art through ReactiveCoverArtService async API
        coverArt = await coverArtService.loadAlbumCover(album, size: Int(Sizes.coverFull))
        
        // Load Songs
        songs = await navidromeVM.loadSongs(for: album.id)
    }
}

// MARK: - Album Header (Enhanced with DS)
struct AlbumHeaderView: View {
    let album: Album
    let cover: UIImage?
    let songs: [Song]
    
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var downloadManager: DownloadManager
    
    var body: some View {
        HStack(spacing: Spacing.l) {
            // Cover Art
            AlbumCoverView(cover: cover)
                .frame(width: Sizes.card, height: Sizes.card)
                .cardShadow()
                .scaleEffect(playerVM.currentAlbumId == album.id ? 1.02 : 1.0)
                .animation(Animations.spring, value: playerVM.currentAlbumId)
                .padding(.leading, 15) // Approx. DS applied - sollte durch screenPadding() ersetzt werden
            
            VStack(alignment: .leading, spacing: Spacing.s) {
                // Album Name + Artist
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
                
                // Metadata als Text-String
                Text(buildMetadataString())
                    .font(Typography.caption)
                    .foregroundColor(TextColor.tertiary)
                    .lineLimit(1)
                
                // Action Buttons
                HStack(spacing: Spacing.s) {
                    CompactPlayButton(album: album, songs: songs)
                    ShuffleButton(album: album, songs: songs)
                    DownloadButton(album: album, songs: songs, navidromeVM: navidromeVM, playerVM: playerVM, downloadManager: downloadManager)
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
