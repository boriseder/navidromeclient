//
//  ArtistDetailHeader.swift - ENHANCED: Modern Artist Header Design
//  NavidromeClient
//
//   ENHANCED: Adaptive layout, better visual hierarchy, modern avatar design
//   SUSTAINABLE: Uses existing design system and patterns
//

import SwiftUI

struct ArtistDetailHeader: View {
    let context: ArtistDetailContext
    let albums: [Album]
    let availableOfflineAlbums: [Album]
    let artistImage: UIImage?
    let isOfflineMode: Bool
    let onShuffleAll: () async -> Void
    
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    
    // ENHANCED: Adaptive layout state
    @State private var headerSize: CGSize = .zero
    @State private var isCompact: Bool = false
    
    private var contextTitle: String {
        switch context {
        case .artist(let artist): return artist.name
        case .genre(let genre): return genre.value
        }
    }
    
    private var contextIcon: String {
        switch context {
        case .artist: return "music.mic"
        case .genre: return "music.note.list"
        }
    }
    
    private var totalAlbumCount: Int {
        isOfflineMode ? availableOfflineAlbums.count : albums.count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // ENHANCED: Main header container with adaptive layout
            headerContainer
                .background(headerBackground)
                .clipShape(RoundedRectangle(cornerRadius: DSCorners.content))
                .shadow(
                    color: DSColor.overlay.opacity(0.1),
                    radius: 8,
                    x: 0,
                    y: 4
                )
            
            // ENHANCED: Status and actions section
            if totalAlbumCount > 0 {
                bottomSection
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
    
    // MARK: - ENHANCED: Adaptive Header Container
    
    @ViewBuilder
    private var headerContainer: some View {
        if isCompact {
            compactHeaderLayout
        } else {
            expansiveHeaderLayout
        }
    }
    
    // ENHANCED: Compact layout for smaller screens/longer names
    private var compactHeaderLayout: some View {
        VStack(spacing: DSLayout.sectionGap) {
            // ENHANCED: Large centered avatar
            EnhancedArtistAvatar(
                image: artistImage,
                context: context,
                size: .large
            )
            
            // ENHANCED: Centered info section
            VStack(spacing: DSLayout.contentGap) {
                artistInfoSection
                albumStatsSection
            }
        }
        .padding(DSLayout.contentPadding)
        .frame(maxWidth: .infinity)
    }
    
    // ENHANCED: Expansive layout for larger screens/shorter names
    private var expansiveHeaderLayout: some View {
        HStack(spacing: DSLayout.sectionGap) {
            // ENHANCED: Medium avatar on left
            EnhancedArtistAvatar(
                image: artistImage,
                context: context,
                size: .medium
            )
            
            // ENHANCED: Info section with better layout
            VStack(alignment: .leading, spacing: DSLayout.contentGap) {
                artistInfoSection
                albumStatsSection
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DSLayout.contentPadding)
    }
    
    // MARK: - ENHANCED: Artist Info Section
    
    private var artistInfoSection: some View {
        VStack(alignment: isCompact ? .center : .leading, spacing: DSLayout.elementGap) {
            // ENHANCED: Artist/Genre name with better typography
            Text(contextTitle)
                .font(isCompact ? DSText.pageTitle : DSText.sectionTitle)
                .foregroundStyle(DSColor.primary)
                .lineLimit(3)
                .multilineTextAlignment(isCompact ? .center : .leading)
                .frame(maxWidth: .infinity, alignment: isCompact ? .center : .leading)
            
            // ENHANCED: Context type indicator
            HStack(spacing: DSLayout.tightGap) {
                Image(systemName: contextIcon)
                    .font(DSText.metadata)
                    .foregroundStyle(DSColor.accent)
                
                Text(contextTypeDescription)
                    .font(DSText.metadata.weight(.medium))
                    .foregroundStyle(DSColor.secondary)
            }
            .frame(maxWidth: .infinity, alignment: isCompact ? .center : .leading)
        }
    }
    
    private var contextTypeDescription: String {
        switch context {
        case .artist(let artist):
            if let count = artist.albumCount {
                return "\(count) Album\(count != 1 ? "s" : "") in Library"
            }
            return "Artist"
        case .genre:
            return "Music Genre"
        }
    }
    
    // MARK: - ENHANCED: Album Stats Section
    
    @ViewBuilder
    private var albumStatsSection: some View {
        if totalAlbumCount > 0 {
            VStack(spacing: DSLayout.elementGap) {
                // ENHANCED: Stats with better visual hierarchy
                HStack(spacing: DSLayout.contentGap) {
                    if !isOfflineMode && albums.count > 0 {
                        StatBadge(
                            value: albums.count,
                            label: "Total Albums",
                            color: DSColor.accent,
                            style: .primary
                        )
                    }
                    
                    if availableOfflineAlbums.count > 0 {
                        StatBadge(
                            value: availableOfflineAlbums.count,
                            label: "Downloaded",
                            color: DSColor.success,
                            style: availableOfflineAlbums.count == albums.count ? .primary : .secondary
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: isCompact ? .center : .leading)
            }
        }
    }
    
    // MARK: - ENHANCED: Bottom Section
    
    private var bottomSection: some View {
        VStack(spacing: DSLayout.elementGap) {
            // ENHANCED: Status indicators for offline mode
            if isOfflineMode && !availableOfflineAlbums.isEmpty {
                offlineStatusIndicator
            }
            
            // ENHANCED: Action bar with better design
            actionBar
        }
    }
    
    private var offlineStatusIndicator: some View {
        HStack(spacing: DSLayout.elementGap) {
            HStack(spacing: DSLayout.tightGap) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(DSColor.success)
                
                Text("Showing Downloaded Content")
                    .font(DSText.body.weight(.medium))
                    .foregroundStyle(DSColor.success)
            }
            
            Spacer()
            
            if networkMonitor.isConnected {
                Button("View All") {
                    offlineManager.switchToOnlineMode()
                }
                .font(DSText.body.weight(.medium))
                .foregroundStyle(DSColor.accent)
            }
        }
        .padding(DSLayout.contentPadding)
        .background(
            RoundedRectangle(cornerRadius: DSCorners.element)
                .fill(DSColor.success.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSCorners.element)
                .stroke(DSColor.success.opacity(0.3), lineWidth: 1)
        )
    }
    
    // ENHANCED: Action bar with modern design
    private var actionBar: some View {
        HStack(spacing: DSLayout.contentGap) {
            // ENHANCED: Primary shuffle action
            ShuffleAllButton(
                albumCount: totalAlbumCount,
                action: onShuffleAll
            )
            
            Spacer()
            
            // ENHANCED: Secondary actions
            HStack(spacing: DSLayout.elementGap) {
                SecondaryActionButton(
                    icon: "heart",
                    action: {
                        // Favorite artist/genre functionality
                    }
                )
                
                SecondaryActionButton(
                    icon: "square.and.arrow.up",
                    action: {
                        // Share functionality
                    }
                )
            }
        }
    }
    
    // MARK: - ENHANCED: Header Background
    
    private var headerBackground: some View {
        ZStack {
            // Base background
            DSColor.surface
            
            // ENHANCED: Subtle gradient overlay
            LinearGradient(
                colors: [
                    DSColor.surface,
                    DSColor.surface.opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // ENHANCED: Artist image background blur (if available)
            if let artistImage = artistImage {
                Image(uiImage: artistImage)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 30)
                    .opacity(0.08)
                    .clipped()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateLayoutMode() {
        // ENHANCED: Intelligent layout switching
        let availableWidth = headerSize.width
        let titleLength = contextTitle.count
        
        // Switch to compact if narrow screen OR very long title
        isCompact = availableWidth < 400 || titleLength > 20
    }
}

// MARK: - ENHANCED: Supporting Components

struct EnhancedArtistAvatar: View {
    let image: UIImage?
    let context: ArtistDetailContext
    let size: AvatarSize
    
    enum AvatarSize {
        case medium, large
        
        var dimension: CGFloat {
            switch self {
            case .medium: return DSLayout.avatar
            case .large: return DSLayout.avatar * 1.4
            }
        }
        
        var iconSize: CGFloat {
            switch self {
            case .medium: return DSLayout.largeIcon
            case .large: return DSLayout.largeIcon * 1.3
            }
        }
    }
    
    private var contextIcon: String {
        switch context {
        case .artist: return "music.mic"
        case .genre: return "music.note.list"
        }
    }
    
    private var gradientColors: [Color] {
        switch context {
        case .artist: return [.blue, .purple]
        case .genre: return [.green, .teal]
        }
    }
    
    var body: some View {
        Group {
            if let image = image {
                // ENHANCED: Real artist image with better styling
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.dimension, height: size.dimension)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: gradientColors.map { $0.opacity(0.3) },
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
            } else {
                // ENHANCED: Sophisticated placeholder
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size.dimension, height: size.dimension)
                    .overlay(
                        ZStack {
                            // Subtle pattern overlay
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color.white.opacity(0.1),
                                            Color.clear
                                        ],
                                        center: .topLeading,
                                        startRadius: 0,
                                        endRadius: size.dimension * 0.7
                                    )
                                )
                            
                            // Icon
                            Image(systemName: contextIcon)
                                .font(.system(size: size.iconSize, weight: .medium))
                                .foregroundStyle(DSColor.onDark.opacity(0.9))
                        }
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                DSColor.onDark.opacity(0.2),
                                lineWidth: 1
                            )
                    )
            }
        }
        .shadow(
            color: DSColor.overlay.opacity(0.2),
            radius: 8,
            x: 0,
            y: 4
        )
    }
}

struct StatBadge: View {
    let value: Int
    let label: String
    let color: Color
    let style: BadgeStyle
    
    enum BadgeStyle {
        case primary, secondary
    }
    
    var body: some View {
        VStack(spacing: DSLayout.tightGap) {
            Text("\(value)")
                .font(style == .primary ? DSText.sectionTitle.weight(.bold) : DSText.prominent.weight(.bold))
                .foregroundStyle(color)
            
            Text(label)
                .font(DSText.metadata.weight(.medium))
                .foregroundStyle(DSColor.secondary)
        }
        .padding(.horizontal, DSLayout.elementPadding)
        .padding(.vertical, DSLayout.tightPadding)
        .background(
            RoundedRectangle(cornerRadius: DSCorners.element)
                .fill(color.opacity(style == .primary ? 0.15 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSCorners.element)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct ShuffleAllButton: View {
    let albumCount: Int
    let action: () async -> Void
    
    @State private var isLoading = false
    
    var body: some View {
        Button {
            Task {
                isLoading = true
                await action()
                isLoading = false
            }
        } label: {
            HStack(spacing: DSLayout.elementGap) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(DSColor.onDark)
                } else {
                    Image(systemName: "shuffle")
                        .font(DSText.prominent.weight(.semibold))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Shuffle All")
                        .font(DSText.prominent.weight(.semibold))
                    
                    Text("\(albumCount) albums")
                        .font(DSText.metadata)
                        .opacity(0.8)
                }
            }
            .foregroundStyle(DSColor.onDark)
            .padding(.horizontal, DSLayout.contentPadding)
            .padding(.vertical, DSLayout.elementPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DSCorners.content)
                    .fill(DSColor.accent)
            )
        }
        .disabled(isLoading || albumCount == 0)
    }
}

struct SecondaryActionButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(DSText.prominent)
                .foregroundStyle(DSColor.secondary)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(DSColor.surface)
                )
        }
    }
}
