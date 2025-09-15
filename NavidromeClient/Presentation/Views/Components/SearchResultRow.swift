//
//  SearchResultRow.swift - CLEAN Async Implementation
//  NavidromeClient
//
//  ✅ CORRECT: No UI blocking, proper async patterns, no ImageType usage
//

import SwiftUI

// MARK: - Artist Row (Clean Async)
struct SearchResultArtistRow: View {
    let artist: Artist
    @EnvironmentObject var coverArtService: ReactiveCoverArtService
    
    var body: some View {
        NavigationLink(destination: ArtistDetailView(context: .artist(artist))) {
            HStack(spacing: Spacing.m) {
                ArtistImageView(artist: artist)
                ArtistInfoView(artist: artist)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(TextColor.tertiary)
            }
            .listItemPadding()
            .materialCardStyle()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Album Row (Clean Async)
struct SearchResultAlbumRow: View {
    let album: Album
    @EnvironmentObject var coverArtService: ReactiveCoverArtService
    
    var body: some View {
        NavigationLink(destination: AlbumDetailView(album: album)) {
            HStack(spacing: Spacing.m) {
                AlbumImageView(album: album)
                AlbumInfoView(album: album)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(TextColor.tertiary)
            }
            .listItemPadding()
            .materialCardStyle()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Song Row (Clean Async)
struct SearchResultSongRow: View {
    let song: Song
    let index: Int
    let isPlaying: Bool
    let action: () -> Void
    
    @EnvironmentObject var coverArtService: ReactiveCoverArtService
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.m) {
                SongImageView(song: song, isPlaying: isPlaying)
                SongInfoView(song: song, isPlaying: isPlaying)
                Spacer()
                SongDurationView(duration: song.duration)
            }
            .listItemPadding()
            .materialCardStyle()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Image Components (Clean Async)

struct ArtistImageView: View {
    let artist: Artist
    @EnvironmentObject var coverArtService: ReactiveCoverArtService
    
    @State private var artistImage: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(BackgroundColor.secondary)
                .frame(width: Sizes.coverSmall, height: Sizes.coverSmall)
                .blur(radius: 3)
            
            Group {
                if let image = artistImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: Sizes.avatar, height: Sizes.avatar)
                        .clipShape(Circle())
                        .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: Sizes.avatar, height: Sizes.avatar)
                        .overlay(
                            Group {
                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "music.mic")
                                        .font(.system(size: Sizes.icon))
                                        .foregroundStyle(TextColor.onDark)
                                }
                            }
                        )
                }
            }
        }
        .task(id: artist.id) {
            await loadArtistImage()
        }
    }
    
    private func loadArtistImage() async {
        if let cached = coverArtService.getCachedArtistImage(artist, size: 120) {
            artistImage = cached
            return
        }
        
        guard artist.coverArt != nil else { return }
        
        isLoading = true
        let loadedImage = await coverArtService.loadArtistImage(artist, size: 120)
        
        withAnimation(.easeInOut(duration: 0.3)) {
            artistImage = loadedImage
            isLoading = false
        }
    }
}

struct AlbumImageView: View {
    let album: Album
    @EnvironmentObject var coverArtService: ReactiveCoverArtService
    
    @State private var albumImage: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.s)
                .fill(BackgroundColor.secondary)
                .frame(width: Sizes.coverSmall, height: Sizes.coverSmall)
                .blur(radius: 3)
            
            Group {
                if let image = albumImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: Sizes.avatar, height: Sizes.avatar)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.s))
                        .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                } else {
                    RoundedRectangle(cornerRadius: Radius.s)
                        .fill(
                            LinearGradient(
                                colors: [.orange, .pink.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: Sizes.avatar, height: Sizes.avatar)
                        .overlay(
                            Group {
                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "record.circle.fill")
                                        .font(.system(size: Sizes.icon))
                                        .foregroundStyle(TextColor.onDark)
                                }
                            }
                        )
                }
            }
        }
        .task(id: album.id) {
            await loadAlbumImage()
        }
    }
    
    private func loadAlbumImage() async {
        if let cached = coverArtService.getCachedAlbumCover(album, size: 120) {
            albumImage = cached
            return
        }
        
        isLoading = true
        let loadedImage = await coverArtService.loadAlbumCover(album, size: 120)
        
        withAnimation(.easeInOut(duration: 0.3)) {
            albumImage = loadedImage
            isLoading = false
        }
    }
}

struct SongImageView: View {
    let song: Song
    let isPlaying: Bool
    @EnvironmentObject var coverArtService: ReactiveCoverArtService
    
