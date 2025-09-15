//
//  OfflineManager.swift - ENHANCED with Complete Reset Logic
//

import Foundation
import SwiftUI

// MARK: - Offline Manager
@MainActor
class OfflineManager: ObservableObject {
    static let shared = OfflineManager()
    
    @Published var isOfflineMode = false
    @Published var offlineAlbums: [Album] = []
    
    private let downloadManager: DownloadManager
    private let networkMonitor: NetworkMonitor
    
    private init() {
        self.downloadManager = DownloadManager.shared
        self.networkMonitor = NetworkMonitor.shared
        
        loadOfflineAlbumsSync()
        
        // Überwache Download-Änderungen
        NotificationCenter.default.addObserver(
            forName: .downloadCompleted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.loadOfflineAlbums()
            }
        }
        
        // ✅ NEW: Überwache Download-Löschungen
        NotificationCenter.default.addObserver(
            forName: .downloadDeleted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.loadOfflineAlbums()
            }
        }
    }
    
    private func loadOfflineAlbumsSync() {
        let downloadedAlbumIds = Set(downloadManager.downloadedAlbums.map { $0.albumId })
        offlineAlbums = AlbumMetadataCache.shared.getAlbums(ids: downloadedAlbumIds)
        print("📦 Initially loaded \(offlineAlbums.count) offline albums")
    }
    
    func loadOfflineAlbums() {
        let downloadedAlbumIds = Set(downloadManager.downloadedAlbums.map { $0.albumId })
        offlineAlbums = AlbumMetadataCache.shared.getAlbums(ids: downloadedAlbumIds)
        print("📦 Loaded \(offlineAlbums.count) offline albums")
    }
    
    func switchToOfflineMode() {
        isOfflineMode = true
        loadOfflineAlbums()
        objectWillChange.send() // Force UI update
    }
    
    func switchToOnlineMode() {
        isOfflineMode = false
        objectWillChange.send() // Force UI update
    }
    
    func toggleOfflineMode() {
        if networkMonitor.isConnected {
            isOfflineMode.toggle()
        } else {
            isOfflineMode = true // Zwinge Offline-Modus wenn kein Netz
        }
        objectWillChange.send() // Force UI update
    }
    
    // ✅ NEW: Complete Reset Method
    func performCompleteReset() {
        print("🔄 OfflineManager: Performing complete reset...")
        
        isOfflineMode = false
        offlineAlbums.removeAll()
        
        // Force UI update
        objectWillChange.send()
        
        print("✅ OfflineManager: Reset completed")
    }
    
    // Prüfe ob ein Album offline verfügbar ist
    func isAlbumAvailableOffline(_ albumId: String) -> Bool {
        return downloadManager.isAlbumDownloaded(albumId)
    }
    
    var offlineArtists: [Artist] {
        return extractArtistsFromOfflineAlbums(offlineAlbums)
    }
    
    var offlineGenres: [Genre] {
        return extractGenresFromOfflineAlbums(offlineAlbums)
    }
    
    private func extractArtistsFromOfflineAlbums(_ albums: [Album]) -> [Artist] {
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
        let genreGroups = Dictionary(grouping: albums) { $0.genre ?? "Unknown" }
        
        return genreGroups.map { genreName, albumsInGenre in
            Genre(
                value: genreName,
                songCount: albumsInGenre.reduce(0) { $0 + ($1.songCount ?? 0) },
                albumCount: albumsInGenre.count
            )
        }.sorted { $0.value < $1.value }
    }
    
    func getOfflineAlbums(for artist: Artist) -> [Album] {
        return offlineAlbums.filter { $0.artist == artist.name }
    }
    
    func getOfflineAlbums(for genre: Genre) -> [Album] {
        return offlineAlbums.filter { $0.genre == genre.value }
    }
    
    func isArtistAvailableOffline(_ artistName: String) -> Bool {
        return offlineAlbums.contains { $0.artist == artistName }
    }
    
    func isGenreAvailableOffline(_ genreName: String) -> Bool {
        return offlineAlbums.contains { $0.genre == genreName }
    }
    
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


