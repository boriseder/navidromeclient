import SwiftUI

// MARK: - Artist Row with Cover Art (ArtistsView Style)
struct SearchResultArtistRow: View {
    let artist: Artist
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @State private var artistImage: UIImage?
    @State private var isLoadingImage = false
    
    var body: some View {
        NavigationLink(destination: ArtistDetailView(context: .artist(artist))) {
            HStack(spacing: 16) {
                ArtistImageView(
                    image: artistImage,
                    isLoading: isLoadingImage
                )
                
                ArtistInfoView(artist: artist)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .task {
            await loadArtistImage()
        }
    }
    
    private func loadArtistImage() async {
        guard let coverId = artist.coverArt, !isLoadingImage else { return }
        isLoadingImage = true
        
        // Use NavidromeVM instead of direct service - ensures caching
        artistImage = await navidromeVM.loadCoverArt(for: coverId)
        
        isLoadingImage = false
    }
}

// MARK: - Album Row with Cover Art (ArtistsView Style)
struct SearchResultAlbumRow: View {
    let album: Album
    
    // REAKTIVER Cover Art Service
    @EnvironmentObject var coverArtService: ReactiveCoverArtService
    
    var body: some View {
        NavigationLink(destination: AlbumDetailView(album: album)) {
            HStack(spacing: 16) {
                // REAKTIVES Album Cover
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 70, height: 70)
                        .blur(radius: 3)
                    
                    Group {
                        if let image = coverArtService.coverImage(for: album, size: 120) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        colors: [.orange, .pink.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: "record.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundStyle(.white.opacity(0.9))
                                )
                                .onAppear {
                                    // FIRE-AND-FORGET Request
                                    coverArtService.requestImage(for: album.id, size: 120)
                                }
                        }
                    }
                }
                
                AlbumInfoView(album: album)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Song Row (ArtistsView Style)
struct SearchResultSongRow: View {
    let song: Song
    let index: Int
    let isPlaying: Bool
    let action: () -> Void
    
    // REAKTIVER Cover Art Service
    @EnvironmentObject var coverArtService: ReactiveCoverArtService
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // REAKTIVES Song Cover
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(isPlaying ? 0.2 : 0.1))
                        .frame(width: 60, height: 60)
                        .blur(radius: 3)
                    
                    Group {
                        if let albumId = song.albumId,
                           let image = coverArtService.image(for: albumId, size: 100) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    // Playing indicator overlay
                                    isPlaying ?
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.blue.opacity(0.3))
                                        .overlay(
                                            Image(systemName: "speaker.wave.2.fill")
                                                .font(.caption)
                                                .foregroundStyle(.blue)
                                        ) : nil
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [.green, .blue.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.white.opacity(0.9))
                                )
                                .onAppear {
                                    // FIRE-AND-FORGET Request
                                    if let albumId = song.albumId {
                                        coverArtService.requestImage(for: albumId, size: 100)
                                    }
                                }
                        }
                    }
                }
                
                SongInfoView(song: song, isPlaying: isPlaying)
                
                Spacer()
                
                SongDurationView(duration: song.duration)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Artist Components (Enhanced)
struct ArtistImageView: View {
    let image: UIImage?
    let isLoading: Bool
    
    var body: some View {
        ZStack {
            // Subtle glow background
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 70, height: 70)
                .blur(radius: 3)
            
            // Main avatar
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                } else if isLoading {
                    Circle()
                        .fill(.regularMaterial)
                        .frame(width: 60, height: 60)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.blue)
                        )
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "music.mic")
                                .font(.system(size: 24))
                                .foregroundStyle(.white.opacity(0.9))
                        )
                }
            }
        }
    }
}

