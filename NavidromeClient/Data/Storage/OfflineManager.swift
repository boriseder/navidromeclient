//
//  OfflineManager.swift - PHASE 4: Enhanced Reactive Updates
//  NavidromeClient
//
//   ENHANCED: Proper reactive chain notifications
//   COORDINATED: State changes with NetworkMonitor and dependent managers
//

import Foundation
import SwiftUI
import Combine

@MainActor
class OfflineManager: ObservableObject {
    static let shared = OfflineManager()
    
    // MARK: - State Machine (unchanged)
    
    enum Mode: Equatable {
        case online
        case offline(userChoice: Bool) // true = user chose, false = forced by network
        
        var isOffline: Bool {
            switch self {
            case .online: return false
            case .offline: return true
            }
        }
                
        var displayDescription: String {
            switch self {
            case .online: return "Online Mode"
            case .offline(userChoice: true): return "Offline Mode (User Choice)"
            case .offline(userChoice: false): return "Offline Mode (No Connection)"
            }
        }
    }
    
    @Published private(set) var currentMode: Mode = .online
    
    // MARK: - Offline Data (unchanged)
    
    var offlineAlbums: [Album] {
        let downloadedAlbumIds = Set(downloadManager.downloadedAlbums.map { $0.albumId })
        return AlbumMetadataCache.shared.getAlbums(ids: downloadedAlbumIds)
    }
    
    var offlineArtists: [Artist] {
        extractUniqueArtists(from: offlineAlbums)
    }
    
    var offlineGenres: [Genre] {
        extractUniqueGenres(from: offlineAlbums)
    }
    
    // MARK: - Dependencies (unchanged)
    
    private let downloadManager = DownloadManager.shared
    private let networkMonitor = NetworkMonitor.shared
    
    private init() {
        observeNetworkChanges()
        observeDownloadChanges()
    }
    
    // MARK: - Public API (enhanced with coordination)
    
    func switchToOnlineMode() {
        guard networkMonitor.isConnected && networkMonitor.canLoadOnlineContent else {
            print("⚠️ Cannot switch to online: network unavailable")
            return
        }
        
        print("🌐 Switching to online mode")
        currentMode = .online
        notifyModeChange()
    }

    func switchToOfflineMode() {
        print("📱 Switching to offline mode (user choice)")
        currentMode = .offline(userChoice: true)
        notifyModeChange()
    }
    
    func toggleOfflineMode() {
        switch currentMode {
        case .online:
            switchToOfflineMode()
        case .offline(userChoice: true):
            switchToOnlineMode()
        case .offline:
            print("⚠️ Cannot switch to online: network unavailable")
        }
    }
    
    func handleNetworkLoss() {
        if case .online = currentMode {
            print("📵 Network lost - forcing offline mode")
            currentMode = .offline(userChoice: false)
            notifyModeChange()
        }
    }
    
    func handleNetworkRestored() {
        if case .offline(userChoice: false) = currentMode {
            print("📶 Network restored - switching back to online mode")
            currentMode = .online
            notifyModeChange()
        }
    }
    
    // MARK: - Convenience Properties (unchanged)
    
    var isOfflineMode: Bool {
        currentMode.isOffline
    }
    
    // MARK: - Album/Artist/Genre Queries (unchanged)
    
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
    
    // MARK: - Statistics (unchanged)
    
    var offlineStats: OfflineStats {
        return OfflineStats(
            albumCount: offlineAlbums.count,
            artistCount: offlineArtists.count,
            genreCount: offlineGenres.count,
            totalSongs: offlineAlbums.reduce(0) { $0 + ($1.songCount ?? 0) }
        )
    }
    
    // MARK: - Reset (unchanged)
    
    func performCompleteReset() {
        print("🔄 OfflineManager: Performing complete reset...")
        
        currentMode = .online
        objectWillChange.send()
        
        print("✅ OfflineManager: Reset completed")
    }
    
    // MARK: - PHASE 4: Enhanced Reactive Updates
    
    private func notifyModeChange() {
        // PHASE 4: Trigger reactive updates in proper order
        objectWillChange.send()
        
        // Notify NetworkMonitor to trigger its reactive chain
        Task { @MainActor in
            networkMonitor.objectWillChange.send()
            
            // Notify MusicLibraryManager for data source changes
            MusicLibraryManager.shared.objectWillChange.send()
            
            // Notify dependent managers that might need to update their state
            await notifyDependentManagers()
        }
        
        // Send system notification for any remaining observers
        NotificationCenter.default.post(
            name: .offlineModeChanged,
            object: currentMode
        )
        
        print("🔄 Offline mode change notifications sent: \(currentMode.displayDescription)")
    }
    
    private func notifyDependentManagers() async {
        // Trigger any manager-specific updates based on offline mode change
        // This ensures all UI components get updated consistently
        
        // Example: If we had other managers that need to know about offline state
        // they would be notified here to maintain consistency
    }
    
    // MARK: - Private Implementation (unchanged)
    
    private func observeNetworkChanges() {
        networkMonitor.$isConnected
            .sink { [weak self] isConnected in
                if isConnected {
                    self?.handleNetworkRestored()
                } else {
                    self?.handleNetworkLoss()
                }
            }
            .store(in: &cancellables)
        
        networkMonitor.$canLoadOnlineContent
            .sink { [weak self] canLoad in
                if !canLoad && self?.currentMode == .online {
                    self?.handleNetworkLoss()
                } else if canLoad {
                    self?.handleNetworkRestored()
                }
            }
            .store(in: &cancellables)
    }
    
    private func observeDownloadChanges() {
        NotificationCenter.default.addObserver(
            forName: .downloadCompleted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.objectWillChange.send()
        }
        
        NotificationCenter.default.addObserver(
            forName: .downloadDeleted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
    
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

// MARK: - Supporting Types (unchanged)

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

// MARK: - Notification Names (unchanged)
extension Notification.Name {
    static let offlineModeChanged = Notification.Name("offlineModeChanged")
}

extension Notification.Name {
    static let servicesNeedInitialization = Notification.Name("servicesNeedInitialization")
}
