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
        HStack(spacing: 8) {
            Image(systemName: downloadManager.isAlbumDownloaded(album.id) ? "checkmark.circle.fill" : "icloud.slash")
                .foregroundStyle(downloadManager.isAlbumDownloaded(album.id) ? .green : .orange)
            
            Text(downloadManager.isAlbumDownloaded(album.id) ? "Downloaded" : "Not Available Offline")
                .font(.caption)
                .foregroundStyle(downloadManager.isAlbumDownloaded(album.id) ? .green : .orange)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(downloadManager.isAlbumDownloaded(album.id) ? .green.opacity(0.1) : .orange.opacity(0.1))
        )
    }
}

// MARK: - Network Status Indicator für verschiedene Views
struct NetworkStatusIndicator: View {
    @StateObject private var networkMonitor = NetworkMonitor.shared
    let showText: Bool
    
    init(showText: Bool = true) {
        self.showText = showText
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: networkMonitor.isConnected ? "wifi" : "wifi.slash")
                .foregroundStyle(networkMonitor.isConnected ? .green : .red)
                .font(.caption)
            
            if showText {
                Text(networkMonitor.isConnected ? "Online" : "Offline")
                    .font(.caption)
                    .foregroundStyle(networkMonitor.isConnected ? .green : .red)
            }
        }
    }
}

// MARK: - Download Progress Ring
struct DownloadProgressRing: View {
    let progress: Double
    let size: CGFloat
    
    init(progress: Double, size: CGFloat = 24) {
        self.progress = progress
        self.size = size
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                .frame(width: size, height: size)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.blue, lineWidth: 2)
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)
            
            if progress > 0 && progress < 1 {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: size * 0.3))
                    .fontWeight(.bold)
                    .foregroundStyle(.blue)
            } else if progress >= 1 {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(.green)
            }
        }
    }
}

// MARK: - Source Indicator für Mini Player
struct SourceIndicator: View {
    let song: Song
    @StateObject private var downloadManager = DownloadManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    var body: some View {
        Group {
            if downloadManager.isSongDownloaded(song.id) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .background(Circle().fill(.green))
            } else if !networkMonitor.isConnected {
                Image(systemName: "wifi.slash")
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .background(Circle().fill(.red))
            }
        }
    }
}

// MARK: - Offline Mode Toggle Button
struct OfflineModeToggle: View {
    @StateObject private var offlineManager = OfflineManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    var body: some View {
        if networkMonitor.isConnected {
            Button(action: {
                offlineManager.toggleOfflineMode()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: offlineManager.isOfflineMode ? "icloud.slash" : "icloud")
                        .font(.caption)
                    Text(offlineManager.isOfflineMode ? "Offline" : "All")
                        .font(.caption)
                }
                .foregroundStyle(offlineManager.isOfflineMode ? .orange : .blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(offlineManager.isOfflineMode ? .orange.opacity(0.1) : .blue.opacity(0.1))
                )
            }
        }
    }
}

// MARK: - Quick Offline Access Button
struct QuickOfflineAccess: View {
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var downloadManager = DownloadManager.shared
    @StateObject private var offlineManager = OfflineManager.shared
    
    var body: some View {
        if !networkMonitor.isConnected && !downloadManager.downloadedAlbums.isEmpty {
            Button {
                offlineManager.switchToOfflineMode()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle")
                        .font(.caption)
                    Text("View Downloaded Music (\(downloadManager.downloadedAlbums.count) Albums)")
                        .font(.caption)
                }
                .foregroundStyle(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.blue.opacity(0.1), in: Capsule())
            }
        }
    }
}

#if DEBUG
// MARK: - Debug Network Test View
struct NetworkTestView: View {
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var offlineManager = OfflineManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Network Testing")
                .font(.title)
            
            HStack {
                Circle()
                    .fill(networkMonitor.isConnected ? .green : .red)
                    .frame(width: 20, height: 20)
                
                Text(networkMonitor.isConnected ? "Online" : "Offline")
                    .font(.headline)
            }
            
            Text("Connection: \(networkMonitor.connectionType)")
                .font(.caption)
            
            Divider()
            
            VStack {
                Text("Offline Manager")
                    .font(.headline)
                
                Text("Mode: \(offlineManager.isOfflineMode ? "Offline" : "Online")")
                Text("Offline Albums: \(offlineManager.offlineAlbums.count)")
                
                Button("Toggle Offline Mode") {
                    offlineManager.toggleOfflineMode()
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
        }
        .padding()
    }
}
#endif