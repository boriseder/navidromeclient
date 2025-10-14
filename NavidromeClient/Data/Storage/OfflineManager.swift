//
//  OfflineManager.swift - REFACTORED: Simplified to Data Coordinator
//  NavidromeClient
//
//   SIMPLIFIED: No longer manages content loading strategy
//   DELEGATES: All strategy decisions to NetworkMonitor
//   FOCUSED: Pure offline data management and UI state tracking
//

import Foundation
import SwiftUI
import Combine

@MainActor
class OfflineManager: ObservableObject {
    static let shared = OfflineManager()
    
    // MARK: - Offline Data Management (Core Responsibility)
    
    // Cached offline albums list - updated only when downloads change
    private var cachedOfflineAlbums: [Album] = []
    private var cacheNeedsRefresh = true
    
    var offlineAlbums: [Album] {
        if cacheNeedsRefresh {
            let downloadedAlbumIds = Set(downloadManager.downloadedAlbums.map { $0.albumId })
            cachedOfflineAlbums = AlbumMetadataCache.shared.getAlbums(ids: downloadedAlbumIds)
            cacheNeedsRefresh = false
        }
        return cachedOfflineAlbums
    }
    
    var offlineArtists: [Artist] {
        extractUniqueArtists(from: offlineAlbums)
    }
    
    var offlineGenres: [Genre] {
        extractUniqueGenres(from: offlineAlbums)
    }
    
    // MARK: - Dependencies
    
    private let downloadManager = DownloadManager.shared
    private let networkMonitor = NetworkMonitor.shared
    
    private init() {
        observeDownloadChanges()
        setupFactoryResetObserver()
    }
    
    // MARK: - Public API (Delegates to NetworkMonitor)
    
    func switchToOnlineMode() {
        networkMonitor.setManualOfflineMode(false)
        print("🌐 Requested switch to online mode")
    }

    func switchToOfflineMode() {
        networkMonitor.setManualOfflineMode(true)
        print("📱 Requested switch to offline mode")
    }
    
    func toggleOfflineMode() {
        let currentStrategy = networkMonitor.contentLoadingStrategy
        
        switch currentStrategy {
        case .online:
            switchToOfflineMode()
        case .offlineOnly(let reason):
            switch reason {
            case .userChoice:
                switchToOnlineMode()
            case .noNetwork, .serverUnreachable:
                print("⚠️ Cannot switch to online: \(reason.message)")
            }
        case .setupRequired:
            print("⚠️ Cannot toggle offline mode: Server setup required")
        }
    }
    
    // MARK: - UI State Properties (Read-Only)
    
    
    /// Legacy compatibility: check if app is in offline mode
    var isOfflineMode: Bool {
        return !networkMonitor.shouldLoadOnlineContent
    }
    
    // MARK: - Network Change Handling (Simplified)
    
    func handleNetworkLoss() {
        // NetworkMonitor handles the strategy change
        // OfflineManager just logs for UI feedback
        print("📵 Network lost - NetworkMonitor will handle strategy")
    }
    
    func handleNetworkRestored() {
        // NetworkMonitor handles the strategy change
        // OfflineManager just logs for UI feedback
        print("📶 Network restored - NetworkMonitor will handle strategy")
    }
    
    // MARK: - Album/Artist/Genre Queries (Unchanged)
    
    func getOfflineAlbums(for artist: Artist) -> [Album] {
        return offlineAlbums.filter { $0.artist == artist.name }
    }
    
    func getOfflineAlbums(for genre: Genre) -> [Album] {
        return offlineAlbums.filter { $0.genre == genre.value }
    }
    
    func isAlbumAvailableOffline(_ albumId: String) -> Bool {
        return downloadManager.isAlbumDownloaded(albumId)
    }
    
    func isArtistAvailableOffline(_ artistName: String) -> Bool {
        return offlineAlbums.contains { $0.artist == artistName }
    }
    
    func isGenreAvailableOffline(_ genreName: String) -> Bool {
        return offlineAlbums.contains { $0.genre == genreName }
    }
    
    // MARK: - Statistics (Unchanged)
    
    var offlineStats: OfflineStats {
        return OfflineStats(
            albumCount: offlineAlbums.count,
            artistCount: offlineArtists.count,
            genreCount: offlineGenres.count,
            totalSongs: offlineAlbums.reduce(0) { $0 + ($1.songCount ?? 0) }
        )
    }
    
    // MARK: - Reset
    
    func performCompleteReset() {
        // Clear cache
        cachedOfflineAlbums = []
        cacheNeedsRefresh = true
        
        // Clear subscriptions
        cancellables.removeAll()
        
        // Data is owned by DownloadManager and AlbumMetadataCache
        print("🔄 OfflineManager: Reset completed")
    }
    
    // MARK: - Reactive Updates
    
    private func setupFactoryResetObserver() {
        NotificationCenter.default.addObserver(
            forName: .factoryResetRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.performCompleteReset()
        }
    }
    
    private func observeDownloadChanges() {
        // Only observe download changes for data updates
        NotificationCenter.default.addObserver(
            forName: .downloadCompleted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.cacheNeedsRefresh = true
            self?.objectWillChange.send()
        }
        
        NotificationCenter.default.addObserver(
            forName: .downloadDeleted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.cacheNeedsRefresh = true
            self?.objectWillChange.send()
        }
        
        // NO need to observe NetworkMonitor: views that depend on network state
        // already observe NetworkMonitor directly. OfflineManager only manages
        // offline data, which changes when downloads change (handled above).
    }
    
    // MARK: - Private Implementation (Unchanged)
    
    private func extractUniqueArtists(from albums: [Album]) -> [Artist] {
        let uniqueArtists = Set(albums.map { $0.artist })
        
        return uniqueArtists.compactMap { artistName in
            Artist(
                id: artistName.replacingOccurrences(of: " ", with: "_"),
                name: artistName,
                coverArt: nil,
                albumCount: albums.filter { $0.artist == artistName }.count,
                artistImageUrl: nil
            )
        }.sorted { $0.name < $1.name }
    }
    
    private func extractUniqueGenres(from albums: [Album]) -> [Genre] {
        let genreGroups = Dictionary(grouping: albums) { $0.genre ?? "Unknown" }
        
        return genreGroups.map { genreName, albumsInGenre in
            Genre(
                value: genreName,
                songCount: albumsInGenre.reduce(0) { $0 + ($1.songCount ?? 0) },
                albumCount: albumsInGenre.count
            )
        }.sorted { $0.value < $1.value }
    }
    
    private var cancellables = Set<AnyCancellable>()
}

// MARK: - Supporting Types (Unchanged)

struct OfflineStats {
    let albumCount: Int
    let artistCount: Int
    let genreCount: Int
    let totalSongs: Int
    
    var isEmpty: Bool {
        return albumCount == 0
    }
    
    var summary: String {
        if isEmpty {
            return "No offline content"
        }
        
        var parts: [String] = []
        if albumCount > 0 { parts.append("\(albumCount) albums") }
        if artistCount > 0 { parts.append("\(artistCount) artists") }
        if genreCount > 0 { parts.append("\(genreCount) genres") }
        
        return parts.joined(separator: ", ")
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let offlineModeChanged = Notification.Name("offlineModeChanged") // Legacy - not used anymore
    static let servicesNeedInitialization = Notification.Name("servicesNeedInitialization")
    static let factoryResetRequested = Notification.Name("factoryResetRequested")
}
