//
//  GenresEmptyStateView.swift
//  NavidromeClient
//
//  Created by Boris Eder on 15.09.25.
//
import SwiftUI

// MARK: - Genres Empty State View (Enhanced with DS)
struct GenresEmptyStateView: View {
    let isOnline: Bool
    let isOfflineMode: Bool
    
    var body: some View {
        VStack(spacing: Spacing.l) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 60))
                .foregroundStyle(TextColor.secondary)
            
            VStack(spacing: Spacing.s) {
                Text(emptyStateTitle)
                    .font(Typography.title2)
                
                Text(emptyStateMessage)
                    .font(Typography.subheadline)
                    .foregroundStyle(TextColor.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if !isOnline && !isOfflineMode {
                Button("Switch to Downloaded Music") {
                    OfflineManager.shared.switchToOfflineMode()
                }
                .primaryButtonStyle()
            }
        }
        .padding(Padding.xl)
    }
    
    private var emptyStateIcon: String {
        if !isOnline {
            return "wifi.slash"
        } else if isOfflineMode {
            return "music.note.list.slash"
        } else {
            return "music.note.list"
        }
    }
    
    private var emptyStateTitle: String {
        if !isOnline {
            return "No Connection"
        } else if isOfflineMode {
            return "No Offline Genres"
        } else {
            return "No Genres Found"
        }
    }
    
    private var emptyStateMessage: String {
        if !isOnline {
            return "Connect to WiFi or cellular to browse music genres"
        } else if isOfflineMode {
            return "Download albums with different genres to see them offline"
        } else {
            return "Your music library appears to have no genres"
        }
    }
}