struct ArtistInfoView: View {
    let artist: Artist
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(artist.name)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            
            HStack(spacing: 8) {
                Image(systemName: "music.mic")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if let count = artist.albumCount {
                    Text("\(count) Album\(count != 1 ? "s" : "")")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Album Components (Enhanced)
struct AlbumImageView: View {
    let albumId: String
    @Binding var albumCovers: [String: UIImage]
    let isLoading: Bool
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    
    var body: some View {
        ZStack {
            // Subtle glow background
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
                .frame(width: 70, height: 70)
                .blur(radius: 3)
            
            // Album cover or placeholder
            Group {
                if let image = albumCovers[albumId] {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else if isLoading {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.regularMaterial)
                        .frame(width: 60, height: 60)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.blue)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [.orange, .pink.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "record.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.white.opacity(0.9))
                        )
                        .task {
                            if albumCovers[albumId] == nil {
                                // Use NavidromeVM instead of direct service - ensures caching
                                if let loadedImage = await navidromeVM.loadCoverArt(for: albumId, size: 120) {
                                    albumCovers[albumId] = loadedImage
                                }
                            }
                        }
                }
            }
        }
    }
}

struct AlbumInfoView: View {
    let album: Album
    
    private var formattedYear: String {
        guard let year = album.year else { return "" }
        return String(year)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(album.name)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            
            Text(album.artist)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            
            HStack(spacing: 8) {
                if !formattedYear.isEmpty {
                    MetadataItem(
                        icon: "calendar",
                        text: formattedYear,
                        fontSize: .caption
                    )
                }
                
                if !formattedYear.isEmpty && album.songCount ?? 0 > 0 {
                    MetadataSeparator(fontSize: .caption)
                }
                
                if album.songCount ?? 0 > 0 {
                    MetadataItem(
                        icon: "music.note",
                        text: "\(album.songCount ?? 0) Songs",
                        fontSize: .caption
                    )
                }
            }
        }
    }
}

// MARK: - Song Components (Enhanced)
struct SongImageView: View {
    let song: Song
    @Binding var albumCovers: [String: UIImage]
    let isLoading: Bool
    let isPlaying: Bool
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    
    var body: some View {
        ZStack {
            // Subtle glow background
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(isPlaying ? 0.2 : 0.1))
                .frame(width: 60, height: 60)
                .blur(radius: 3)
            
            // Song cover or placeholder
            Group {
                if let albumId = song.albumId, let image = albumCovers[albumId] {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            // Playing indicator overlay
                            isPlaying ?
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.blue.opacity(0.3))
                                .overlay(
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                ) : nil
                        )
                } else if isLoading {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.regularMaterial)
                        .frame(width: 50, height: 50)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.blue)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [.green, .blue.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 20))
                                .foregroundStyle(.white.opacity(0.9))
                        )
                        .task {
                            if let albumId = song.albumId, albumCovers[albumId] == nil {
                                // Use NavidromeVM instead of direct service - ensures caching
                                if let loadedImage = await navidromeVM.loadCoverArt(for: albumId, size: 100) {
                                    albumCovers[albumId] = loadedImage
                                }
                            }
                        }
                }
            }
        }
    }
}

struct SongInfoView: View {
    let song: Song
    let isPlaying: Bool
    
    private var formattedYear: String {
        guard let year = song.year else { return "" }
        return String(year)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(song.title)
                .font(.headline.weight(.medium))
                .foregroundStyle(isPlaying ? .blue : .primary)
                .lineLimit(1)
            
            Text(song.artist ?? "Unbekannter Künstler")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            
            HStack(spacing: 8) {
                if !song.album.isNilOrEmpty {
                    MetadataItem(
                        icon: "record.circle.fill",
                        text: song.album!,
                        fontSize: .caption
                    )
                }
                
                if !song.album.isNilOrEmpty && !formattedYear.isEmpty {
                    MetadataSeparator(fontSize: .caption)
                }
                
                if !formattedYear.isEmpty {
                    MetadataItem(
                        icon: "calendar",
                        text: formattedYear,
                        fontSize: .caption
                    )
                }
            }
        }
    }
}

struct SongDurationView: View {
    let duration: Int?
    
    private var formattedDuration: String {
        let duration = duration ?? 0
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(formattedDuration)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            
            // Small music note indicator
            Image(systemName: "music.note")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Shared Components
struct MetadataItem: View {
    let icon: String
    let text: String
    let fontSize: Font
    
    init(icon: String, text: String, fontSize: Font = .caption) {
        self.icon = icon
        self.text = text
        self.fontSize = fontSize
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(fontSize)
                .foregroundStyle(.secondary)
            
            Text(text)
                .font(fontSize.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

struct MetadataSeparator: View {
    let fontSize: Font
    
    init(fontSize: Font = .caption) {
        self.fontSize = fontSize
    }
    
    var body: some View {
        Text("•")
            .font(fontSize)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Helper Extension
extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        return self?.isEmpty ?? true
    }
}
