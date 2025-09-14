//
//  ArtistDetailView.swift - Enhanced with Design System
//  NavidromeClient
//
//  ✅ ENHANCED: Vollständige Anwendung des Design Systems
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
    @EnvironmentObject var coverArtService: ReactiveCoverArtService
    
    @StateObject private var viewModel = ArtistDetailViewModel()

    private var artist: Artist? {
        if case .artist(let a) = context { return a }
        return nil
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                headerView
                    .padding(.top, Spacing.s)
                
                albumsSection
                    .padding(.top, Spacing.m)
            }
        }
        .scrollIndicators(.hidden)
        .task {
            await viewModel.loadContent(context: context, navidromeVM: navidromeVM, coverArtService: coverArtService)
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
                    .frame(width: 80, height: 80) // Approx. DS applied - zwischen avatar und avatarLarge
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
            
            if !viewModel.albums.isEmpty {
                HStack {
                    albumCountBadge
                    shuffleButton
                }
            }
        }
    }
    
    private var albumCountBadge: some View {
        Text("\(viewModel.albums.count) Album\(viewModel.albums.count != 1 ? "s" : "")")
            .font(Typography.caption)
            .foregroundStyle(TextColor.secondary)
            .padding(.horizontal, Padding.s)
            .padding(.vertical, Padding.xs)
            .background(BackgroundColor.secondary, in: Capsule())
    }
    
    private var shuffleButton: some View {
        Button(action: {
            Task {
                await shufflePlayAllAlbums()
            }
        }) {
            Label("", systemImage: "shuffle")
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
    
    // MARK: - Albums Section (Enhanced with DS)
    private var albumsSection: some View {
        VStack(spacing: Spacing.l) {
            if viewModel.isLoading {
                loadingView()
            } else {
                AlbumGridView(albums: viewModel.albums)
            }
        }
        .padding(.bottom, 120) // Approx. DS applied - Sizes.miniPlayer + Spacing.xl
    }
    
    // MARK: - Shuffle Play Implementation
    
    @MainActor
    private func shufflePlayAllAlbums() async {
        guard !viewModel.albums.isEmpty else { return }
        
        // Show loading state
        viewModel.isLoadingSongs = true
        defer { viewModel.isLoadingSongs = false }
        
        var allSongs: [Song] = []
        
        // Load songs from all albums
        for album in viewModel.albums {
            do {
                let songs = try await loadSongsForAlbum(album.id)
                allSongs.append(contentsOf: songs)
            } catch {
                print("⚠️ Failed to load songs for album \(album.name): \(error)")
                // Continue with other albums even if one fails
            }
        }
        
        guard !allSongs.isEmpty else {
            print("❌ No songs found in any albums")
            return
        }
        
        // Shuffle the songs
        let shuffledSongs = allSongs.shuffled()
        
        print("🎵 Starting shuffle play with \(shuffledSongs.count) songs")
        
        // Start playback with shuffled playlist
        await playerVM.setPlaylist(
            shuffledSongs,
            startIndex: 0,
            albumId: nil // Mixed albums, so no single album ID
        )
        
        // Enable shuffle mode in player
        if !playerVM.isShuffling {
            playerVM.toggleShuffle()
        }
    }
    
    private func loadSongsForAlbum(_ albumId: String) async throws -> [Song] {
        guard let service = navidromeVM.getService() else {
            throw URLError(.networkConnectionLost)
        }
        
        return try await service.getSongs(for: albumId)
    }
}
