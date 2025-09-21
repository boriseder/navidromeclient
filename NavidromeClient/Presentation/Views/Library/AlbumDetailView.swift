//
//  AlbumDetailView.swift - CLEAN: Nur bestehende Komponenten
//  NavidromeClient
//
//   DRY: Nutzt nur existierende EmptyStateView, LibraryStatusHeader, etc.
//   SAUBER: Keine Code-Duplikation
//   KONSISTENT: Folgt bestehenden Patterns
//

import SwiftUI

struct AlbumDetailView: View {
    let album: Album
    @State private var scrollOffset: CGFloat = 0
    
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var coverArtManager: CoverArtManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    
    @State private var songs: [Song] = []
    @State private var coverArt: UIImage?
    @State private var isOfflineAlbum = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: DSLayout.screenGap) {
                AlbumHeaderView(
                    album: album,
                    cover: coverArt,
                    songs: songs,
                    isOfflineAlbum: isOfflineAlbum
                )
                
                //  BESTEHENDE KOMPONENTE: LibraryStatusHeader für Offline-Status
                if isOfflineAlbum || !networkMonitor.canLoadOnlineContent {
                    HStack {
                        if downloadManager.isAlbumDownloaded(album.id) {
                            OfflineStatusBadge(album: album)
                        } else {
                            NetworkStatusIndicator(showText: true)
                        }
                        Spacer()
                    }
                    .screenPadding()
                }
                
                if songs.isEmpty {
                    //  BESTEHENDE KOMPONENTE: EmptyStateView
                    EmptyStateView(
                        type: .songs,
                        customTitle: "No Songs Available",
                        customMessage: isOfflineAlbum ?
                            "This album is not downloaded for offline listening." :
                            "No songs found in this album."
                    )
                    .screenPadding()
                } else {
                    AlbumSongsListView(
                        songs: songs,
                        album: album
                    )
                }
            }
            .screenPadding()
            .padding(.bottom, DSLayout.miniPlayerHeight + DSLayout.contentGap)
            .navigationTitle(album.name)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadAlbumData()
            }
        }
    }
    
    @MainActor
    private func loadAlbumData() async {
        isOfflineAlbum = !networkMonitor.canLoadOnlineContent || offlineManager.isOfflineMode
        
        //  BESTEHENDE INTEGRATION: CoverArtManager
        coverArt = await coverArtManager.loadAlbumImage(album: album, size: Int(DSLayout.fullCover))
        
        //  BESTEHENDE INTEGRATION: NavidromeViewModel für Songs
        songs = await navidromeVM.loadSongs(for: album.id)
    }
}

// MARK: -  BESTEHENDE AlbumHeaderView (angepasst für bestehende Komponenten)

struct AlbumHeaderView: View {
    let album: Album
    let cover: UIImage?
    let songs: [Song]
    let isOfflineAlbum: Bool
    
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var downloadManager: DownloadManager
    
    var body: some View {
        HStack(spacing: DSLayout.sectionGap) {
            AlbumCoverView(cover: cover)
                .frame(width: DSLayout.cardCover, height: DSLayout.cardCover)
                .cardStyle()
            
            VStack(alignment: .leading, spacing: DSLayout.elementGap) {
                VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                    Text(album.name)
                        .font(DSText.sectionTitle)
                        .lineLimit(2)
                        .foregroundColor(DSColor.primary)
                    
                    Text(album.artist)
                        .font(DSText.emphasized)
                        .foregroundColor(DSColor.secondary)
                        .lineLimit(1)
                }
                
                Text(buildMetadataString())
                    .font(DSText.metadata)
                    .foregroundColor(DSColor.tertiary)
                    .lineLimit(1)
                
                HStack(spacing: DSLayout.elementGap) {
                    CompactPlayButton(album: album, songs: songs)
                    ShuffleButton(album: album, songs: songs)
                    
                    //  BESTEHENDE KOMPONENTE: DownloadButton
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
        .padding(.vertical, DSLayout.screenGap)
        .cardStyle()
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

// MARK: -  BESTEHENDE Komponenten (unverändert)


struct AlbumCoverView: View {
    let cover: UIImage?
    
    var body: some View {
        Group {
            if let cover = cover {
                Image(uiImage: cover)
                    .resizable()
                    .scaledToFill()
                    .frame(width: DSLayout.cardCover, height: DSLayout.cardCover)
                    .clipShape(RoundedRectangle(cornerRadius: DSCorners.tight))
            } else {
                RoundedRectangle(cornerRadius: DSCorners.tight)
                    .fill(DSColor.surface)
                    .frame(width: DSLayout.cardCover, height: DSLayout.cardCover)
                    .overlay(
                        Image(systemName: "record.circle.fill")
                            .font(.system(size: DSLayout.largeIcon))
                            .foregroundStyle(DSColor.tertiary)
                    )

            }
        }
    }
}

