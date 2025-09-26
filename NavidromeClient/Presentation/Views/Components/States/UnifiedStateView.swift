//
//  EmptyStateView.swift - UNIFIED: Complete State System Replacement
//  NavidromeClient
//
//   REPLACED: Old EmptyStateView + LoadingView (~300 LOC)
//   UNIFIED: Single elegant component for all states
//   MODERN: Glass-morphic design with proper animations
//

import SwiftUI

// MARK: - Main Unified State Component

struct UnifiedStateView: View {
    let state: ViewState
    let primaryAction: StateAction?
    let secondaryAction: StateAction?
    
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @EnvironmentObject private var offlineManager: OfflineManager
    
    init(
        state: ViewState,
        primaryAction: StateAction? = nil,
        secondaryAction: StateAction? = nil
    ) {
        self.state = state
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
    }
    
    var body: some View {
        VStack(spacing: DSLayout.screenGap) {
            stateIcon
                .padding(.top, DSLayout.screenGap)
            
            VStack(spacing: DSLayout.elementGap) {
                Text(state.title)
                    .font(DSText.itemTitle)
                    .foregroundStyle(DSColor.primary)
                    .multilineTextAlignment(.center)
                
                Text(contextualMessage)
                    .font(DSText.body)
                    .foregroundStyle(DSColor.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .padding(.horizontal, DSLayout.contentPadding)
            
            if primaryAction != nil || secondaryAction != nil {
                actionButtons
                    .padding(.top, DSLayout.elementGap)
            }
        }
        .frame(maxWidth: 400)
        .padding(DSLayout.comfortPadding)
        .background(modernGlassBackground)
        .padding(.horizontal, DSLayout.screenPadding)
    }
    
    // MARK: - State Icon with Animation
    
    @ViewBuilder
    private var stateIcon: some View {
        if case .loading = state {
            LoadingIcon()
        } else {
            StaticIcon(state: state)
        }
    }
    
    private var modernGlassBackground: some View {
        RoundedRectangle(cornerRadius: DSCorners.spacious)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: DSCorners.spacious)
                    .stroke(
                        LinearGradient(
                            colors: [
                                state.accentColor.opacity(0.2),
                                state.accentColor.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.05), radius: 20, x: 0, y: 10)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var contextualMessage: String {
        let baseMessage = state.message
        
        if !networkMonitor.isConnected {
            return state.offlineMessage ?? baseMessage
        } else if offlineManager.isOfflineMode {
            return state.offlineModeMessage ?? baseMessage
        }
        
        return baseMessage
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: DSLayout.elementGap) {
            if let primary = primaryAction {
                modernActionButton(
                    title: primary.title,
                    style: .primary,
                    action: primary.action
                )
            }
            
            if let secondary = secondaryAction {
                modernActionButton(
                    title: secondary.title,
                    style: .secondary,
                    action: secondary.action
                )
            }
        }
    }
    
    private func modernActionButton(
        title: String,
        style: ButtonStyle,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(DSText.button)
                .padding(.horizontal, DSLayout.comfortPadding)
                .padding(.vertical, DSLayout.contentPadding)
                .background(buttonBackground(style))
                .foregroundStyle(buttonForeground(style))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    private func buttonBackground(_ style: ButtonStyle) -> some View {
        Group {
            switch style {
            case .primary:
                Capsule()
                    .fill(DSColor.accent)
                    .shadow(color: DSColor.accent.opacity(0.3), radius: 8, x: 0, y: 4)
            case .secondary:
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule().stroke(DSColor.accent.opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }
    
    private func buttonForeground(_ style: ButtonStyle) -> Color {
        switch style {
        case .primary: return .white
        case .secondary: return DSColor.accent
        }
    }
    
    enum ButtonStyle {
        case primary, secondary
    }
}

// MARK: - Animated Loading Icon

struct LoadingIcon: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(DSColor.accent.opacity(0.1))
                .frame(width: 80, height: 80)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: isAnimating
                )
            
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(DSColor.accent)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(
                    .linear(duration: 2).repeatForever(autoreverses: false),
                    value: isAnimating
                )
        }
        .onAppear { isAnimating = true }
        .onDisappear { isAnimating = false }
    }
}

// MARK: - Static State Icon

struct StaticIcon: View {
    let state: ViewState
    
    var body: some View {
        ZStack {
            Circle()
                .fill(iconBackgroundGradient)
                .frame(width: 80, height: 80)
                .shadow(color: state.accentColor.opacity(0.3), radius: 12, x: 0, y: 6)
            
            Image(systemName: state.icon)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(state.accentColor)
        }
    }
    
    private var iconBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                state.accentColor.opacity(0.2),
                state.accentColor.opacity(0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - View State Enum

enum ViewState: Equatable {
    case loading(String? = nil)
    case empty(type: ContentType)
    case noConnection
    case serverError
    case unauthorized
    case noDownloads
    
    enum ContentType {
        case artists, albums, genres, songs, favorites, search
    }
    
    var icon: String {
        switch self {
        case .loading: return "arrow.triangle.2.circlepath"
        case .empty(let type): return type.icon
        case .noConnection: return "wifi.slash"
        case .serverError: return "exclamationmark.triangle"
        case .unauthorized: return "lock"
        case .noDownloads: return "arrow.down.circle"
        }
    }
    
    var title: String {
        switch self {
        case .loading(let custom): return custom ?? "Loading"
        case .empty(let type): return "No \(type.displayName) Found"
        case .noConnection: return "No Connection"
        case .serverError: return "Server Error"
        case .unauthorized: return "Authentication Required"
        case .noDownloads: return "No Downloads"
        }
    }
    
    var message: String {
        switch self {
        case .loading: return "Please wait while we load your content"
        case .empty(let type): return "Your music library appears to have no \(type.displayName.lowercased())"
        case .noConnection: return "Check your internet connection and try again"
        case .serverError: return "The server encountered an error. Please try again later"
        case .unauthorized: return "Please check your login credentials in settings"
        case .noDownloads: return "Download content while connected to enjoy it offline"
        }
    }
    
    var offlineMessage: String? {
        switch self {
        case .empty(let type): return "No downloaded \(type.displayName.lowercased()) available for offline listening"
        case .noConnection: return "Connect to WiFi or cellular to access your music library"
        default: return nil
        }
    }
    
    var offlineModeMessage: String? {
        switch self {
        case .empty(let type): return "Download some \(type.displayName.lowercased()) to see them in offline mode"
        default: return nil
        }
    }
    
    var accentColor: Color {
        switch self {
        case .loading: return DSColor.accent
        case .empty: return DSColor.secondary
        case .noConnection: return DSColor.warning
        case .serverError: return DSColor.error
        case .unauthorized: return DSColor.error
        case .noDownloads: return DSColor.info
        }
    }
}

// MARK: - Content Type Extensions

extension ViewState.ContentType {
    var icon: String {
        switch self {
        case .artists: return "person.2"
        case .albums: return "music.note.house"
        case .genres: return "music.note.list"
        case .songs: return "music.note"
        case .favorites: return "heart"
        case .search: return "magnifyingglass"
        }
    }
    
    var displayName: String {
        switch self {
        case .artists: return "Artists"
        case .albums: return "Albums"
        case .genres: return "Genres"
        case .songs: return "Songs"
        case .favorites: return "Favorites"
        case .search: return "Results"
        }
    }
}

// MARK: - State Action

struct StateAction {
    let title: String
    let action: () -> Void
    
    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }
}

// MARK: - Convenience Factory Methods

extension UnifiedStateView {
    static func loading(_ message: String? = nil) -> UnifiedStateView {
        UnifiedStateView(state: .loading(message))
    }
    
    static func empty(_ type: ViewState.ContentType) -> UnifiedStateView {
        UnifiedStateView(state: .empty(type: type))
    }
    
    static func noConnection(retry: @escaping () -> Void) -> UnifiedStateView {
        UnifiedStateView(
            state: .noConnection,
            primaryAction: StateAction("Try Again", action: retry)
        )
    }
    
    static func serverError(retry: @escaping () -> Void) -> UnifiedStateView {
        UnifiedStateView(
            state: .serverError,
            primaryAction: StateAction("Retry", action: retry)
        )
    }
    
    static func unauthorized(openSettings: @escaping () -> Void) -> UnifiedStateView {
        UnifiedStateView(
            state: .unauthorized,
            primaryAction: StateAction("Open Settings", action: openSettings)
        )
    }
}
