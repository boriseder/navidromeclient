//
//  SearchResultRow.swift - Enhanced with Design System
//  NavidromeClient
//
//  ✅ ENHANCED: Vollständige Anwendung des Design Systems
//

import SwiftUI

// MARK: - Artist Row with Cover Art (Enhanced with DS)
struct SearchResultArtistRow: View {
    let artist: Artist
    @EnvironmentObject var coverArtService: ReactiveCoverArtService
    
    var body: some View {
        NavigationLink(destination: ArtistDetailView(context: .artist(artist))) {
            HStack(spacing: Spacing.m) {
                ArtistImageView(
                    artist: artist,
                    coverArtService: coverArtService
                )
                
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

// MARK: - Album Row with Cover Art (Enhanced with DS)
struct SearchResultAlbumRow: View {
    let album: Album
    
    // REAKTIVER Cover Art Service
    @EnvironmentObject var coverArtService: ReactiveCoverArtService
    
    var body: some View {
        NavigationLink(destination: AlbumDetailView(album: album)) {
            HStack(spacing: Spacing.m) {
                // REAKTIVES Album Cover
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.s)
                        .fill(BackgroundColor.secondary)
                        .frame(width: Sizes.coverSmall, height: Sizes.coverSmall)
                        .blur(radius: 3) // Approx. DS applied
                    
                    Group {
                        if let image = coverArtService.coverImage(for: album, size: 120) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: Sizes.avatar, height: Sizes.avatar)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.s))
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
                                    Image(systemName: "record.circle.fill")
                                        .font(.system(size: Sizes.icon))
                                        .foregroundStyle(TextColor.onDark)
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
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(TextColor.tertiary)
            }
            .listItemPadding()
            .materialCardStyle()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Song Row (Enhanced with DS)
struct SearchResultSongRow: View {
    let song: Song
    let index: Int
    let isPlaying: Bool
    let action: () -> Void
    
    // REAKTIVER Cover Art Service
    @EnvironmentObject var coverArtService: ReactiveCoverArtService
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.m) {
                // REAKTIVES Song Cover
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.s)
                        .fill(BackgroundColor.secondary.opacity(isPlaying ? 0.2 : 0.1))
                        .frame(width: Sizes.coverSmall, height: Sizes.coverSmall)
                        .blur(radius: 3) // Approx. DS applied
                    
                    Group {
                        if let albumId = song.albumId,
                           let image = coverArtService.image(for: albumId, size: 100) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: Sizes.coverMini, height: Sizes.coverMini)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.s))
                                .overlay(
                                    // Playing indicator overlay
                                    isPlaying ?
                                    RoundedRectangle(cornerRadius: Radius.s)
                                        .fill(BrandColor.playing.opacity(0.3))
                                        .overlay(
                                            Image(systemName: "speaker.wave.2.fill")
                                                .font(Typography.caption)
                                                .foregroundStyle(BrandColor.playing)
                                        ) : nil
                                )
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
                                    Image(systemName: "music.note")
                                        .font(.system(size: Sizes.iconLarge))
                                        .foregroundStyle(TextColor.onDark)
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
            .listItemPadding()
            .materialCardStyle()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Artist Components (Enhanced with DS)
struct ArtistImageView: View {
    let artist: Artist
    let coverArtService: ReactiveCoverArtService
    
    var body: some View {
        ZStack {
            // Subtle glow background
            Circle()
                .fill(BackgroundColor.secondary)
                .frame(width: Sizes.coverSmall, height: Sizes.coverSmall)
                .blur(radius: 3) // Approx. DS applied
            
            // Main avatar
            Group {
                if let coverArt = artist.coverArt,
                   let image = coverArtService.image(for: coverArt, size: 120) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: Sizes.avatar, height: Sizes.avatar)
                        .clipShape(Circle())
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
                            Image(systemName: "music.mic")
                                .font(.system(size: Sizes.icon))
                                .foregroundStyle(TextColor.onDark)
                        )
                        .onAppear {
                            if let coverArt = artist.coverArt {
                                coverArtService.requestImage(for: coverArt, size: 120)
                            }
                        }
                }
            }
        }
    }
}

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

// MARK: - Album Components (Enhanced with DS)
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

// MARK: - Song Components (Enhanced with DS)
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
            
            // Small music note indicator
            Image(systemName: "music.note")
                .font(Typography.caption2)
                .foregroundStyle(TextColor.quaternary)
        }
    }
}

// MARK: - Shared Components (Enhanced with DS)
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

// MARK: - Helper Extension
extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        return self?.isEmpty ?? true
    }
}
