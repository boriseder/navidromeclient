//
//  AlbumHeaderView.swift - ENHANCED: Modern UX Patterns
//  NavidromeClient
//
//   ENHANCED: Adaptive layout, better visual hierarchy, improved interactions
//   SUSTAINABLE: Uses existing design system, no new dependencies
//

import SwiftUI

struct AlbumHeaderView: View {
    let album: Album
    let cover: UIImage?
    let songs: [Song]
    let isOfflineAlbum: Bool
    
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var downloadManager: DownloadManager
    
    // ENHANCED: Adaptive layout state
    @State private var headerSize: CGSize = .zero
    @State private var isCompact: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // ENHANCED: Adaptive container with better spacing
            adaptiveHeaderContainer
                .background(
                    // ENHANCED: Subtle gradient background
                    LinearGradient(
                        colors: [
                            DSColor.surface,
                            DSColor.surface.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: DSCorners.content))
                .shadow(
                    color: DSColor.overlay.opacity(0.1),
                    radius: 8,
                    x: 0,
                    y: 4
                )
            
            // ENHANCED: Action bar with better visual separation
            if !songs.isEmpty {
                actionBar
                    .padding(.top, DSLayout.elementGap)
            }
        }
        .onGeometryChange(for: CGSize.self) { geometry in
            geometry.size
        } action: { newSize in
            headerSize = newSize
            updateLayoutMode()
        }
    }
    
    // MARK: - ENHANCED: Adaptive Layout Container
    
    @ViewBuilder
    private var adaptiveHeaderContainer: some View {
        if isCompact {
            compactLayout
        } else {
            expansiveLayout
        }
    }
    
    // ENHANCED: Compact layout for smaller screens
    private var compactLayout: some View {
        VStack(spacing: DSLayout.contentGap) {
            albumCoverView
                .frame(width: DSLayout.detailCover * 0.7, height: DSLayout.detailCover * 0.7)
            
            albumInfoSection
        }
        .padding(DSLayout.contentPadding)
    }
    
    // ENHANCED: Expansive layout for larger screens
    private var expansiveLayout: some View {
        HStack(spacing: DSLayout.sectionGap) {
            albumCoverView
                .frame(width: DSLayout.detailCover, height: DSLayout.detailCover)
            
            VStack(alignment: .leading, spacing: DSLayout.contentGap) {
                albumInfoSection
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DSLayout.contentPadding)
    }
    
    // MARK: - ENHANCED: Improved Album Info Section
    
    private var albumInfoSection: some View {
        VStack(alignment: .leading, spacing: DSLayout.elementGap) {
            // ENHANCED: Better typography hierarchy
            albumTitleGroup
            
            // ENHANCED: Rich metadata with icons
            albumMetadataGroup
            
            // ENHANCED: Status indicators
            if isOfflineAlbum || downloadManager.isAlbumDownloaded(album.id) {
                albumStatusIndicators
            }
        }
    }
    
    private var albumTitleGroup: some View {
        VStack(alignment: .leading, spacing: DSLayout.tightGap) {
            Text(album.name)
                .font(DSText.sectionTitle)
                .foregroundStyle(DSColor.primary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            Text(album.artist)
                .font(DSText.emphasized)
                .foregroundStyle(DSColor.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
    }
    
    // ENHANCED: Rich metadata with better visual hierarchy
    private var albumMetadataGroup: some View {
        VStack(alignment: .leading, spacing: DSLayout.tightGap) {
            if let primaryMetadata = buildPrimaryMetadata() {
                MetadataRow(items: primaryMetadata)
            }
            
            if let secondaryMetadata = buildSecondaryMetadata() {
                MetadataRow(items: secondaryMetadata)
            }
        }
    }
    
    // ENHANCED: Status indicators with better visual design
    private var albumStatusIndicators: some View {
        HStack(spacing: DSLayout.elementGap) {
            if downloadManager.isAlbumDownloaded(album.id) {
                StatusBadge(
                    icon: "checkmark.circle.fill",
                    text: "Downloaded",
                    color: DSColor.success
                )
            }
            
            if isOfflineAlbum {
                StatusBadge(
                    icon: "wifi.slash",
                    text: "Offline Mode",
                    color: DSColor.warning
                )
            }
        }
    }
    
    // MARK: - ENHANCED: Action Bar with Better UX
    
    private var actionBar: some View {
        HStack(spacing: DSLayout.contentGap) {
            // ENHANCED: Primary action with better prominence
            PrimaryActionButton(
                icon: "play.fill",
                title: "Play",
                subtitle: "\(songs.count) songs",
                action: {
                    Task {
                        await playerVM.setPlaylist(songs, startIndex: 0, albumId: album.id)
                    }
                }
            )
            
            Spacer()
            
            // ENHANCED: Secondary actions with consistent design
            HStack(spacing: DSLayout.contentGap) {
                SecondaryActionButton(
                    icon: "shuffle",
                   // isActive: playerVM.isShuffling,
                    action: {
                        Task {
                            await playerVM.setPlaylist(
                                songs.shuffled(),
                                startIndex: 0,
                                albumId: album.id
                            )
                        }
                    }
                )
                
                if !isOfflineAlbum {
                    DownloadButton(
                        album: album,
                        songs: songs,
                        navidromeVM: navidromeVM
                    )
                }
            }
        }
        .padding(.horizontal, DSLayout.contentPadding)
    }
    
    // MARK: - ENHANCED: Album Cover with Better Presentation
    
    private var albumCoverView: some View {
        Group {
            if let cover = cover {
                Image(uiImage: cover)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: DSCorners.content))
                    .shadow(
                        color: DSColor.overlay.opacity(0.3),
                        radius: 12,
                        x: 0,
                        y: 6
                    )
            } else {
                AlbumPlaceholderView(album: album)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateLayoutMode() {
        // ENHANCED: Intelligent layout switching based on content size
        let availableWidth = headerSize.width
        isCompact = availableWidth < 480 // iPad mini threshold
    }
    
    private func buildPrimaryMetadata() -> [MetadataItem]? {
        var items: [MetadataItem] = []
        
        if let year = album.year {
            items.append(MetadataItem(icon: "calendar", text: String(year)))
        }
        
        if !songs.isEmpty {
            items.append(MetadataItem(icon: "music.note", text: "\(songs.count) songs"))
        }
        
        return items.isEmpty ? nil : items
    }
    
    private func buildSecondaryMetadata() -> [MetadataItem]? {
        var items: [MetadataItem] = []
        
        if let duration = calculateTotalDuration() {
            items.append(MetadataItem(icon: "clock", text: duration))
        }
        
        if let genre = album.genre, !genre.isEmpty {
            items.append(MetadataItem(icon: "music.note.list", text: genre))
        }
        
        return items.isEmpty ? nil : items
    }
    
    private func calculateTotalDuration() -> String? {
        let totalSeconds = songs.compactMap { $0.duration }.reduce(0, +)
        guard totalSeconds > 0 else { return nil }
        
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) min"
        }
    }
}

// MARK: - ENHANCED: Supporting Components

struct MetadataRow: View {
    let items: [MetadataItem]
    
    var body: some View {
        HStack(spacing: DSLayout.elementGap) {
            ForEach(items.indices, id: \.self) { index in
                HStack(spacing: DSLayout.tightGap) {
                    Image(systemName: items[index].icon)
                        .font(DSText.metadata)
                        .foregroundStyle(DSColor.tertiary)
                        .frame(width: DSLayout.smallIcon)
                    
                    Text(items[index].text)
                        .font(DSText.metadata.weight(.medium))
                        .foregroundStyle(DSColor.secondary)
                }
                
                if index < items.count - 1 {
                    Text("•")
                        .font(DSText.metadata)
                        .foregroundStyle(DSColor.quaternary)
                }
            }
            
            Spacer()
        }
    }
}

struct StatusBadge: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: DSLayout.tightGap) {
            Image(systemName: icon)
                .font(DSText.metadata)
            
            Text(text)
                .font(DSText.metadata.weight(.medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, DSLayout.elementPadding)
        .padding(.vertical, DSLayout.tightPadding)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
        .overlay(
            Capsule()
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct PrimaryActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DSLayout.elementGap) {
                Image(systemName: icon)
                    .font(DSText.prominent.weight(.semibold))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DSText.prominent.weight(.semibold))
                    
                    Text(subtitle)
                        .font(DSText.metadata)
                        .opacity(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(DSColor.onDark)
            .padding(.horizontal, DSLayout.contentPadding)
            .padding(.vertical, DSLayout.elementPadding)
            .background(
                RoundedRectangle(cornerRadius: DSCorners.content)
                    .fill(DSColor.accent)
            )
        }
    }
}


struct AlbumPlaceholderView: View {
    let album: Album
    
    var body: some View {
        RoundedRectangle(cornerRadius: DSCorners.content)
            .fill(
                LinearGradient(
                    colors: [
                        DSColor.accent.opacity(0.3),
                        DSColor.accent.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                VStack(spacing: DSLayout.elementGap) {
                    Image(systemName: "music.note")
                        .font(.system(size: 40))
                        .foregroundStyle(DSColor.accent.opacity(0.8))
                    
                    Text(String(album.name.prefix(2)).uppercased())
                        .font(DSText.sectionTitle.weight(.bold))
                        .foregroundStyle(DSColor.accent.opacity(0.8))
                }
            )
            .shadow(
                color: DSColor.overlay.opacity(0.3),
                radius: 12,
                x: 0,
                y: 6
            )
    }
}
