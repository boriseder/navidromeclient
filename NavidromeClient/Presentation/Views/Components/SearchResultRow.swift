//
//  SearchResultRow.swift - REFACTORED to Pure UI
//  NavidromeClient
//
//  ✅ CLEAN: All image loading logic moved to CoverArtManager
//  ✅ REACTIVE: Uses centralized image state instead of local @State
//

import SwiftUI

// MARK: - Artist Row (Pure UI)
struct SearchResultArtistRow: View {
    let artist: Artist
    let index: Int // For staggered loading
    
    @EnvironmentObject var coverArtManager: CoverArtManager
    
    var body: some View {
        NavigationLink(destination: ArtistDetailView(context: .artist(artist))) {
            HStack(spacing: Spacing.m) {
                // ✅ REACTIVE: Uses centralized state
                ArtistImageView(artist: artist, index: index)
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

// MARK: - Album Row (Pure UI)
struct SearchResultAlbumRow: View {
    let album: Album
    let index: Int // For staggered loading
    
    @EnvironmentObject var coverArtManager: CoverArtManager
    
    var body: some View {
        NavigationLink(destination: AlbumDetailView(album: album)) {
            HStack(spacing: Spacing.m) {
                // ✅ REACTIVE: Uses centralized state
                AlbumImageView(album: album, index: index)
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

// MARK: - Song Row (Pure UI)
struct SearchResultSongRow: View {
    let song: Song
    let index: Int
    let isPlaying: Bool
    let action: () -> Void
    
    @EnvironmentObject var coverArtManager: CoverArtManager
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.m) {
                // ✅ REACTIVE: Uses centralized state
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

// MARK: - ✅ REFACTORED: Image Components (Pure UI)

struct ArtistImageView: View {
    let artist: Artist
    let index: Int
    
    @EnvironmentObject var coverArtManager: CoverArtManager
    
    var body: some View {
        ZStack {
            Circle()
                .fill(BackgroundColor.secondary)
                .frame(width: Sizes.coverSmall, height: Sizes.coverSmall)
                .blur(radius: 3)
            
            Group {
                if let image = coverArtManager.getArtistImage(for: artist.id) {
                    // ✅ REACTIVE: Uses centralized state
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
                        .overlay(artistImageOverlay)
                }
            }
        }
        .task(id: artist.id) {
            // ✅ SINGLE LINE: Manager handles staggering, caching, state
            await coverArtManager.loadArtistImage(
                artist: artist,
                size: Int(Sizes.avatar),
                staggerIndex: index
            )
        }
    }
    
    @ViewBuilder
    private var artistImageOverlay: some View {
        if coverArtManager.isLoadingImage(for: artist.id) {
            // ✅ REACTIVE: Uses centralized loading state
            ProgressView()
                .scaleEffect(0.7)
                .tint(.white)
        } else {
            Image(systemName: "music.mic")
                .font(.system(size: Sizes.icon))
                .foregroundStyle(TextColor.onDark)
        }
    }
}

struct AlbumImageView: View {
    let album: Album
    let index: Int
    
    @EnvironmentObject var coverArtManager: CoverArtManager
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.s)
                .fill(BackgroundColor.secondary)
                .frame(width: Sizes.coverSmall, height: Sizes.coverSmall)
                .blur(radius: 3)
            
            Group {
                if let image = coverArtManager.getAlbumImage(for: album.id) {
                    // ✅ REACTIVE: Uses centralized state
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
                        .overlay(albumImageOverlay)
                }
            }
        }
        .task(id: album.id) {
            // ✅ SINGLE LINE: Manager handles staggering, caching, state
            await coverArtManager.loadAlbumImage(
                album: album,
                size: Int(Sizes.avatar),
                staggerIndex: index
            )
        }
    }
    
    @ViewBuilder
    private var albumImageOverlay: some View {
        if coverArtManager.isLoadingImage(for: album.id) {
            // ✅ REACTIVE: Uses centralized loading state
            ProgressView()
                .scaleEffect(0.7)
                .tint(.white)
        } else {
            Image(systemName: "record.circle.fill")
                .font(.system(size: Sizes.icon))
                .foregroundStyle(TextColor.onDark)
        }
    }
}

struct SongImageView: View {
    let song: Song
    let isPlaying: Bool
    
    @EnvironmentObject var coverArtManager: CoverArtManager
    
    // ✅ REACTIVE: Get song image via centralized state
    private var songImage: UIImage? {
        coverArtManager.getSongImage(for: song, size: Int(Sizes.coverMini))
    }
    
    // ✅ REACTIVE: Get loading state via centralized state
    private var isLoading: Bool {
        guard let albumId = song.albumId else { return false }
        return coverArtManager.isLoadingImage(for: albumId)
    }
    
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
                        .overlay(playingOverlay)
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
                        .overlay(songImageOverlay)
                }
            }
        }
        .task(id: song.albumId) {
            // ✅ SINGLE LINE: Manager handles all complexity
            _ = await coverArtManager.loadSongImage(song: song, size: Int(Sizes.coverMini))
        }
    }
    
    @ViewBuilder
    private var playingOverlay: some View {
        if isPlaying {
            RoundedRectangle(cornerRadius: Radius.s)
                .fill(BrandColor.playing.opacity(0.3))
                .overlay(
                    Image(systemName: "speaker.wave.2.fill")
                        .font(Typography.caption)
                        .foregroundStyle(BrandColor.playing)
                )
        }
    }
    
    @ViewBuilder
    private var songImageOverlay: some View {
        if isLoading {
            // ✅ REACTIVE: Uses centralized loading state
            ProgressView()
                .scaleEffect(0.6)
                .tint(.white)
        } else {
            Image(systemName: "music.note")
                .font(.system(size: Sizes.iconLarge))
                .foregroundStyle(TextColor.onDark)
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
            
            Text(song.artist ?? "Unknown Artist")
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

// MARK: - ✅ Convenience Initializers

extension SearchResultArtistRow {
    /// Convenience initializer without index for simple usage
    init(artist: Artist) {
        self.artist = artist
        self.index = 0
    }
}

extension SearchResultAlbumRow {
    /// Convenience initializer without index for simple usage
    init(album: Album) {
        self.album = album
        self.index = 0
    }
}
