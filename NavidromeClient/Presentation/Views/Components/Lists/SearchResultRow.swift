//
//  SearchResultRow.swift - UPDATED for CoverArtManager
//  NavidromeClient
//
//   UPDATED: Uses unified CoverArtManager instead of multiple services
//   REACTIVE: Uses centralized image state instead of local @State
//

import SwiftUI

// MARK: - Artist Row (Pure UI)
struct SearchResultArtistRow: View {

    @EnvironmentObject var deps: AppDependencies

    let artist: Artist
    let index: Int // For staggered loading
    
    
    var body: some View {
        NavigationLink(destination: ArtistDetailView(context: .artist(artist))) {
            HStack(spacing: DSLayout.contentGap) {
                //  REACTIVE: Uses centralized state
                ArtistImageView(artist: artist, index: index)
                ArtistInfoView(artist: artist)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(DSText.metadata.weight(.semibold))
                    .foregroundStyle(DSColor.tertiary)
            }
            .listItemPadding()
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Album Row (Pure UI)
struct SearchResultAlbumRow: View {
    let album: Album
    let index: Int // For staggered loading
    
    //  UPDATED: Uses CoverArtManager instead of ReactiveCoverArtService
    // MIGRATED to AppDependencies
    
    var body: some View {
        NavigationLink(destination: AlbumDetailView(album: album)) {
            HStack(spacing: DSLayout.contentGap) {
                //  REACTIVE: Uses centralized state
                AlbumImageView(album: album, index: index)
                AlbumInfoView(album: album)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(DSText.metadata.weight(.semibold))
                    .foregroundStyle(DSColor.tertiary)
            }
            .listItemPadding()
            .cardStyle()
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
    
    //  UPDATED: Uses CoverArtManager instead of ReactiveCoverArtService
    // MIGRATED to AppDependencies
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DSLayout.contentGap) {
                //  REACTIVE: Uses centralized state
                SongImageView(song: song, isPlaying: isPlaying)
                SongInfoView(song: song, isPlaying: isPlaying)
                Spacer()
                // Heart Button für Search Results
                HeartButton.songRow(song: song)

                SongDurationView(duration: song.duration)
            }
            .listItemPadding()
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}

// MARK: -  UPDATED: Image Components (Pure UI)

struct ArtistImageView: View {
    @EnvironmentObject var deps: AppDependencies
    
    let artist: Artist
    let index: Int
    
    //  UPDATED: Uses CoverArtManager instead of ReactiveCoverArtService
    // MIGRATED to AppDependencies
    
    var body: some View {
        ZStack {
            Circle()
                .fill(DSColor.surface)
                .frame(width: DSLayout.smallAvatar, height: DSLayout.smallAvatar)
            
            Group {
                if let image = deps.coverArtManager.getArtistImage(for: artist.id, size: Int(DSLayout.smallAvatar*3)) {
                    //  REACTIVE: Uses centralized state
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: DSLayout.smallAvatar, height: DSLayout.smallAvatar)
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
                        .frame(width: DSLayout.smallAvatar, height: DSLayout.smallAvatar)
                        .overlay(artistImageOverlay)
                }
            }
        }
        .task(id: artist.id) {
            //  SINGLE LINE: Manager handles staggering, caching, state
            await deps.coverArtManager.loadArtistImage(
                artist: artist,
                size: Int(DSLayout.smallAvatar*3),
                staggerIndex: index
            )
        }
    }
    
    @ViewBuilder
    private var artistImageOverlay: some View {
        if deps.coverArtManager.isLoadingImage(for: artist.id, size: Int(DSLayout.smallAvatar*3)) {
            //  REACTIVE: Uses centralized loading state
            ProgressView()
                .scaleEffect(0.7)
                .tint(.white)
        } else if let error = deps.coverArtManager.getImageError(for: artist.id, size: Int(DSLayout.smallAvatar*3)) {
            //  NEW: Error state handling
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: DSLayout.smallIcon))
                .foregroundStyle(.orange)
        } else {
            Image(systemName: "music.mic")
                .font(.system(size: DSLayout.icon))
                .foregroundStyle(DSColor.onDark)
        }
    }
}

struct AlbumImageView: View {
    @EnvironmentObject var deps: AppDependencies
    
