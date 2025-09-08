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
            MusicBackgroundView(
                artist: artist,
                genre: nil,
                album: nil
            )
                .environmentObject(navidromeVM)
            contentView
        }
        
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadContent(context: context, navidromeVM: navidromeVM)
        }
        .accountToolbar()
    }
       
    // MARK: - Content
    private var contentView: some View {
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
    
    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 20) {
            artistAvatar
            artistInfo
            Spacer()
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 20)
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
                    .fill(Color(red: 0.8, green: 0.8, blue: 0.8))
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
                albumCountBadge
                shuffleButton
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
            // playerVM.shufflePlay(albums: viewModel.albums)
        }) {
            Label("Shuffle All", systemImage: "shuffle")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(viewModel.dominantColors.first ?? .blue)
                )
                .shadow(color: viewModel.dominantColors.first?.opacity(0.3) ?? .clear, radius: 4)
        }
    }
    
    // MARK: - Albums Section
    private var albumsSection: some View {
        VStack(spacing: 24) {
            if viewModel.isLoading {
                loadingView
            } else {
                albumsGrid
            }
        }
        .padding(.bottom, 120)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(viewModel.dominantColors.first)
            Text("Loading albums...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }
    
    private var albumsGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 2)

        return LazyVGrid(columns: columns, spacing: 20) {
            ForEach(viewModel.albums.indices, id: \.self) { index in
                let album = viewModel.albums[index]
                NavigationLink {
                    AlbumDetailView(album: album)
                        .environmentObject(navidromeVM)
                        .environmentObject(playerVM)
                } label: {
                    AlbumGridCard(
                        album: album,
                        cover: viewModel.albumCovers[album.id],
                        dominantColors: viewModel.dominantColors
                    )
                    .task {
                        await viewModel.loadAlbumCover(for: album, navidromeVM: navidromeVM)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - ViewModel
@Observable
class ArtistDetailViewModel {
    var albums: [Album] = []
    var albumCovers: [String: UIImage] = [:]
    var artistImage: UIImage?
    var dominantColors: [Color] = [.green, .red]
    var isLoading = false
    
    func title(for context: ArtistDetailContext) -> String {
        switch context {
        case .artist(let artist): return artist.name
        case .genre(let genre): return genre.value
        }
    }
    
    @MainActor
    func loadContent(context: ArtistDetailContext, navidromeVM: NavidromeViewModel) async {
        isLoading = true
        
        async let albumsTask = loadAlbums(context: context, navidromeVM: navidromeVM)
        async let imageTask = loadArtistImage(context: context, navidromeVM: navidromeVM)
        
        await albumsTask
        await imageTask
        
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
            let image = await navidromeVM.loadCoverArt(for: coverId) // <-- über VM
            await MainActor.run {
                self.artistImage = image
                // TODO: Extract dominant colors from image
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

// MARK: - Album Grid Card (Optimized)
struct AlbumGridCard: View {
    let album: Album
    let cover: UIImage?
    let dominantColors: [Color]

    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 12) {
            albumCover
            albumInfo
        }
        .padding(16)
        .frame(height: 240)
        .background(cardBackground)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(duration: 0.2, bounce: 0.3), value: isPressed)
        .onLongPressGesture(
            minimumDuration: 0.1,
            maximumDistance: 50,
            perform: hapticFeedback,
            onPressingChanged: { isPressed = $0 }
        )
    }
    
    private var albumCover: some View {
        Group {
            if let cover = cover {
                Image(uiImage: cover)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholderCover
            }
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(
            color: dominantColors.first?.opacity(0.2) ?? .black.opacity(0.1),
            radius: isPressed ? 8 : 12,
            x: 0, y: isPressed ? 4 : 8
        )
    }
    
    private var placeholderCover: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: dominantColors.map { $0.opacity(0.3) } + [Color.gray.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                ZStack {
                    Circle()
                        .stroke(dominantColors.first?.opacity(0.2) ?? .gray.opacity(0.2), lineWidth: 2)
                        .frame(width: 60, height: 60)
                    Image(systemName: "opticaldisc")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(dominantColors.first?.opacity(0.7) ?? .secondary)
                }
            )
    }
    
    private var albumInfo: some View {
        VStack(spacing: 4) {
            Text(album.name)
                .font(.headline.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundColor(Color(white: 0.2))
                .frame(height: 32)
            
            albumMetadata
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
    }
    
    private var albumMetadata: some View {
        HStack(spacing: 6) {
            if let year = album.year {
                metadataItem(icon: "calendar", text: "\(year)")
            }
            
            if let duration = album.duration {
                metadataItem(icon: "clock", text: formatDuration(duration))
            }

            
        }
        .frame(height: 16)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

    private func metadataItem(icon: String, text: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(Color(white: 0.2))
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(Color(white: 0.2))
        }
    }
    
    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .clear, dominantColors.first?.opacity(0.2) ?? .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }
    
    private func hapticFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}
