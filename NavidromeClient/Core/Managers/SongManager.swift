//
//  SongManager.swift - MIGRATED to ContentService
//  NavidromeClient
//
//  ✅ MIGRATION COMPLETE: SubsonicService → ContentService
//  ✅ ALL SERVICE CALLS UPDATED
//

import Foundation
import SwiftUI

@MainActor
class SongManager: ObservableObject {
    
    // MARK: - ✅ SONG CACHE (unchanged)
    
    @Published private(set) var albumSongs: [String: [Song]] = [:]
    @Published private(set) var isLoadingSongs: [String: Bool] = [:]
    
    // ✅ MIGRATION: ContentService dependency
    private weak var contentService: ContentService?
    private let downloadManager: DownloadManager
    
    // MARK: - ✅ INITIALIZATION (unchanged)
    
    init(downloadManager: DownloadManager = DownloadManager.shared) {
        self.downloadManager = downloadManager
    }
    
    // MARK: - ✅ MIGRATION: New configuration method
    
    func configure(contentService: ContentService) {
        self.contentService = contentService
        print("✅ SongManager configured with ContentService")
    }
    
    // MARK: - ✅ PRIMARY API: Smart Song Loading (unchanged logic, updated service calls)
    
    /// Load songs for album with intelligent offline/online fallback
    func loadSongs(for albumId: String) async -> [Song] {
        // Return cached if available (unchanged)
        if let cached = albumSongs[albumId], !cached.isEmpty {
            print("📋 Using cached songs for album \(albumId): \(cached.count) songs")
            return cached
        }
        
        // Prevent duplicate loading (unchanged)
        if isLoadingSongs[albumId] == true {
            print("⏳ Already loading songs for album \(albumId), waiting...")
            while isLoadingSongs[albumId] == true {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
            return albumSongs[albumId] ?? []
        }
        
        isLoadingSongs[albumId] = true
        defer { isLoadingSongs[albumId] = false }
        
        // Try offline first if available (unchanged)
        if downloadManager.isAlbumDownloaded(albumId) {
            print("📱 Loading offline songs for album \(albumId)")
            let offlineSongs = await loadOfflineSongs(for: albumId)
            if !offlineSongs.isEmpty {
                albumSongs[albumId] = offlineSongs
                return offlineSongs
            }
        }
        
        // Try online if available (unchanged logic, updated service call)
        if NetworkMonitor.shared.canLoadOnlineContent && !OfflineManager.shared.isOfflineMode {
            print("🌐 Loading online songs for album \(albumId)")
            let onlineSongs = await loadOnlineSongs(for: albumId)
            if !onlineSongs.isEmpty {
                albumSongs[albumId] = onlineSongs
                return onlineSongs
            }
        }
        
        // Final fallback to offline (unchanged)
        print("📱 Final fallback to offline songs for album \(albumId)")
        let fallbackSongs = await loadOfflineSongs(for: albumId)
        if !fallbackSongs.isEmpty {
            albumSongs[albumId] = fallbackSongs
        }
        
        return fallbackSongs
    }
    
    // MARK: - ✅ CACHE MANAGEMENT (unchanged)
    
    /// Get cached songs immediately (no loading)
    func getCachedSongs(for albumId: String) -> [Song]? {
        return albumSongs[albumId]
    }
    
    /// Check if songs are cached
    func hasCachedSongs(for albumId: String) -> Bool {
        return albumSongs[albumId] != nil && !albumSongs[albumId]!.isEmpty
    }
    
    /// Preload songs for multiple albums
    func preloadSongs(for albumIds: [String]) async {
        await withTaskGroup(of: Void.self) { group in
            for albumId in albumIds.prefix(5) { // Limit to 5 concurrent loads
                group.addTask {
                    _ = await self.loadSongs(for: albumId)
                }
            }
        }
    }
    
    /// Clear all cached songs
    func clearSongCache() {
        let cacheSize = albumSongs.count
        albumSongs.removeAll()
        isLoadingSongs.removeAll()
        print("🧹 Cleared song cache (\(cacheSize) albums)")
    }
    
    /// Clear cache for specific album
    func clearCache(for albumId: String) {
        albumSongs.removeValue(forKey: albumId)
        isLoadingSongs.removeValue(forKey: albumId)
        print("🧹 Cleared cache for album \(albumId)")
    }
    
    // MARK: - ✅ STATISTICS (unchanged)
    
    /// Get total number of cached songs
    func getCachedSongCount() -> Int {
        return albumSongs.values.reduce(0) { $0 + $1.count }
    }
    
    /// Get cache statistics
    func getCacheStats() -> SongCacheStats {
        let totalCachedSongs = getCachedSongCount()
        let cachedAlbums = albumSongs.count
        let offlineAlbums = downloadManager.downloadedAlbums.count
        let offlineSongs = downloadManager.downloadedAlbums.reduce(0) { $0 + $1.songs.count }
        
        return SongCacheStats(
            totalCachedSongs: totalCachedSongs,
            cachedAlbums: cachedAlbums,
            offlineAlbums: offlineAlbums,
            offlineSongs: offlineSongs
        )
    }
    
    /// Check if album has offline songs available
    func hasSongsAvailableOffline(for albumId: String) -> Bool {
        return downloadManager.isAlbumDownloaded(albumId)
    }
    
    /// Get offline song count for album
    func getOfflineSongCount(for albumId: String) -> Int {
        return downloadManager.getDownloadedSongs(for: albumId).count
    }
    
    // MARK: - ✅ MIGRATION: Online song loading with ContentService
    
    /// Load songs from online service
    private func loadOnlineSongs(for albumId: String) async -> [Song] {
        // ✅ MIGRATION: ContentService guard
        guard let contentService = contentService else {
            print("❌ ContentService not available for online song loading")
            return []
        }
        
        do {
            // ✅ MIGRATION: ContentService call
            let songs = try await contentService.getSongs(for: albumId)
            print("✅ Loaded \(songs.count) online songs for album \(albumId) via ContentService")
            return songs
        } catch {
            print("⚠️ Failed to load online songs for album \(albumId) via ContentService: \(error)")
            return []
        }
    }
    
    // MARK: - ✅ PRIVATE IMPLEMENTATION (unchanged - no service calls)
    
    /// Load songs from offline storage with smart fallback
    private func loadOfflineSongs(for albumId: String) async -> [Song] {
        // Try downloaded songs with full metadata first (unchanged)
        let downloadedSongs = downloadManager.getDownloadedSongs(for: albumId)
        if !downloadedSongs.isEmpty {
            let songs = downloadedSongs.map { $0.toSong() }
            print("✅ Loaded \(songs.count) offline songs with full metadata for album \(albumId)")
            return songs
        }
        
        // Fallback to legacy downloaded albums (unchanged)
        guard let legacyAlbum = downloadManager.downloadedAlbums.first(where: { $0.albumId == albumId }) else {
            print("⚠️ Album \(albumId) not found in downloads")
            return []
        }
        
        // Get album metadata for better fallback (unchanged)
        let albumMetadata = AlbumMetadataCache.shared.getAlbum(id: albumId)
        
        // Create songs from legacy song IDs (unchanged)
        let fallbackSongs = legacyAlbum.songIds.enumerated().map { index, songId in
            Song.createFromDownload(
                id: songId,
                title: generateFallbackTitle(index: index, songId: songId, albumMetadata: albumMetadata),
                duration: nil,
                coverArt: albumId,
                artist: albumMetadata?.artist ?? "Unknown Artist",
                album: albumMetadata?.name ?? "Unknown Album",
                albumId: albumId,
                track: index + 1,
                year: albumMetadata?.year,
                genre: albumMetadata?.genre,
                contentType: "audio/mpeg"
            )
        }
        
        print("✅ Created \(fallbackSongs.count) fallback songs for legacy album \(albumId)")
        return fallbackSongs
    }
    
    /// Generate smart fallback titles for songs (unchanged)
    private func generateFallbackTitle(index: Int, songId: String, albumMetadata: Album?) -> String {
        let trackNumber = String(format: "%02d", index + 1)
        
        // If songId looks like a hash, use generic title (unchanged)
        if songId.count > 10 && songId.allSatisfy({ $0.isHexDigit }) {
            return "Track \(trackNumber)"
        }
        
        // Try to clean up songId as title (unchanged)
        let cleanTitle = songId
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
        
        // Use album name as prefix if available and title is too generic (unchanged)
        if let albumName = albumMetadata?.name,
           cleanTitle.count < 5 {
            return "\(albumName) - Track \(trackNumber)"
        }
        
        return cleanTitle.isEmpty ? "Track \(trackNumber)" : cleanTitle
    }
    
    // MARK: - ✅ RESET (unchanged)
    
    func reset() {
        albumSongs.removeAll()
        isLoadingSongs.removeAll()
        print("✅ SongManager reset completed")
    }
}

// MARK: - ✅ SUPPORTING TYPES (unchanged)

struct SongCacheStats {
    let totalCachedSongs: Int
    let cachedAlbums: Int
    let offlineAlbums: Int
    let offlineSongs: Int
    
