//
//  AlbumDetailView.swift
//  NavidromeClient
//
//  Created by Boris Eder on 04.09.25.
//


import SwiftUI

struct AlbumDetailView: View {
    let album: Album
    @State private var scrollOffset: CGFloat = 0

    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var downloadManager: DownloadManager

    @State private var loadedCover: UIImage?
    @State private var songs: [Song] = []
    @State private var showDeleteAlert = false
    @State private var miniPlayerVisible = false
    @State private var dominantColors: [Color] = [.yellow, .cyan]

    var body: some View {
        ZStack {

            // Album-spezifisches Cover als Hintergrund
           MusicBackgroundView(
                artist: nil,
                genre: nil,
                album: album
            )
                .environmentObject(navidromeVM)
            ScrollView {
                VStack(spacing: 32) {
                    AlbumHeaderView(
                        album: album,
                        cover: loadedCover,
                        songs: songs,
                        showDeleteAlert: $showDeleteAlert)
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
        .alert("Album löschen", isPresented: $showDeleteAlert) {
            Button("Abbrechen", role: .cancel) { }
            Button("Löschen", role: .destructive) {
                playerVM.deleteAlbum(albumId: album.id)
            }
        } message: {
            Text("Möchten Sie das heruntergeladene Album '\(album.name)' wirklich vom Gerät löschen?")
        }
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
    @Binding var showDeleteAlert: Bool
    
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    
    var body: some View {
        HStack {
            AlbumCoverView(cover: cover)
            AlbumInfoAndButtonsView(album: album, songs: songs, showDeleteAlert: $showDeleteAlert)
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
    @Binding var showDeleteAlert: Bool
    
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    
    var body: some View {
        VStack(alignment: .leading) {
            AlbumTextInfoView(album: album, songs: songs)
            
            if !songs.isEmpty {
                AlbumButtonsRowView(album: album, songs: songs, showDeleteAlert: $showDeleteAlert)
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
                .font(.title2)
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
    @Binding var showDeleteAlert: Bool
    
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            PlayButton(album: album, songs: songs)
            ShuffleButton(album: album, songs: songs)
            DownloadButton(album: album, songs: songs, showDeleteAlert: $showDeleteAlert)
            Spacer()
        }
        .padding(.top, 8)
    }
}

// MARK: - Play Button
struct PlayButton: View {
    let album: Album
    let songs: [Song]
    @EnvironmentObject var playerVM: PlayerViewModel
    
    var body: some View {
        Button {
            Task { await playerVM.setPlaylist(songs, startIndex: 0, albumId: album.id) }
        } label: {
            Image(systemName: "play.fill")
                .font(.title2)
                .foregroundColor(.white)
                .padding(12)
                .background(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                .clipShape(Circle())
        }
    }
}

// MARK: - Shuffle Button
struct ShuffleButton: View {
    let album: Album
    let songs: [Song]
    @EnvironmentObject var playerVM: PlayerViewModel
    
    var body: some View {
        Button {
            Task { await playerVM.setPlaylist(songs.shuffled(), startIndex: 0, albumId: album.id) }
        } label: {
            Image(systemName: playerVM.isShuffling ? "shuffle.circle.fill" : "shuffle")
                .font(.title2)
                .foregroundColor(.black.opacity(0.8))
        }
    }
}

// MARK: - Download Button
struct DownloadButton: View {
    let album: Album
    let songs: [Song]
    @Binding var showDeleteAlert: Bool
    
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    
    var body: some View {
        Button {
            if playerVM.isAlbumDownloading(album.id) {
                showDeleteAlert = true
            } else if !playerVM.isAlbumDownloading(album.id) {
                Task {
                    await navidromeVM.downloadAlbum(
                        songs: songs,
                        albumId: album.id,
                        playerVM: playerVM
                    )
                }
            }
        } label: {
            ZStack {
                if playerVM.isAlbumDownloading(album.id) {
                    Circle()
                        .stroke(Color.black.opacity(0.3), lineWidth: 2)
                        .frame(width: 28, height: 28)
                    Circle()
                        .trim(from: 0, to: playerVM.getDownloadProgress(albumId: album.id))
                        .stroke(Color.black.opacity(0.8), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 28, height: 28)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: playerVM.getDownloadProgress(albumId: album.id))
                    
                    Image(systemName: "arrow.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.black.opacity(0.8))
                } else if playerVM.isAlbumDownloaded(album.id) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.black)
                } else {
                    Image(systemName: "arrow.down.circle")
                        .font(.title2)
                        .foregroundStyle(.black.opacity(0.8))
                }
            }
        }
        .disabled(playerVM.isAlbumDownloading(album.id))
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
            ProgressView("Loading songs...")
                .frame(height: 100)
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
