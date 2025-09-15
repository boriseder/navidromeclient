//
//  ArtistsEmptyStateView.swift
//  NavidromeClient
//
//  Created by Boris Eder on 15.09.25.
//
import SwiftUI

// MARK: - Artists Empty State View (Enhanced with DS)
struct ArtistsEmptyStateView: View {
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
            return "person.2.slash"
        } else {
            return "person.2"
        }
    }
    
    private var emptyStateTitle: String {
        if !isOnline {
            return "No Connection"
        } else if isOfflineMode {
            return "No Offline Artists"
        } else {
            return "No Artists Found"
        }
    }
    
    private var emptyStateMessage: String {
        if !isOnline {
            return "Connect to WiFi or cellular to browse your artists"
        } else if isOfflineMode {
            return "Download some albums to see artists offline"
        } else {
            return "Your music library appears to have no artists"
        }
    }
}