    var cacheHitRate: Double {
        guard offlineSongs > 0 else { return 0 }
        return Double(totalCachedSongs) / Double(offlineSongs) * 100
    }
    
    var summary: String {
        return "Cached: \(cachedAlbums) albums (\(totalCachedSongs) songs), Offline: \(offlineAlbums) albums (\(offlineSongs) songs)"
    }
}

// MARK: - ✅ HELPER EXTENSIONS (unchanged)

extension Character {
    var isHexDigit: Bool {
        return self.isNumber || ("a"..."f").contains(self.lowercased()) || ("A"..."F").contains(self)
    }
}

// MARK: - ✅ BATCH OPERATIONS SUPPORT (unchanged - no direct service calls)

extension SongManager {
    
    /// Load songs for artist (all albums)
    func loadSongsForArtist(_ artist: Artist) async -> [Song] {
        // This would need MusicLibraryManager to get artist's albums
        // For now, return empty - will be handled in coordination layer
        return []
    }
    
    /// Load songs for genre (all albums in genre)
    func loadSongsForGenre(_ genre: Genre) async -> [Song] {
        // This would need MusicLibraryManager to get genre's albums
        // For now, return empty - will be handled in coordination layer
        return []
    }
    
    /// Warm up cache for visible albums
    func warmUpCache(for albumIds: [String]) async {
        let uncachedAlbums = albumIds.filter { !hasCachedSongs(for: $0) }
        
        if !uncachedAlbums.isEmpty {
            print("🔥 Warming up cache for \(uncachedAlbums.count) albums via ContentService")
            await preloadSongs(for: Array(uncachedAlbums.prefix(3))) // Limit concurrent loads
        }
    }
}