    @State private var songImage: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.s)
                .fill(BackgroundColor.secondary.opacity(isPlaying ? 0.2 : 0.1))
                .frame(width: Sizes.coverSmall, height: Sizes.coverSmall)
                .blur(radius: 3)
            
            Group {
                if let image = songImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: Sizes.coverMini, height: Sizes.coverMini)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.s))
                        .overlay(
                            isPlaying ?
                            RoundedRectangle(cornerRadius: Radius.s)
                                .fill(BrandColor.playing.opacity(0.3))
                                .overlay(
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(Typography.caption)
                                        .foregroundStyle(BrandColor.playing)
                                ) : nil
                        )
                        .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                } else {
                    RoundedRectangle(cornerRadius: Radius.s)
                        .fill(
                            LinearGradient(
                                colors: [.green, .blue.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: Sizes.coverMini, height: Sizes.coverMini)
                        .overlay(
                            Group {
                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "music.note")
                                        .font(.system(size: Sizes.iconLarge))
                                        .foregroundStyle(TextColor.onDark)
                                }
                            }
                        )
                }
            }
        }
        .task(id: song.albumId) {
            await loadSongImage()
        }
    }
    
    // ✅ FIXED: No more ImageType usage
    private func loadSongImage() async {
        guard let albumId = song.albumId else { return }
        
        // ✅ FIXED: Use Album object instead of ImageType
        if let albumMetadata = AlbumMetadataCache.shared.getAlbum(id: albumId) {
            if let cached = coverArtService.getCachedAlbumCover(albumMetadata, size: 100) {
                songImage = cached
                return
            }
            
            isLoading = true
            let loadedImage = await coverArtService.loadAlbumCover(albumMetadata, size: 100)
            
            withAnimation(.easeInOut(duration: 0.3)) {
                songImage = loadedImage
                isLoading = false
            }
        } else {
            // ✅ GRACEFUL DEGRADATION: No fallback, just leave empty
            print("⚠️ Album metadata not found for ID: \(albumId)")
        }
    }
}

// MARK: - Info Components (unchanged)

struct ArtistInfoView: View {
    let artist: Artist
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(artist.name)
                .font(Typography.headline)
                .foregroundStyle(TextColor.primary)
                .lineLimit(1)
            
            HStack(spacing: Spacing.s) {
                Image(systemName: "music.mic")
                    .font(Typography.caption)
                    .foregroundStyle(TextColor.secondary)
                
                if let count = artist.albumCount {
                    Text("\(count) Album\(count != 1 ? "s" : "")")
                        .font(Typography.caption.weight(.medium))
                        .foregroundStyle(TextColor.secondary)
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
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(album.name)
                .font(Typography.headline)
                .foregroundStyle(TextColor.primary)
                .lineLimit(1)
            
            Text(album.artist)
                .font(Typography.bodyEmphasized)
                .foregroundStyle(TextColor.secondary)
                .lineLimit(1)
            
            HStack(spacing: Spacing.s) {
                if !formattedYear.isEmpty {
                    MetadataItem(
                        icon: "calendar",
                        text: formattedYear,
                        fontSize: Typography.caption
                    )
                }
                
                if !formattedYear.isEmpty && album.songCount ?? 0 > 0 {
                    MetadataSeparator(fontSize: Typography.caption)
                }
                
                if album.songCount ?? 0 > 0 {
                    MetadataItem(
                        icon: "music.note",
                        text: "\(album.songCount ?? 0) Songs",
                        fontSize: Typography.caption
                    )
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
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(song.title)
                .font(Typography.bodyEmphasized)
                .foregroundStyle(isPlaying ? BrandColor.playing : TextColor.primary)
                .lineLimit(1)
            
            Text(song.artist ?? "Unbekannter Künstler")
                .font(Typography.bodyEmphasized)
                .foregroundStyle(TextColor.secondary)
                .lineLimit(1)
            
            HStack(spacing: Spacing.s) {
                if !song.album.isNilOrEmpty {
                    MetadataItem(
                        icon: "record.circle.fill",
                        text: song.album!,
                        fontSize: Typography.caption
                    )
                }
                
                if !song.album.isNilOrEmpty && !formattedYear.isEmpty {
                    MetadataSeparator(fontSize: Typography.caption)
                }
                
                if !formattedYear.isEmpty {
                    MetadataItem(
                        icon: "calendar",
                        text: formattedYear,
                        fontSize: Typography.caption
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
        VStack(alignment: .trailing, spacing: Spacing.xs) {
            Text(formattedDuration)
                .font(Typography.monospacedNumbers)
                .foregroundStyle(TextColor.secondary)
                .monospacedDigit()
            
            Image(systemName: "music.note")
                .font(Typography.caption2)
                .foregroundStyle(TextColor.quaternary)
        }
    }
}

// MARK: - Shared Components (unchanged)

struct MetadataItem: View {
    let icon: String
    let text: String
    let fontSize: Font
    
    init(icon: String, text: String, fontSize: Font = Typography.caption) {
        self.icon = icon
        self.text = text
        self.fontSize = fontSize
    }
    
    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(fontSize)
                .foregroundStyle(TextColor.secondary)
            
            Text(text)
                .font(fontSize.weight(.medium))
                .foregroundStyle(TextColor.secondary)
                .lineLimit(1)
        }
    }
}

struct MetadataSeparator: View {
    let fontSize: Font
    
    init(fontSize: Font = Typography.caption) {
        self.fontSize = fontSize
    }
    
    var body: some View {
        Text("•")
            .font(fontSize)
            .foregroundStyle(TextColor.secondary)
    }
}

// MARK: - Helper Extension (unchanged)
extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        return self?.isEmpty ?? true
    }
}
