//
//  AlbumDetailHeaderView.swift
//  NavidromeClient
//
//  Verbesserte iOS-like album detail header mit korrekter Positionierung
//

import SwiftUI

struct AlbumHeaderView: View {
    let album: Album
    let songs: [Song]
    let isOfflineAlbum: Bool
    
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var downloadManager: DownloadManager

    var body: some View {
        ZStack {
            
            // MARK: - Background Layer
            backgroundImageLayer
            
            // MARK: - Content Layer
            contentLayer
        }
        .frame(height: 440)
        .ignoresSafeArea(edges: .top)
    }
    
    // MARK: - Background Image Layer
    
    @ViewBuilder
    private var backgroundImageLayer: some View {
        AlbumImageView(album: album, index: 0, size: UIScreen.main.bounds.width)
            .scaledToFill()
            .frame(
                width: UIScreen.main.bounds.width,
                height: 690 // Erhöhte Höhe für Safe Area
            )
            .blur(radius: 35)
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .black.opacity(0.5),
                                .black.opacity(0.2),
                                .black.opacity(0.1),
                                .black.opacity(0.85)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .offset(y: -125) // Verschiebt das Bild nach oben
            .ignoresSafeArea(edges: .top)
    }
    
    // MARK: - Content Layer
    
    @ViewBuilder
    private var contentLayer: some View {
        VStack(spacing: 0) {
            
            // Safe area spacer
            Color.clear.frame(height: 140)
            
            VStack(spacing: DSLayout.screenGap) {
                albumHeroContent
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, DSLayout.screenPadding)
            
            Spacer()
        }
    }
    
    // MARK: - Album Hero Content
    
    @ViewBuilder
    private var albumHeroContent: some View {
        VStack(spacing: 20) {
            
            // Large album cover - kleinere Größe
            AlbumImageView(album: album, index: 0, size: 200)
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
            
            // Album info mit besserer Textdarstellung
            VStack(spacing: 8) {
                Text(album.name)
                    .font(.system(size: 24, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.9), radius: 1, x: 0, y: 1)
                    .shadow(color: .black.opacity(0.7), radius: 4, x: 0, y: 2)
                    .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true) // Verhindert Abschneiden
                
                Text(album.artist)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.8), radius: 1, x: 0, y: 1)
                    .shadow(color: .black.opacity(0.5), radius: 6, x: 0, y: 3)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true) // Verhindert Abschneiden
                
                Text(buildMetadataString())
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.7), radius: 1, x: 0, y: 1)
                    .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
                    .multilineTextAlignment(.center)
            }
            
            // Modern floating action buttons
            actionButtonsFloating
        }

    }
    
    // MARK: - Floating Action Buttons
    
    @ViewBuilder
    private var actionButtonsFloating: some View {
        HStack(spacing: 12) {
            
            // Play Button - Primary action
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
                                    Color(red: 0.15, green: 0.7, blue: 0.15)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 4)
                        .shadow(color: .green.opacity(0.4), radius: 12, x: 0, y: 6)
                )
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
            }
            
            // Shuffle Button
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
                        .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 4)
                )
            }
            
            // Download Button
            if !isOfflineAlbum {
                Button {
                    Task { await downloadAlbum() }
                } label: {
                    Image(systemName: downloadManager.isAlbumDownloaded(album.id) ? "checkmark.circle.fill" : "arrow.down.circle")
                        .font(DSText.emphasized)
                        .foregroundStyle(.white)
                        .frame(width: DSLayout.largeIcon, height: DSLayout.largeIcon)
                        .background(
                            Circle()
                                .fill(.black.opacity(0.4))
                                .overlay(
                                    Circle()
                                        .stroke(.white.opacity(0.4), lineWidth: 1.5)
                                )
                                .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 4)
                        )
                }
            }
        }
    }
    
    // MARK: - Action Methods
    
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
        await playerVM.setPlaylist(shuffledSongs, startIndex: 0, albumId: album.id)
        if !playerVM.isShuffling {
            playerVM.toggleShuffle()
        }
    }
    
    private func downloadAlbum() async {
        if downloadManager.isAlbumDownloaded(album.id) {
            downloadManager.deleteAlbum(albumId: album.id)
        } else {
            print("Download album: \(album.name)")
        }
    }
    
    // MARK: - Helper Methods
    
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
