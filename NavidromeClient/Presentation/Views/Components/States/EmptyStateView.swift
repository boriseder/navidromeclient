//
//  ConsolidatedStateViews.swift
//  NavidromeClient
//
//  ✅ CONSOLIDATED: Universal EmptyState and Loading components
//  ✅ REUSABLE: Single source of truth for all empty states
//  ✅ CONSISTENT: Design system applied throughout
//

import SwiftUI

// MARK: - ✅ Universal Loading View

struct LoadingView: View {
    let title: String
    let subtitle: String?
    @State private var isAnimating = false
    
    init(title: String = "Loading...", subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }
    
    var body: some View {
        VStack(spacing: DSLayout.sectionGap) {
            // Animated loading circles
            HStack(spacing: DSLayout.elementGap) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(DSColor.accent)
                        .frame(width: 12, height: 12)
                        .scaleEffect(isAnimating ? 1.0 : 0.5)
                        .animation(
                            Animations.ease
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: isAnimating
                        )
                }
            }
            
            VStack(spacing: DSLayout.elementGap) {
                Text(title)
                    .font(DSText.prominent)
                    .foregroundStyle(DSColor.primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DSText.metadata)
                        .foregroundStyle(DSColor.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(DSLayout.screenGap)
        .cardStyle()
        .onAppear {
            isAnimating = true
        }
        .onDisappear {
            isAnimating = false
        }
    }
}

// MARK: - ✅ Universal Empty State View

struct EmptyStateView: View {
    let type: EmptyStateType
    let customTitle: String?
    let customMessage: String?
    let primaryAction: EmptyStateAction?
    let secondaryAction: EmptyStateAction?
    
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @EnvironmentObject private var offlineManager: OfflineManager
    
    init(
        type: EmptyStateType,
        customTitle: String? = nil,
        customMessage: String? = nil,
        primaryAction: EmptyStateAction? = nil,
        secondaryAction: EmptyStateAction? = nil
    ) {
        self.type = type
        self.customTitle = customTitle
        self.customMessage = customMessage
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
    }
    