    let album: Album
    let index: Int
        
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DSCorners.element)
                .fill(DSColor.surface)
                .frame(width: DSLayout.listCover, height: DSLayout.listCover)
            
            Group {
                if let image = deps.coverArtManager.getAlbumImage(for: album.id, size: Int(DSLayout.listCover*3)) {
                    //  REACTIVE: Uses centralized state
                    Image(uiImage: image)  
                        .resizable()
                        .scaledToFill()
                        .frame(width: DSLayout.listCover, height: DSLayout.listCover)
                        .clipShape(RoundedRectangle(cornerRadius: DSCorners.element))
                        .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                } else {
                    RoundedRectangle(cornerRadius: DSCorners.element)
                        .fill(
                            LinearGradient(
                                colors: [.orange, .pink.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: DSLayout.smallAvatar, height: DSLayout.smallAvatar)
                        .overlay(albumImageOverlay)
                }
            }
        }
        .task(id: album.id) {
            //  SINGLE LINE: Manager handles staggering, caching, state
            await deps.coverArtManager.loadAlbumImage(
                album: album,
                size: Int(DSLayout.listCover*3),
                staggerIndex: index
            )
        }
    }
    
    @ViewBuilder
    private var albumImageOverlay: some View {
        if deps.coverArtManager.isLoadingImage(for: album.id, size: Int(DSLayout.listCover*3)) {
            //  REACTIVE: Uses centralized loading state
            ProgressView()
                .scaleEffect(0.7)
                .tint(.white)
        } else if let error = deps.coverArtManager.getImageError(for: album.id, size: Int(DSLayout.listCover*3)) {
            //  NEW: Error state handling
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: DSLayout.smallIcon))
                .foregroundStyle(.orange)
        } else {
            Image(systemName: "record.circle.fill")
                .font(.system(size: DSLayout.icon))
                .foregroundStyle(DSColor.onDark)
        }
    }
}

struct SongImageView: View {
    @EnvironmentObject var deps: AppDependencies
    
    let song: Song
    let isPlaying: Bool
    
    //  UPDATED: Uses CoverArtManager instead of ReactiveCoverArtService
    // MIGRATED to AppDependencies
    
    //  REACTIVE: Get song image via centralized state
    private var songImage: UIImage? {
        deps.coverArtManager.getSongImage(for: song, size: Int(DSLayout.miniCover))
    }
    
    //  REACTIVE: Get loading state via centralized state
    private var isLoading: Bool {
        guard let albumId = song.albumId else { return false }
        return deps.coverArtManager.isLoadingImage(for: albumId, size: Int(DSLayout.miniCover))
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DSCorners.element)
                .fill(DSColor.surface.opacity(isPlaying ? 0.2 : 0.1))
                .frame(width: DSLayout.listCover, height: DSLayout.listCover)
            
            Group {
                if let image = songImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: DSLayout.miniCover, height: DSLayout.miniCover)
                        .clipShape(RoundedRectangle(cornerRadius: DSCorners.element))
                        .overlay(playingOverlay)
                        .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                } else {
                    RoundedRectangle(cornerRadius: DSCorners.element)
                        .fill(
                            LinearGradient(
                                colors: [.green, .blue.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: DSLayout.miniCover, height: DSLayout.miniCover)
                        .overlay(songImageOverlay)
                }
            }
        }
        .task(id: song.albumId) {
            //  SINGLE LINE: Manager handles all complexity
            _ = await deps.coverArtManager.loadSongImage(song: song, size: Int(DSLayout.miniCover))
        }
    }
    
    @ViewBuilder
    private var playingOverlay: some View {
        if isPlaying {
            RoundedRectangle(cornerRadius: DSCorners.element)
                .fill(DSColor.playing.opacity(0.3))
                .overlay(
                    Image(systemName: "speaker.wave.2.fill")
                        .font(DSText.metadata)
                        .foregroundStyle(DSColor.playing)
                )
        }
    }
    
    @ViewBuilder
    private var songImageOverlay: some View {
        if isLoading {
            //  REACTIVE: Uses centralized loading state
            ProgressView()
                .scaleEffect(0.6)
                .tint(.white)
        } else if let albumId = song.albumId, let error = deps.coverArtManager.getImageError(for: albumId, size: Int(DSLayout.smallAvatar*3)) {
            //  NEW: Error state handling
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: DSLayout.smallIcon))
                .foregroundStyle(.orange)
        } else {
            Image(systemName: "music.note")
                .font(.system(size: DSLayout.largeIcon))
                .foregroundStyle(DSColor.onDark)
        }
    }
}

