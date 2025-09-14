//
//  LibraryStatusHeader.swift
//  NavidromeClient
//
//  Created by Boris Eder on 14.09.25.
//


//
//  LibraryStatusHeader.swift - Generic Status Header Component
//  NavidromeClient
//
//  ✅ DRY: Replaces ArtistsStatusHeader + GenresStatusHeader
//

import SwiftUI

// MARK: - Generic Library Status Header
struct LibraryStatusHeader: View {
    let itemType: LibraryItemType
    let count: Int
    let isOnline: Bool
    let isOfflineMode: Bool
    
    var body: some View {
        HStack {
            NetworkStatusIndicator()
            
            Spacer()
            
            Text(countText)
                .font(Typography.caption)
                .foregroundStyle(TextColor.secondary)
            
            Spacer()
            
            if isOnline {
                OfflineModeToggle()
            }
        }
        .listItemPadding()
        .glassCardStyle()
        .screenPadding()
        .padding(.bottom, Spacing.s)
    }
    
    private var countText: String {
        let itemName = itemType.displayName(for: count)
        return "\(count) \(itemName)"
    }
}

// MARK: - Library Item Type Configuration
enum LibraryItemType {
    case artists
    case genres
    case albums
    case songs
    
    func displayName(for count: Int) -> String {
        let plural = count != 1
        
        switch self {
        case .artists:
            return plural ? "Artists" : "Artist"
        case .genres:
            return plural ? "Genres" : "Genre"
        case .albums:
            return plural ? "Albums" : "Album"
        case .songs:
            return plural ? "Songs" : "Song"
        }
    }
    
    var icon: String {
        switch self {
        case .artists: return "person.2"
        case .genres: return "music.note.list"
        case .albums: return "record.circle"
        case .songs: return "music.note"
        }
    }
}

// MARK: - Convenience Initializers
extension LibraryStatusHeader {
    
    /// Creates a status header for Artists
    static func artists(
        count: Int,
        isOnline: Bool,
        isOfflineMode: Bool
    ) -> LibraryStatusHeader {
        LibraryStatusHeader(
            itemType: .artists,
            count: count,
            isOnline: isOnline,
            isOfflineMode: isOfflineMode
        )
    }
    
    /// Creates a status header for Genres
    static func genres(
        count: Int,
        isOnline: Bool,
        isOfflineMode: Bool
    ) -> LibraryStatusHeader {
        LibraryStatusHeader(
            itemType: .genres,
            count: count,
            isOnline: isOnline,
            isOfflineMode: isOfflineMode
        )
    }
    
    /// Creates a status header for Albums
    static func albums(
        count: Int,
        isOnline: Bool,
        isOfflineMode: Bool
    ) -> LibraryStatusHeader {
        LibraryStatusHeader(
            itemType: .albums,
            count: count,
            isOnline: isOnline,
            isOfflineMode: isOfflineMode
        )
    }
}

// MARK: - Enhanced Network Status Indicator (if not already exists)
struct NetworkStatusIndicator: View {
    @StateObject private var networkMonitor = NetworkMonitor.shared
    let showText: Bool
    
    init(showText: Bool = true) {
        self.showText = showText
    }
    
    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: networkMonitor.isConnected ? "wifi" : "wifi.slash")
                .foregroundStyle(networkMonitor.isConnected ? BrandColor.success : BrandColor.error)
                .font(Typography.caption)
            
            if showText {
                Text(networkMonitor.isConnected ? "Online" : "Offline")
                    .font(Typography.caption)
                    .foregroundStyle(networkMonitor.isConnected ? BrandColor.success : BrandColor.error)
            }
        }
    }
}

// MARK: - Enhanced Offline Mode Toggle (if not already exists)
struct OfflineModeToggle: View {
    @StateObject private var offlineManager = OfflineManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    var body: some View {
        if networkMonitor.isConnected {
            Button(action: {
                offlineManager.toggleOfflineMode()
            }) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: offlineManager.isOfflineMode ? "icloud.slash" : "icloud")
                        .font(Typography.caption)
                    Text(offlineManager.isOfflineMode ? "Offline" : "All")
                        .font(Typography.caption)
                }
                .foregroundStyle(offlineManager.isOfflineMode ? BrandColor.warning : BrandColor.primary)
                .padding(.horizontal, Padding.s)
                .padding(.vertical, Padding.xs)
                .background(
                    Capsule()
                        .fill(offlineManager.isOfflineMode ? BrandColor.warning.opacity(0.1) : BrandColor.primary.opacity(0.1))
                )
            }
        }
    }
}

// MARK: OFfline Status Badge
struct OfflineStatusBadge: View {
    let album: Album
    @StateObject private var downloadManager = DownloadManager.shared
    
    var body: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: downloadManager.isAlbumDownloaded(album.id) ? "checkmark.circle.fill" : "icloud.slash")
                .foregroundStyle(downloadManager.isAlbumDownloaded(album.id) ? BrandColor.success : BrandColor.warning)
            
            Text(downloadManager.isAlbumDownloaded(album.id) ? "Downloaded" : "Not Available Offline")
                .font(Typography.caption)
                .foregroundStyle(downloadManager.isAlbumDownloaded(album.id) ? BrandColor.success : BrandColor.warning)
        }
        .padding(.horizontal, Padding.s)
        .padding(.vertical, Padding.xs)
        .background(
            Capsule()
                .fill(downloadManager.isAlbumDownloaded(album.id) ? BrandColor.success.opacity(0.1) : BrandColor.warning.opacity(0.1))
        )
    }
}

// MARK: Download Progress Ring
struct DownloadProgressRing: View {
    let progress: Double
    let size: CGFloat
    
    init(progress: Double, size: CGFloat = Sizes.icon) {
        self.progress = progress
        self.size = size
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(BrandColor.primary.opacity(0.3), lineWidth: 2)
                .frame(width: size, height: size)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(BrandColor.primary, lineWidth: 2)
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(Animations.ease, value: progress)
            
            if progress > 0 && progress < 1 {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: size * 0.3))
                    .fontWeight(.bold)
                    .foregroundStyle(BrandColor.primary)
            } else if progress >= 1 {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(BrandColor.success)
            }
        }
    }
}
