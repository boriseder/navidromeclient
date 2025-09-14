//
//  OfflineStatusBadge.swift
//  NavidromeClient
//
//  Created by Boris Eder on 11.09.25.
//


import SwiftUI

// MARK: - Offline Status Badge für AlbumDetailView
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

// MARK: - Debug Network Test View (Enhanced with DS)
#if DEBUG
struct NetworkTestView: View {
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var offlineManager = OfflineManager.shared
    
    var body: some View {
        VStack(spacing: Spacing.l) {
            Text("Network Testing")
                .font(Typography.title)
            
            HStack {
                Circle()
                    .fill(networkMonitor.isConnected ? BrandColor.success : BrandColor.error)
                    .frame(width: Sizes.iconLarge, height: Sizes.iconLarge)
                
                Text(networkMonitor.isConnected ? "Online" : "Offline")
                    .font(Typography.headline)
            }
            
            Text("Connection: \(networkMonitor.connectionType)")
                .font(Typography.caption)
            
            Divider()
            
            VStack {
                Text("Offline Manager")
                    .font(Typography.headline)
                
                Text("Mode: \(offlineManager.isOfflineMode ? "Offline" : "Online")")
                Text("Offline Albums: \(offlineManager.offlineAlbums.count)")
                
                Button("Toggle Offline Mode") {
                    offlineManager.toggleOfflineMode()
                }
                .secondaryButtonStyle()
            }
            
            Spacer()
        }
        .padding(Padding.xl)
    }
}
#endif

