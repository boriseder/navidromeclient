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

// MARK: - ✅ NEW: Offline Data Providers (DRY Solution)
extension OfflineManager {
    
    /// Computed property für offline verfügbare Artists
    var offlineArtists: [Artist] {
        return extractArtistsFromOfflineAlbums(offlineAlbums)
    }
    
    /// Computed property für offline verfügbare Genres
    var offlineGenres: [Genre] {
        return extractGenresFromOfflineAlbums(offlineAlbums)
    }
    
    // MARK: - Private Helper Methods
    
    private func extractArtistsFromOfflineAlbums(_ albums: [Album]) -> [Artist] {
        // Extrahiere unique Artists
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
    
    private func extractGenresFromOfflineAlbums(_ albums: [Album]) -> [Genre] {
        // Gruppiere Alben nach Genre
        let genreGroups = Dictionary(grouping: albums) { $0.genre ?? "Unknown" }
        
        return genreGroups.map { genreName, albumsInGenre in
            Genre(
                value: genreName,
                songCount: albumsInGenre.reduce(0) { $0 + ($1.songCount ?? 0) },
                albumCount: albumsInGenre.count
            )
        }.sorted { $0.value < $1.value }
    }
}

// MARK: - ✅ NEW: Convenience Methods
extension OfflineManager {
    
    /// Gibt offline verfügbare Alben für einen bestimmten Artist zurück
    func getOfflineAlbums(for artist: Artist) -> [Album] {
        return offlineAlbums.filter { $0.artist == artist.name }
    }
    
    /// Gibt offline verfügbare Alben für ein bestimmtes Genre zurück
    func getOfflineAlbums(for genre: Genre) -> [Album] {
        return offlineAlbums.filter { $0.genre == genre.value }
    }
    
    /// Prüft ob ein Artist offline verfügbar ist
    func isArtistAvailableOffline(_ artistName: String) -> Bool {
        return offlineAlbums.contains { $0.artist == artistName }
    }
    
    /// Prüft ob ein Genre offline verfügbar ist
    func isGenreAvailableOffline(_ genreName: String) -> Bool {
        return offlineAlbums.contains { $0.genre == genreName }
    }
    
    /// Gibt Statistiken über offline verfügbare Inhalte zurück
    var offlineStats: OfflineStats {
        return OfflineStats(
            albumCount: offlineAlbums.count,
            artistCount: offlineArtists.count,
            genreCount: offlineGenres.count,
            totalSongs: offlineAlbums.reduce(0) { $0 + ($1.songCount ?? 0) }
        )
    }
}

// MARK: - ✅ NEW: Stats Helper
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
