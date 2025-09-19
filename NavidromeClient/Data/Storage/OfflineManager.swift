//
//  OfflineManager.swift - ENHANCED with Single Source of Truth
//  NavidromeClient
//
//   FIXED: offlineAlbums as computed property eliminates state duplication
//   PRESERVED: All public API methods for Views
//

import Foundation
import SwiftUI

@MainActor
class OfflineManager: ObservableObject {
    static let shared = OfflineManager()
    
    @Published var isOfflineMode = false
    
    // ✅ SINGLE SOURCE OF TRUTH: Computed property
    var offlineAlbums: [Album] {
        let downloadedAlbumIds = Set(downloadManager.downloadedAlbums.map { $0.albumId })
        return AlbumMetadataCache.shared.getAlbums(ids: downloadedAlbumIds)
    }
    
    private let downloadManager: DownloadManager
    private let networkMonitor: NetworkMonitor
    
    private init() {
        self.downloadManager = DownloadManager.shared
        self.networkMonitor = NetworkMonitor.shared
        
        // ✅ NO SYNCHRONIZATION NEEDED
        print("📦 OfflineManager initialized with computed offlineAlbums")
    }

    // ✅ PRESERVED: All public API methods unchanged
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
    
    func isAlbumAvailableOffline(_ albumId: String) -> Bool {
        return downloadManager.isAlbumDownloaded(albumId)
    }
    
    // ✅ PRESERVED: Computed properties with single evaluation for performance
    var offlineArtists: [Artist] {
        return extractArtistsFromOfflineAlbums(offlineAlbums)
    }
    
    var offlineGenres: [Genre] {
        return extractGenresFromOfflineAlbums(offlineAlbums)
    }
    
    var offlineStats: OfflineStats {
        let albums = offlineAlbums // Single evaluation
        return OfflineStats(
            albumCount: albums.count,
            artistCount: Set(albums.map { $0.artist }).count,
            genreCount: Set(albums.compactMap { $0.genre }).count,
            totalSongs: albums.reduce(0) { $0 + ($1.songCount ?? 0) }
        )
    }
    
    // ✅ PRESERVED: Mode switching methods unchanged
    func switchToOfflineMode() {
        isOfflineMode = true
        objectWillChange.send()
    }
    
    func switchToOnlineMode() {
        isOfflineMode = false
        objectWillChange.send()
    }
    
    func toggleOfflineMode() {
        if networkMonitor.isConnected {
            isOfflineMode.toggle()
        } else {
            isOfflineMode = true // Force offline mode when no network
        }
        objectWillChange.send()
    }
    
    // ✅ SIMPLIFIED: Reset method without manual array clearing
    func performCompleteReset() {
        print("🔄 OfflineManager: Performing complete reset...")
        
        isOfflineMode = false
        // ✅ ELIMINATED: offlineAlbums.removeAll() - computed property updates automatically
        
        // Force UI update
        objectWillChange.send()
        
        print("✅ OfflineManager: Reset completed")
    }
    
    // ✅ PRESERVED: Helper methods unchanged
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
}

// MARK: - Stats Helper (UNCHANGED)
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