// MARK: - Info Components (unchanged)

struct ArtistInfoView: View {
    let artist: Artist
    
    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.tightGap) {
            Text(artist.name)
                .font(DSText.prominent)
                .foregroundStyle(DSColor.primary)
                .lineLimit(1)
            
            HStack(spacing: DSLayout.elementGap) {
                Image(systemName: "music.mic")
                    .font(DSText.metadata)
                    .foregroundStyle(DSColor.secondary)
                
                if let count = artist.albumCount {
                    Text("\(count) Album\(count != 1 ? "s" : "")")
                        .font(DSText.metadata.weight(.medium))
                        .foregroundStyle(DSColor.secondary)
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
        VStack(alignment: .leading, spacing: DSLayout.tightGap) {
            Text(album.name)
                .font(DSText.prominent)
                .foregroundStyle(DSColor.primary)
                .lineLimit(1)
            
            Text(album.artist)
                .font(DSText.emphasized)
                .foregroundStyle(DSColor.secondary)
                .lineLimit(1)
            
            HStack(spacing: DSLayout.elementGap) {
                if !formattedYear.isEmpty {
                    MetadataItem(
                        icon: "calendar",
                        text: formattedYear,
                        fontSize: DSText.metadata
                    )
                }
                
                if !formattedYear.isEmpty && album.songCount ?? 0 > 0 {
                    MetadataSeparator(fontSize: DSText.metadata)
                }
                
                if album.songCount ?? 0 > 0 {
                    MetadataItem(
                        icon: "music.note",
                        text: "\(album.songCount ?? 0) Songs",
                        fontSize: DSText.metadata
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
        VStack(alignment: .leading, spacing: DSLayout.tightGap) {
            Text(song.title)
                .font(DSText.emphasized)
                .foregroundStyle(isPlaying ? DSColor.playing : DSColor.primary)
                .lineLimit(1)
            
            Text(song.artist ?? "Unknown Artist")
                .font(DSText.emphasized)
                .foregroundStyle(DSColor.secondary)
                .lineLimit(1)
            
            HStack(spacing: DSLayout.elementGap) {
                if !song.album.isNilOrEmpty {
                    MetadataItem(
                        icon: "record.circle.fill",
                        text: song.album!,
                        fontSize: DSText.metadata
                    )
                }
                
                if !song.album.isNilOrEmpty && !formattedYear.isEmpty {
                    MetadataSeparator(fontSize: DSText.metadata)
                }
                
                if !formattedYear.isEmpty {
                    MetadataItem(
                        icon: "calendar",
                        text: formattedYear,
                        fontSize: DSText.metadata
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
        VStack(alignment: .trailing, spacing: DSLayout.tightGap) {
            Text(formattedDuration)
                .font(DSText.numbers)
                .foregroundStyle(DSColor.secondary)
                .monospacedDigit()
            
            Image(systemName: "music.note")
                .font(DSText.body)
                .foregroundStyle(DSColor.quaternary)
        }
    }
}

// MARK: - Shared Components (unchanged)

struct MetadataItem: View {
    let icon: String
    let text: String
    let fontSize: Font
    
    init(icon: String, text: String, fontSize: Font = DSText.metadata) {
        self.icon = icon
        self.text = text
        self.fontSize = fontSize
    }
    
    var body: some View {
        HStack(spacing: DSLayout.tightGap) {
            Image(systemName: icon)
                .font(fontSize)
                .foregroundStyle(DSColor.secondary)
            
            Text(text)
                .font(fontSize.weight(.medium))
                .foregroundStyle(DSColor.secondary)
                .lineLimit(1)
        }
    }
}

struct MetadataSeparator: View {
    let fontSize: Font
    
    init(fontSize: Font = DSText.metadata) {
        self.fontSize = fontSize
    }
    
    var body: some View {
        Text("•")
            .font(fontSize)
            .foregroundStyle(DSColor.secondary)
    }
}

// MARK: - Helper Extension (unchanged)
extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        return self?.isEmpty ?? true
    }
}

// MARK: -  Convenience Initializers

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
