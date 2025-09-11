import Foundation
import SwiftUI

// MARK: - Offline Manager
@MainActor
class OfflineManager: ObservableObject {
    static let shared = OfflineManager()
    
    @Published var isOfflineMode = false
    @Published var offlineAlbums: [Album] = []
    
    private let downloadManager = DownloadManager.shared
    private let networkMonitor = NetworkMonitor.shared
    
    private init() {
        // Initial load - synchron da wir schon auf MainActor sind
        loadOfflineAlbumsSync()
        
        // Überwache Netzwerk-Änderungen
        NotificationCenter.default.addObserver(
            forName: .downloadCompleted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.loadOfflineAlbums()
            }
        }
    }
    
    private func loadOfflineAlbumsSync() {
        // Synchrone Version für init
        let downloadedAlbumIds = Set(downloadManager.downloadedAlbums.map { $0.albumId })
        offlineAlbums = AlbumMetadataCache.shared.getAlbums(ids: downloadedAlbumIds)
        print("📦 Initially loaded \(offlineAlbums.count) offline albums")
    }
    
    func loadOfflineAlbums() {
        // Async Version für Updates
        let downloadedAlbumIds = Set(downloadManager.downloadedAlbums.map { $0.albumId })
        offlineAlbums = AlbumMetadataCache.shared.getAlbums(ids: downloadedAlbumIds)
        print("📦 Loaded \(offlineAlbums.count) offline albums")
    }
    
    func switchToOfflineMode() {
        isOfflineMode = true
        loadOfflineAlbums()
    }
    
    func switchToOnlineMode() {
        isOfflineMode = false
    }
    
    func toggleOfflineMode() {
        if networkMonitor.isConnected {
            isOfflineMode.toggle()
        } else {
            isOfflineMode = true // Zwinge Offline-Modus wenn kein Netz
        }
    }
    
    // Prüfe ob ein Album offline verfügbar ist
    func isAlbumAvailableOffline(_ albumId: String) -> Bool {
        return downloadManager.isAlbumDownloaded(albumId)
    }
}
