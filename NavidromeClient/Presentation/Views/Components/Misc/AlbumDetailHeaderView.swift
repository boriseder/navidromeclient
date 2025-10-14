//
//  AlbumDetailHeaderView.swift
//  NavidromeClient
//
//  FIXED: Download state observation and multiple download prevention
//

import SwiftUI

struct AlbumHeaderView: View {
    let album: Album
    let songs: [Song]
    let isOfflineAlbum: Bool

    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var downloadManager: DownloadManager

    @State private var isDownloaded = false
    @State private var isDownloading = false

    var body: some View {
        ZStack {
            backgroundImageLayer
            contentLayer
        }
        .frame(height: DSLayout.fullCover)
        .ignoresSafeArea(edges: .top)
        .onAppear {
            updateDownloadState()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .downloadCompleted)
        ) { notification in
            if let albumId = notification.object as? String, albumId == album.id
            {
                updateDownloadState()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .downloadDeleted))
        { notification in
            if let albumId = notification.object as? String, albumId == album.id
            {
                updateDownloadState()
            }
        }
        .onReceive(downloadManager.objectWillChange) { _ in
            updateDownloadState()
        }
    }

    private func updateDownloadState() {
        isDownloaded = downloadManager.isAlbumDownloaded(album.id)
        isDownloading = downloadManager.isAlbumDownloading(album.id)
    }

    @ViewBuilder
    private var backgroundImageLayer: some View {
        GeometryReader { geo in
            AlbumImageView(album: album, index: 0, context: .hero)
                .scaledToFit()
                .frame(
                    width: DSLayout.fullCover * 1.7,
                    height: DSLayout.fullCover * 1.7
                )
                .blur(radius: 20)
                .clipped() // Blur wird hier abgeschnitten
                .ignoresSafeArea(edges: .top)
                .offset(
                    x: -(DSLayout.fullCover * 1.7 - geo.size.width) / 2,
                    y: -70
                )
                .overlay(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: appConfig.userBackgroundStyle.textColor == .white
                                    ? [
                                        .black.opacity(0.5),
                                        .black.opacity(0.2),
                                        .black.opacity(0.1),
                                        .black.opacity(1),
                                      ]
                                    : [
                                        .white.opacity(0.5),
                                        .white.opacity(0.2),
                                        .white.opacity(0.1),
                                        .white.opacity(1),
                                      ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .offset(y: -70)
                        .ignoresSafeArea(edges: .top)
                )
        }
    }

    @ViewBuilder
    private var contentLayer: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: DSLayout.contentGap)

            VStack(spacing: DSLayout.screenGap) {
                albumHeroContent
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, DSLayout.screenPadding)

            Spacer()
        }
    }

    @ViewBuilder
    private var albumHeroContent: some View {
        VStack(spacing: 20) {
            AlbumImageView(album: album, index: 0, context: .detail)
                .clipShape(
                    RoundedRectangle(cornerRadius: 20)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            .white.opacity(0.15),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: .black.opacity(0.6),
                    radius: 20,
                    x: 0,
                    y: 10
                )
                .shadow(
                    color: .black.opacity(0.3),
                    radius: 40,
                    x: 0,
                    y: 20
                )

            VStack(spacing: 8) {
                Text(album.name)
                    .font(.system(size: 24, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.9), radius: 1, x: 0, y: 1)
                    .shadow(color: .black.opacity(0.7), radius: 4, x: 0, y: 2)
                    .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(album.artist)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.8), radius: 1, x: 0, y: 1)
                    .shadow(color: .black.opacity(0.5), radius: 6, x: 0, y: 3)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(buildMetadataString())
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.7), radius: 1, x: 0, y: 1)
                    .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
                    .multilineTextAlignment(.center)
            }

            actionButtonsFloating
        }
        .padding(.top, DSLayout.largeGap)
    }

    @ViewBuilder
    private var actionButtonsFloating: some View {
        HStack(spacing: 12) {
            Button {
                Task { await playAlbum() }
            } label: {
                HStack(spacing: DSLayout.contentGap) {
                    Image(systemName: "play.fill")
                        .font(DSText.emphasized)
                    Text("Play")
                        .font(DSText.emphasized)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, DSLayout.contentPadding)
                .padding(.vertical, DSLayout.elementPadding)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.2, green: 0.8, blue: 0.2),
                                    Color(red: 0.15, green: 0.7, blue: 0.15),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(
                            color: .black.opacity(0.6),
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                        .shadow(
                            color: .green.opacity(0.4),
                            radius: 12,
                            x: 0,
                            y: 6
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
            }

            Button {
                Task { await shuffleAlbum() }
            } label: {
                HStack(spacing: DSLayout.contentGap) {
                    Image(systemName: "shuffle")
                        .font(DSText.emphasized)
                    Text("Shuffle")
                        .font(DSText.emphasized)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, DSLayout.contentPadding)
                .padding(.vertical, DSLayout.elementPadding)
                .background(
                    Capsule()
                        .fill(.black.opacity(0.4))
                        .overlay(
                            Capsule()
                                .stroke(.white.opacity(0.4), lineWidth: 1.5)
                        )
                        .shadow(
                            color: .black.opacity(0.6),
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                )
            }

            Button {
                Task { await downloadAlbum() }
            } label: {
                downloadButtonIcon
                    .font(DSText.emphasized)
                    .foregroundStyle(.white)
                    .frame(
                        width: DSLayout.largeIcon,
                        height: DSLayout.largeIcon
                    )
                    .background(
                        Circle()
                            .fill(.black.opacity(0.4))
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.4), lineWidth: 1.5)
                            )
                            .shadow(
                                color: .black.opacity(0.6),
                                radius: 8,
                                x: 0,
                                y: 4
                            )
                    )
            }
            .disabled(isDownloading)
        }
    }

    @ViewBuilder
    private var downloadButtonIcon: some View {
        if isDownloading {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(0.8)
        } else if isDownloaded {
            Image(systemName: "checkmark.circle.fill")
        } else {
            Image(systemName: "arrow.down.circle")
        }
    }

    private func playAlbum() async {
        guard !songs.isEmpty else { return }
        await playerVM.setPlaylist(songs, startIndex: 0, albumId: album.id)

        if playerVM.isShuffling {
            playerVM.toggleShuffle()
        }
    }

    private func shuffleAlbum() async {
        guard !songs.isEmpty else { return }
        let shuffledSongs = songs.shuffled()
        await playerVM.setPlaylist(
            shuffledSongs,
            startIndex: 0,
            albumId: album.id
        )

        if !playerVM.isShuffling {
            playerVM.toggleShuffle()
        }
    }

    private func downloadAlbum() async {
        guard !isDownloading else {
            print("Download already in progress for album: \(album.id)")
            return
        }

        if isDownloaded {
            downloadManager.deleteAlbum(albumId: album.id)
        } else {
            print("Starting download for album: \(album.name)")
            isDownloading = true
            defer { isDownloading = false }

            await downloadManager.startDownload(album: album, songs: songs)
        }
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
