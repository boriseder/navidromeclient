//
//  AlbumDetailView.swift - FIXED VERSION
//  NavidromeClient
//
//  ✅ FIXES:
//  - Removed bypass call to navidromeVM.loadCoverArt()
//  - Now uses ReactiveCoverArtService.loadAlbumCover() async method
//  - Maintains reactive UI updates
//

import SwiftUI

let buttonSize: CGFloat = 32 // gemeinsame Größe für alle Buttons

struct AlbumDetailView: View {
    let album: Album
    @State private var scrollOffset: CGFloat = 0

    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var coverArtService: ReactiveCoverArtService

    @State private var songs: [Song] = []
    @State private var miniPlayerVisible = false
    @State private var coverArt: UIImage? // ✅ FIX: Local state for cover art

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                AlbumHeaderView(
                    album: album,
                    cover: coverArt, // ✅ FIX: Use local state
                    songs: songs
                )
                
                AlbumSongsListView(
                    songs: songs,
                    album: album,
                    miniPlayerVisible: $miniPlayerVisible
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, miniPlayerVisible ? 90 : 50)
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
        // ✅ FIX: Load cover art through ReactiveCoverArtService async API
        // This replaces the old bypass: await navidromeVM.loadCoverArt(for: album.id, size: 400)
        coverArt = await coverArtService.loadAlbumCover(album, size: 400)
        
        // Load Songs (unchanged)
        songs = await navidromeVM.loadSongs(for: album.id)
    }
}

// MARK: - Album Header (unchanged - uses passed cover art)
struct AlbumHeaderView: View {
    let album: Album
    let cover: UIImage?
    let songs: [Song]
    
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var downloadManager: DownloadManager
    
    var body: some View {
        HStack(spacing: 20) {
            // Cover Art
            AlbumCoverView(cover: cover)
                .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 4)
                .scaleEffect(playerVM.currentAlbumId == album.id ? 1.02 : 1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: playerVM.currentAlbumId)
                .padding(.leading, 15)
            
            VStack(alignment: .leading, spacing: 8) {
                // Album Name + Artist
                VStack(alignment: .leading, spacing: 2) {
                    Text(album.name)
                        .font(.title3.weight(.bold))
                        .lineLimit(2)
                        .foregroundColor(.black)
                    
                    Text(album.artist)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.black.opacity(0.7))
                        .lineLimit(1)
                }
                
                // Metadata als Text-String
                Text(buildMetadataString())
                    .font(.caption)
                    .foregroundColor(.black.opacity(0.6))
                    .lineLimit(1)
                
                // Action Buttons
                HStack(spacing: 12) {
                    CompactPlayButton(album: album, songs: songs)
                    ShuffleButton(album: album, songs: songs)
                    DownloadButton(album: album, songs: songs, navidromeVM: navidromeVM, playerVM: playerVM, downloadManager: downloadManager)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 32)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
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

// MARK: - Kompakter Play Button (unchanged)
struct CompactPlayButton: View {
    let album: Album
    let songs: [Song]
    @EnvironmentObject var playerVM: PlayerViewModel

    var body: some View {
        Button {
            Task { await playerVM.setPlaylist(songs, startIndex: 0, albumId: album.id) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "play.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text("Play")
                    .font(.caption.weight(.semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.blue)
            )
        }
    }
}

// MARK: - Album Cover (unchanged)
struct AlbumCoverView: View {
    let cover: UIImage?
    
    var body: some View {
        Group {
            if let cover = cover {
                Image(uiImage: cover)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 140, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)
            } else {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 140, height: 140)
                    .overlay(
                        Image(systemName: "record.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.secondary)
                    )
            }
        }
    }
}

// MARK: - Shuffle Button (unchanged)
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
                .frame(width: buttonSize * 0.6, height: buttonSize * 0.6)
                .foregroundColor(.black.opacity(0.8))
        }
    }
}