    var body: some View {
        VStack(spacing: DSLayout.sectionGap) {
            Image(systemName: iconName)
                .font(.system(size: 60))
                .foregroundStyle(DSColor.secondary)
            
            VStack(spacing: DSLayout.elementGap) {
                Text(titleText)
                    .font(DSText.itemTitle)
                    .foregroundStyle(DSColor.primary)
                
                Text(messageText)
                    .font(DSText.sectionTitle)
                    .foregroundStyle(DSColor.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Action buttons
            VStack(spacing: DSLayout.contentGap) {
                if let primaryAction = primaryAction {
                    Button(primaryAction.title, action: primaryAction.action)
                } else if !isOnline && !isOfflineMode {
                    // Auto-generated action for offline scenarios
                    Button("Switch to Downloaded Music") {
                        offlineManager.switchToOfflineMode()
                    }
                }
                
                if let secondaryAction = secondaryAction {
                    Button(secondaryAction.title, action: secondaryAction.action)
                }
            }
        }
        .padding(DSLayout.screenGap)
        .cardStyle()
    }
    
    // MARK: - Computed Properties
    
    private var isOnline: Bool {
        return networkMonitor.canLoadOnlineContent
    }
    
    private var isOfflineMode: Bool {
        return offlineManager.isOfflineMode
    }
    
    private var iconName: String {
        if let customIcon = type.customIcon {
            return customIcon
        }
        
        if !isOnline {
            return "wifi.slash"
        } else if isOfflineMode {
            return type.offlineIcon
        } else {
            return type.onlineIcon
        }
    }
    
    private var titleText: String {
        if let customTitle = customTitle {
            return customTitle
        }
        
        if !isOnline {
            return "No Connection"
        } else if isOfflineMode {
            return type.offlineTitle
        } else {
            return type.onlineTitle
        }
    }
    
    private var messageText: String {
        if let customMessage = customMessage {
            return customMessage
        }
        
        if !isOnline {
            return type.noConnectionMessage
        } else if isOfflineMode {
            return type.offlineMessage
        } else {
            return type.onlineMessage
        }
    }
}

// MARK: - ✅ Empty State Types

enum EmptyStateType {
    case artists
    case albums
    case songs
    case genres
    case search
    case notConfigured
    case downloads
    case playlists
    case favorites
    case custom(icon: String, onlineTitle: String, onlineMessage: String)
    
    var customIcon: String? {
        switch self {
        case .custom(let icon, _, _):
            return icon
        default:
            return nil
        }
    }
    
    var onlineIcon: String {
        switch self {
        case .artists: return "person.2"
        case .albums: return "music.note.house"
        case .songs: return "music.note"
        case .genres: return "music.note.list"
        case .search: return "magnifyingglass.circle"
        case .notConfigured: return "gear.badge.questionmark"
        case .downloads: return "arrow.down.circle"
        case .playlists: return "music.note.list"
        case .favorites: return "heart"
        case .custom(let icon, _, _): return icon
        }
    }
    
    var offlineIcon: String {
        switch self {
        case .artists: return "person.2.slash"
        case .albums: return "arrow.down.circle"
        case .songs: return "music.note.slash"
        case .genres: return "music.note.list.slash"
        case .search: return "arrow.down.circle"
        case .downloads: return "arrow.down.circle.slash"
        case .playlists: return "music.note.list.slash"
        case .favorites: return "heart.slash"
        default: return onlineIcon
        }
    }
    
    var onlineTitle: String {
        switch self {
        case .artists: return "No Artists Found"
        case .albums: return "No Albums Found"
        case .songs: return "No Songs Found"
        case .genres: return "No Genres Found"
        case .search: return "No Results"
        case .notConfigured: return "Setup Required"
        case .downloads: return "No Downloads"
        case .playlists: return "No Playlists"
        case .favorites: return "No Favorites"
        case .custom(_, let title, _): return title
        }
    }
    
    var offlineTitle: String {
        switch self {
        case .artists: return "No Offline Artists"
        case .albums: return "No Downloaded Albums"
        case .songs: return "No Offline Songs"
        case .genres: return "No Offline Genres"
        case .search: return "No Downloads Found"
        case .downloads: return "No Downloads"
        case .playlists: return "No Offline Playlists"
        case .favorites: return "No Offline Favorites"
        default: return onlineTitle
        }
    }
    
    var onlineMessage: String {
        switch self {
        case .artists: return "Your music library appears to have no artists"
        case .albums: return "Your music library appears to be empty"
        case .songs: return "Your music library appears to have no songs"
        case .genres: return "Your music library appears to have no genres"
        case .search: return "Try different search terms"
        case .notConfigured: return "Please configure your Navidrome server connection in Settings"
        case .downloads: return "Download albums while online to enjoy them offline"
        case .playlists: return "Create playlists to organize your music"
        case .favorites: return "Favorite songs and albums to see them here"
        case .custom(_, _, let message): return message
        }
    }
    
    var offlineMessage: String {
        switch self {
        case .artists: return "Download some albums to see artists offline"
        case .albums: return "Download albums while online to enjoy them offline"
        case .songs: return "Download songs to listen offline"
        case .genres: return "Download albums with different genres to see them offline"
        case .search: return "No downloads found matching your search"
        case .downloads: return "Download content while connected to enjoy offline"
        case .playlists: return "Download playlists to access them offline"
        case .favorites: return "Download your favorite content for offline access"
        default: return onlineMessage
        }
    }
    
    var noConnectionMessage: String {
        switch self {
        case .artists: return "Connect to WiFi or cellular to browse your artists"
        case .albums: return "Connect to WiFi or cellular to browse your music library"
        case .songs: return "Connect to WiFi or cellular to browse songs"
        case .genres: return "Connect to WiFi or cellular to browse music genres"
        case .search: return "Connect to internet to search your music library"
        case .downloads: return "Connection required to download music"
        case .playlists: return "Connect to WiFi or cellular to access playlists"
        case .favorites: return "Connect to WiFi or cellular to access favorites"
        default: return "Connect to internet to access this content"
        }
    }
}

// MARK: - ✅ Empty State Action

struct EmptyStateAction {
    let title: String
    let action: () -> Void
    
    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }
}

// MARK: - ✅ Convenience Extensions

extension EmptyStateView {
    
    // Quick initializers for common cases
    static func artists() -> EmptyStateView {
        EmptyStateView(type: .artists)
    }
    
    static func albums() -> EmptyStateView {
        EmptyStateView(type: .albums)
    }
    
    static func genres() -> EmptyStateView {
        EmptyStateView(type: .genres)
    }
    
    static func songs() -> EmptyStateView {
        EmptyStateView(type: .songs)
    }
    
    static func notConfigured(onOpenSettings: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            type: .notConfigured,
            primaryAction: EmptyStateAction("Open Settings", action: onOpenSettings)
        )
    }
    
    static func search() -> EmptyStateView {
        EmptyStateView(type: .search)
    }
    
    static func downloads() -> EmptyStateView {
        EmptyStateView(type: .downloads)
    }
    
    static func playlists() -> EmptyStateView {
        EmptyStateView(type: .playlists)
    }
    
    static func favorites() -> EmptyStateView {
        EmptyStateView(type: .favorites)
    }
}

// MARK: - ✅ Loading View Variants

extension LoadingView {
    
    static var musicLibrary: LoadingView {
        LoadingView(
            title: "Loading...",
            subtitle: "Discovering your music library"
        )
    }
    
    static var search: LoadingView {
        LoadingView(
            title: "Searching...",
            subtitle: "Finding your music"
        )
    }
    
    static var albums: LoadingView {
        LoadingView(
            title: "Loading Albums...",
            subtitle: "Fetching your collection"
        )
    }
    
    static var artists: LoadingView {
        LoadingView(
            title: "Loading Artists...",
            subtitle: "Discovering musicians"
        )
    }
    
    static var downloading: LoadingView {
        LoadingView(
            title: "Downloading...",
            subtitle: "Preparing for offline listening"
        )
    }
}
