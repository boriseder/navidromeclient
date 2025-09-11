import SwiftUI

enum ArtistDetailContext {
    case artist(Artist)
    case genre(Genre)
}

struct ArtistDetailView: View {
    let context: ArtistDetailContext
    
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    
    @State private var viewModel = ArtistDetailViewModel()

    private var artist: Artist? {
        if case .artist(let a) = context { return a }
        return nil
    }
    
    var body: some View {
        ZStack {
            DynamicMusicBackground()
            ScrollView {
                LazyVStack(spacing: 0) {
                    headerView
                        .padding(.top, 8)
                    
                    albumsSection
                        .padding(.top, 16)
                }
            }
            .scrollIndicators(.hidden)
        }
        .task {
            await viewModel.loadContent(context: context, navidromeVM: navidromeVM)
        }
        .accountToolbar()
    }
       
    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 20) {
            artistAvatar
            artistInfo
            Spacer()
        }
        .padding(20)
        .padding(.horizontal, 20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var artistAvatar: some View {
        Group {
            if let image = viewModel.artistImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(.black.opacity(0.1))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "music.mic")
                            .font(.system(size: 30))
                            .foregroundStyle(.white)
                    )
            }
        }
        .shadow(radius: 6)
    }
    
    private var artistInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.title(for: context))
                .font(.title2)
                .fontWeight(.bold)
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
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.08), in: Capsule())
    }
    
    private var shuffleButton: some View {
        Button(action: {
            Task {
                await shufflePlayAllAlbums()
            }
        }) {
            Label("", systemImage: "shuffle")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(Color.orange)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 3)
        }
        .disabled(viewModel.albums.isEmpty || viewModel.isLoading)
    }
    
    // MARK: - Albums Section
    private var albumsSection: some View {
        VStack(spacing: 24) {
            if viewModel.isLoading {
                loadingView()
            } else {
                // GEÄNDERT: Verwende das neue AlbumGridView
                AlbumGridView(albums: viewModel.albums)
                    .environmentObject(navidromeVM)
                    .environmentObject(playerVM)
            }
        }
        .padding(.bottom, 120)
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

// MARK: - Enhanced ViewModel
@Observable
class ArtistDetailViewModel {
    var albums: [Album] = []
    var albumCovers: [String: UIImage] = [:]
    var artistImage: UIImage?
    var isLoading = false
    var isLoadingSongs = false // New: for shuffle play loading
    
    func title(for context: ArtistDetailContext) -> String {
        switch context {
        case .artist(let artist): return artist.name
        case .genre(let genre): return genre.value
        }
    }
    
    @MainActor
    func loadContent(context: ArtistDetailContext, navidromeVM: NavidromeViewModel) async {
        isLoading = true
        
        // Führe Tasks parallel aus
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadAlbums(context: context, navidromeVM: navidromeVM) }
            group.addTask { await self.loadArtistImage(context: context, navidromeVM: navidromeVM) }
        }
        
        isLoading = false
    }
    
    private func loadAlbums(context: ArtistDetailContext, navidromeVM: NavidromeViewModel) async {
        do {
            let loadedAlbums = try await navidromeVM.loadAlbums(context: context)
            await MainActor.run {
                self.albums = loadedAlbums
            }
        } catch {
            await MainActor.run {
                self.albums = []
            }
        }
    }
    
    private func loadArtistImage(context: ArtistDetailContext, navidromeVM: NavidromeViewModel) async {
        if case .artist(let artist) = context,
           let coverId = artist.coverArt {
            let image = await navidromeVM.loadCoverArt(for: coverId)
            await MainActor.run {
                self.artistImage = image
            }
        }
    }
    
    func loadAlbumCover(for album: Album, navidromeVM: NavidromeViewModel) async {
        guard albumCovers[album.id] == nil else { return }
        
        let cover = await navidromeVM.loadCoverArt(for: album.id)
        await MainActor.run {
            self.albumCovers[album.id] = cover
        }
    }
}
