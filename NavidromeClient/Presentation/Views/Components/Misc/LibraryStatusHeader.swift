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
//   DRY: Replaces ArtistsStatusHeader + GenresStatusHeader
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
                .font(DSText.metadata)
                .foregroundStyle(DSColor.secondary)
            
            Spacer()
            
            if isOnline {
                OfflineModeToggle()
            }
        }
        .padding(.bottom, DSLayout.elementGap)
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
        HStack(spacing: DSLayout.tightGap) {
            Image(systemName: networkMonitor.canLoadOnlineContent ? "wifi" : "wifi.slash")
                .foregroundStyle(networkMonitor.canLoadOnlineContent ? DSColor.success : DSColor.error)
                .font(DSText.metadata)
            
            if showText {
                Text(networkMonitor.canLoadOnlineContent ? "Online" : "Offline")
                    .font(DSText.metadata)
                    .foregroundStyle(networkMonitor.canLoadOnlineContent ? DSColor.success : DSColor.error)
            }
        }
    }
}

// MARK: - Enhanced Offline Mode Toggle (if not already exists)
struct OfflineModeToggle: View {
    @StateObject private var offlineManager = OfflineManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    var body: some View {
        if networkMonitor.canLoadOnlineContent {
            Button(action: {
                offlineManager.toggleOfflineMode()
            }) {
                HStack(spacing: DSLayout.tightGap) {
                    Image(systemName: offlineManager.isOfflineMode ? "icloud.slash" : "icloud")
                        .font(DSText.metadata)
                    Text(offlineManager.isOfflineMode ? "Offline" : "All")
                        .font(DSText.metadata)
                }
                .foregroundStyle(offlineManager.isOfflineMode ? DSColor.warning : DSColor.accent)
                .padding(.horizontal, DSLayout.elementPadding)
                .padding(.vertical, DSLayout.tightPadding)
                .background(
                    Capsule()
                        .fill(offlineManager.isOfflineMode ? DSColor.warning.opacity(0.1) : DSColor.accent.opacity(0.1))
                )
            }
        }
    }
}
