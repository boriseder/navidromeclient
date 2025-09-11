//
//  AlbumDetailView.swift
//  NavidromeClient
//
//  Created by Boris Eder on 04.09.25.
//


import SwiftUI

let buttonSize: CGFloat = 32 // gemeinsame Größe für alle Buttons

struct AlbumDetailView: View {
    let album: Album
    @State private var scrollOffset: CGFloat = 0

    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var downloadManager: DownloadManager

    @State private var loadedCover: UIImage?
    @State private var songs: [Song] = []
    @State private var miniPlayerVisible = false

    var body: some View {
        ZStack {
            DynamicMusicBackground()
            ScrollView {
                VStack(spacing: 32) {
                    AlbumHeaderView(
                        album: album,
                        cover: loadedCover,
                        songs: songs
                    )
                    .environmentObject(playerVM)
                    .environmentObject(navidromeVM)
                    
                    AlbumSongsListView(
                        songs: songs,
                        album: album,
                        miniPlayerVisible: $miniPlayerVisible
                    )
                    .environmentObject(playerVM)
                    .environmentObject(navidromeVM)
                
                }
                .padding(.horizontal, 16)
                .padding(.bottom, miniPlayerVisible ? 90 : 50)
        }
    }
        
        .navigationTitle(album.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadAlbumData()
        }
        .accountToolbar()
    }

    @MainActor
    private func loadAlbumData() async {
        loadedCover = await navidromeVM.loadCoverArt(for: album.id)
        songs = await navidromeVM.loadSongs(for: album.id)
    }
}


// MARK: - Album Header
struct AlbumHeaderView: View {
    let album: Album
    let cover: UIImage?
    let songs: [Song]
    
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    
    var body: some View {
        HStack {
            AlbumCoverView(cover: cover)
            AlbumInfoAndButtonsView(
                album: album,
                songs: songs
            )
        }
        .padding(12)
    }
}

// MARK: - Album Cover
struct AlbumCoverView: View {
    let cover: UIImage?
    
    var body: some View {
        Group {
            if let cover = cover {
                Image(uiImage: cover)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 160, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 140, height: 140)
                    .overlay(
                        Image(systemName: "record.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                    )
            }
        }
    }
}

// MARK: - Album Info + Buttons
struct AlbumInfoAndButtonsView: View {
    let album: Album
    let songs: [Song]
    
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    
    var body: some View {
        VStack(alignment: .leading) {
            AlbumTextInfoView(album: album, songs: songs)
            
            if !songs.isEmpty {
                AlbumButtonsRowView(album: album, songs: songs
                )
            }
        }
        .frame(maxWidth: 180)
        .padding(.leading, 10)
    }
}

// MARK: - Album Text Info
struct AlbumTextInfoView: View {
    let album: Album
    let songs: [Song]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(album.name)
                .font(.headline)
                .fontWeight(.bold)
                .lineLimit(2)
                .foregroundColor(Color.black)
            
            VStack(alignment: .leading, spacing: 6) {
                // Array von Tuples: (SystemImage, Text-Value)
                let items: [(String, String)] = [
                    ("music.note", songs.isEmpty ? "" : "\(songs.count) " + (songs.count == 1 ? "Song" : "Songs")),
                    ("clock", album.duration.map { "\($0 / 60).\($0 % 60)" } ?? ""),
                    ("calendar", album.year.map { "\($0)" } ?? "")
                ]
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    if !item.1.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: item.0)
                            Text(item.1)
                        }
                        
                        /*
                        // Trennzeichen, außer nach dem letzten Element
                        if index < items.count - 1 {
                            Text("•")
                                .foregroundStyle(.secondary)
                        }
                         */
                    }
                }
            }
            .font(.caption)
            .foregroundColor(Color.black)
            .padding(.top, 20)
        }
    }
}

// MARK: - Album Buttons Row
struct AlbumButtonsRowView: View {
    let album: Album
    let songs: [Song]
    
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            PlayButton(album: album, songs: songs)
            ShuffleButton(album: album, songs: songs)
            DownloadButton(album: album, songs: songs
            )
            Spacer()
        }
        .padding(.top, 8)
    }
}

struct PlayButton: View {
    let album: Album
    let songs: [Song]
    @EnvironmentObject var playerVM: PlayerViewModel

    var body: some View {
        Button {
            Task { await playerVM.setPlaylist(songs, startIndex: 0, albumId: album.id) }
        } label: {
            ZStack {
                /*
                Circle()
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                    .frame(width: buttonSize, height: buttonSize)
                 */
                Image(systemName: "play.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonSize * 0.6, height: buttonSize * 0.6)
                    .foregroundColor(.purple)
            }
        }
    }
}

struct ShuffleButton: View {
    let album: Album
    let songs: [Song]
    @EnvironmentObject var playerVM: PlayerViewModel

    var body: some View {
        Button {
            Task { await playerVM.setPlaylist(songs.shuffled(), startIndex: 0, albumId: album.id) }
        } label: {
            ZStack {
                /*
                Circle()
                    .fill(Color.white)
                    .frame(width: buttonSize, height: buttonSize)
                    .shadow(radius: 2)
*/
                Image(systemName: playerVM.isShuffling ? "shuffle.circle.fill" : "shuffle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonSize * 0.6, height: buttonSize * 0.6)
                    .foregroundColor(.black.opacity(0.8))
            }
        }
    }
}

struct DownloadButton: View {
    let album: Album
    let songs: [Song]
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel

    var isDownloading: Bool { downloadManager.isAlbumDownloading(album.id) }
    var isDownloaded: Bool { downloadManager.isAlbumDownloaded(album.id) }
    var progress: Double { downloadManager.downloadProgress[album.id] ?? 0 }

    var body: some View {
        Button {
            if isDownloading { return }
            else if isDownloaded { downloadManager.deleteAlbum(albumId: album.id) }
            else {
                Task { await navidromeVM.downloadAlbum(songs: songs, albumId: album.id, playerVM: playerVM) }
            }
        } label: {
            ZStack {
                /*
                Circle()
                    .fill(Color.white)
                    .frame(width: buttonSize, height: buttonSize)
                    .shadow(radius: 2)
*/
                if isDownloading {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.black.opacity(0.8), lineWidth: 2)
                        .rotationEffect(.degrees(-90))
                        .frame(width: buttonSize, height: buttonSize)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }

                Image(systemName: isDownloading ? "arrow.down" : (isDownloaded ? "checkmark.circle.fill" : "arrow.down.circle"))
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonSize * 0.6, height: buttonSize * 0.6)
                    .foregroundColor(.black.opacity(isDownloaded ? 1 : 0.8))
            }
        }
        .disabled(isDownloading)
    }
}





// MARK: - Album Songs List
struct AlbumSongsListView: View {
    let songs: [Song]
    let album: Album
    @Binding var miniPlayerVisible: Bool
    
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    
    var body: some View {
        if songs.isEmpty {
            loadingView()
        } else {
            VStack(spacing: 5) {
                ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                    SongRow(
                        song: song,
                        index: index + 1,
                        isPlaying: playerVM.currentSong?.id == song.id && playerVM.isPlaying,
                        action: {
                            Task { await playerVM.setPlaylist(songs, startIndex: index, albumId: album.id) }
                        },
                        onLongPressOrSwipe: {
                            playerVM.stop()
                            miniPlayerVisible = false
                        }
                    )
                }
            }
        }
    }
}
