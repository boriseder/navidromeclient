//
//  AlbumsEmptyStateView.swift
//  NavidromeClient
//
//  Created by Boris Eder on 11.09.25.
//


import SwiftUI

// MARK: - Empty State
struct AlbumsEmptyStateView: View {
    let isOnline: Bool
    let isOfflineMode: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text(emptyStateTitle)
                    .font(.title2.weight(.semibold))
                
                Text(emptyStateMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if !isOnline && !isOfflineMode {
                Button("Switch to Downloaded Music") {
                    OfflineManager.shared.switchToOfflineMode()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(40)
    }
    
    private var emptyStateIcon: String {
        if !isOnline {
            return "wifi.slash"
        } else if isOfflineMode {
            return "arrow.down.circle"
        } else {
            return "music.note.house"
        }
    }
    
    private var emptyStateTitle: String {
        if !isOnline {
            return "No Connection"
        } else if isOfflineMode {
            return "No Downloaded Albums"
        } else {
            return "No Albums Found"
        }
    }
    
    private var emptyStateMessage: String {
        if !isOnline {
            return "Connect to WiFi or cellular to browse your music library"
        } else if isOfflineMode {
            return "Download albums while online to enjoy them offline"
        } else {
            return "Your music library appears to be empty"
        }
    }
}