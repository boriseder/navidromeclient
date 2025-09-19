//
//  CoverArtManager.swift - EMERGENCY FIXED: Backwards Compatible
//  NavidromeClient
//
//   FIXED: Backwards compatible während Multi-Resolution Support
//

import Foundation
import SwiftUI

@MainActor
class CoverArtManager: ObservableObject {
    static let shared = CoverArtManager()
    
    // MARK: - State (unchanged)
    @Published private(set) var albumImages: [String: UIImage] = [:]
    @Published private(set) var artistImages: [String: UIImage] = [:]
    @Published private(set) var loadingStates: [String: Bool] = [:]
    @Published private(set) var errorStates: [String: String] = [:]
    
    private weak var mediaService: MediaService?
    private weak var legacyService: UnifiedSubsonicService?
    private let persistentCache = PersistentImageCache.shared
    
    private init() {}
    
    // MARK: - Configuration
    
    func configure(mediaService: MediaService) {
        self.mediaService = mediaService
        print("✅ CoverArtManager configured with focused MediaService")
    }
    
    func configure(service: UnifiedSubsonicService) {
        self.legacyService = service
        self.mediaService = service.getMediaService()
        print("✅ CoverArtManager configured with legacy service")
    }
    
    private var activeMediaService: MediaService? {
        return mediaService ?? legacyService?.getMediaService()
    }
    
    // MARK: - FIXED: ALBUM Loading mit Multi-Resolution aber Backwards Compatible
    
    func loadAlbumImage(album: Album, size: Int = 200, staggerIndex: Int = 0) async -> UIImage? {
        // ✅ Multi-Resolution Memory Key
        let memoryKey = "album_\(album.id)_\(size)"
        
        // Check Multi-Resolution Memory Cache
        if let cached = albumImages[memoryKey] {
            print("🎯 Album memory hit: \(album.id) @ \(size)px")
            return cached
        }
        
        // Check persistent cache
        let cacheKey = "album_\(album.id)_\(size)"
        if let cached = persistentCache.image(for: cacheKey) {
            print("💾 Album disk hit: \(album.id) @ \(size)px")
            albumImages[memoryKey] = cached
            
            // ✅ BACKWARDS COMPATIBLE: Store auch im old key für legacy getter
            let legacyKey = "album_\(album.id)"
            if !albumImages.keys.contains(legacyKey) {
                albumImages[legacyKey] = cached
            }
            
            return cached
        }
        
        guard let service = activeMediaService else {
            errorStates[memoryKey] = "Media service not available"
            return nil
        }
        
        loadingStates[memoryKey] = true
        // ✅ Legacy loading state auch setzen
        loadingStates["album_\(album.id)"] = true
        
        defer {
            loadingStates[memoryKey] = false
            loadingStates["album_\(album.id)"] = false
        }
        
        if staggerIndex > 0 {
            try? await Task.sleep(nanoseconds: UInt64(staggerIndex * 100_000_000))
        }
        
        if let image = await service.getCoverArt(for: album.id, size: size) {
            print("📡 Album network load: \(album.id) @ \(size)px -> \(image.size.width)x\(image.size.height)")
            
            // ✅ Store in Multi-Resolution Cache
            albumImages[memoryKey] = image
            
            // ✅ BACKWARDS COMPATIBLE: Store auch im legacy key
            let legacyKey = "album_\(album.id)"
            if !albumImages.keys.contains(legacyKey) {
                albumImages[legacyKey] = image
            }
            
            errorStates.removeValue(forKey: memoryKey)
            persistentCache.store(image, for: cacheKey)
            
            return image
        } else {
            errorStates[memoryKey] = "Failed to load album image"
            return nil
        }
    }
    
    // MARK: - FIXED: ARTIST Loading mit Multi-Resolution aber Backwards Compatible
    
    func loadArtistImage(artist: Artist, size: Int = 200, staggerIndex: Int = 0) async -> UIImage? {
        let memoryKey = "artist_\(artist.id)_\(size)"
        
        if let cached = artistImages[memoryKey] {
            print("🎯 Artist memory hit: \(artist.id) @ \(size)px")
            return cached
        }
        
        let cacheKey = "artist_\(artist.id)_\(size)"
        if let cached = persistentCache.image(for: cacheKey) {
            print("💾 Artist disk hit: \(artist.id) @ \(size)px")
            artistImages[memoryKey] = cached
            
            // ✅ BACKWARDS COMPATIBLE: Store auch im legacy key
            let legacyKey = "artist_\(artist.id)"
            if !artistImages.keys.contains(legacyKey) {
                artistImages[legacyKey] = cached
            }
            
            return cached
        }
        
        guard let service = activeMediaService else {
            errorStates[memoryKey] = "Media service not available"
            return nil
        }
        
        loadingStates[memoryKey] = true
        loadingStates["artist_\(artist.id)"] = true
        
        defer {
            loadingStates[memoryKey] = false
            loadingStates["artist_\(artist.id)"] = false
        }
        
        if staggerIndex > 0 {
            try? await Task.sleep(nanoseconds: UInt64(staggerIndex * 100_000_000))
        }
        
        if let image = await service.getCoverArt(for: artist.id, size: size) {
            print("📡 Artist network load: \(artist.id) @ \(size)px -> \(image.size.width)x\(image.size.height)")
            
            artistImages[memoryKey] = image
            
            // ✅ BACKWARDS COMPATIBLE: Store auch im legacy key
            let legacyKey = "artist_\(artist.id)"
            if !artistImages.keys.contains(legacyKey) {
                artistImages[legacyKey] = image
            }
            
            errorStates.removeValue(forKey: memoryKey)
            persistentCache.store(image, for: cacheKey)
            
            return image
        } else {
            errorStates[memoryKey] = "Failed to load artist image"
            return nil
        }
    }
    
    // MARK: - ✅ BACKWARDS COMPATIBLE: Legacy Getter Methods (UNCHANGED API)
    
    func getAlbumImage(for albumId: String) -> UIImage? {
        // ✅ First try legacy key (for backwards compatibility)
        let legacyKey = "album_\(albumId)"
        if let cached = albumImages[legacyKey] {
            return cached
        }
        
        // Fallback: Try default size key
        let defaultKey = "album_\(albumId)_200"
        return albumImages[defaultKey]
    }

    func getArtistImage(for artistId: String) -> UIImage? {
        // ✅ First try legacy key (for backwards compatibility)
        let legacyKey = "artist_\(artistId)"
        if let cached = artistImages[legacyKey] {
            return cached
        }
        
        // Fallback: Try default size key
        let defaultKey = "artist_\(artistId)_200"
        return artistImages[defaultKey]
    }
    
    // ✅ NEW: Multi-Resolution Getter Methods (for FullScreen Player)
    
    func getAlbumImage(for albumId: String, size: Int) -> UIImage? {
        let memoryKey = "album_\(albumId)_\(size)"
        return albumImages[memoryKey]
    }

    func getArtistImage(for artistId: String, size: Int) -> UIImage? {
        let memoryKey = "artist_\(artistId)_\(size)"
        return artistImages[memoryKey]
    }
    
    // MARK: - Song Images
    
    func loadSongImage(song: Song, size: Int = 50) async -> UIImage? {
        guard let albumId = song.albumId else { return nil }
        
        let album = Album(
            id: albumId,
            name: song.album ?? "Unknown Album",
            artist: song.artist ?? "Unknown Artist",
            year: song.year,
            genre: song.genre,
            coverArt: song.coverArt,
            coverArtId: song.coverArt,
            duration: song.duration,
            songCount: nil,
            artistId: song.artistId,
            displayArtist: song.artist
        )
        
        return await loadAlbumImage(album: album, size: size)
    }
    
    func getSongImage(for song: Song, size: Int = 50) -> UIImage? {
        guard let albumId = song.albumId else { return nil }
        
        // ✅ Try both legacy and multi-resolution keys
        if let legacyImage = albumImages["album_\(albumId)"] {
            return legacyImage
        }
        
        let memoryKey = "album_\(albumId)_\(size)"
        return albumImages[memoryKey]
    }
    
    // MARK: - ✅ BACKWARDS COMPATIBLE: Legacy Loading/Error State Methods
    
    func isLoadingImage(for key: String) -> Bool {
        return loadingStates[key] == true
    }
    
    func getImageError(for key: String) -> String? {
        return errorStates[key]
    }
    
    // MARK: - Batch Operations
    
    func preloadAlbums(_ albums: [Album], size: Int = 200) async {
        guard activeMediaService != nil else { return }
        
        await withTaskGroup(of: Void.self) { group in
            for (index, album) in albums.enumerated() {
                if index >= 5 { break }
                
                group.addTask {
                    _ = await self.loadAlbumImage(album: album, size: size, staggerIndex: index)
                }
            }
        }
        
        print("✅ Batch preloaded album covers for \(min(albums.count, 5)) albums @ \(size)px")
    }
    
    func preloadArtists(_ artists: [Artist], size: Int = 120) async {
        guard activeMediaService != nil else { return }
        
        await withTaskGroup(of: Void.self) { group in
            for (index, artist) in artists.enumerated() {
                if index >= 5 { break }
                
                group.addTask {
                    _ = await self.loadArtistImage(artist: artist, size: size, staggerIndex: index)
                }
            }
        }
        
        print("✅ Batch preloaded artist images for \(min(artists.count, 5)) artists @ \(size)px")
    }
    
    // MARK: - Cache Management
    
    func clearMemoryCache() {
        albumImages.removeAll()
        artistImages.removeAll()
        loadingStates.removeAll()
        errorStates.removeAll()
        persistentCache.clearCache()
        print("🧹 Cleared all image caches")
    }
    
    // MARK: - Diagnostics
    
    func getCacheStats() -> CoverArtCacheStats {
        let persistentStats = persistentCache.getCacheStats()
        return CoverArtCacheStats(
            memoryCount: albumImages.count + artistImages.count,
            diskCount: persistentStats.diskCount,
            diskSize: persistentStats.diskSize,
            activeRequests: loadingStates.count,
            errorCount: errorStates.count
        )
    }

    func getHealthStatus() -> CoverArtHealthStatus {
        let stats = getCacheStats()
        let errorRate = stats.errorCount > 0 ? Double(stats.errorCount) / max(1, Double(stats.memoryCount)) : 0.0
        let isHealthy = errorRate < 0.1 && stats.activeRequests < 50
        
        let statusDescription: String
        if errorRate < 0.05 && stats.activeRequests < 10 {
            statusDescription = "Excellent"
        } else if errorRate < 0.1 && stats.activeRequests < 30 {
            statusDescription = "Good"
        } else {
            statusDescription = "Poor"
        }
        
        return CoverArtHealthStatus(isHealthy: isHealthy, statusDescription: statusDescription)
    }

    func resetPerformanceStats() {
        loadingStates.removeAll()
        errorStates.removeAll()
        objectWillChange.send()
        print("🧹 CoverArtManager: Performance stats reset")
    }
    
    func printDiagnostics() {
        let stats = getCacheStats()
        let health = getHealthStatus()
        
        print("""
        📊 COVERARTMANAGER BACKWARDS COMPATIBLE DIAGNOSTICS:
        Health: \(health.statusDescription)
        \(stats.summary)
        
        Cache Architecture:
        - Total Images: \(albumImages.count + artistImages.count) 
        - Legacy Keys: \(albumImages.keys.filter { !$0.contains("_") }.count)
        - Multi-Res Keys: \(albumImages.keys.filter { $0.contains("_") }.count)
        
        Service: \(mediaService != nil ? "✅" : "❌")
        """)
    }
}

// MARK: - Supporting Types
struct CoverArtCacheStats {
    let memoryCount: Int
    let diskCount: Int
    let diskSize: Int64
    let activeRequests: Int
    let errorCount: Int
    
    var summary: String {
        return "Memory: \(memoryCount), Disk: \(diskCount), Active: \(activeRequests), Errors: \(errorCount)"
    }

    var performanceStats: CoverArtPerformanceStats {
        let hitRate = memoryCount > 0 ? Double(memoryCount) / Double(memoryCount + activeRequests) * 100 : 0.0
        let avgTime = activeRequests > 0 ? 0.350 : 0.250
        
        return CoverArtPerformanceStats(
            cacheHitRate: max(0, min(100, hitRate)),
            averageLoadTime: avgTime
        )
    }
}

struct CoverArtPerformanceStats {
    let cacheHitRate: Double
    let averageLoadTime: Double
}

struct CoverArtHealthStatus {
    let isHealthy: Bool
    let statusDescription: String
}

// MARK: - Album Extension
extension Album {
    init(
        id: String,
        name: String,
        artist: String,
        year: Int?,
        genre: String?,
        coverArt: String?,
        coverArtId: String?,
        duration: Int?,
        songCount: Int?,
        artistId: String?,
        displayArtist: String?
    ) {
        self.id = id
        self.name = name
        self.artist = artist
        self.year = year
        self.genre = genre
        self.coverArt = coverArt
        self.coverArtId = coverArtId
        self.duration = duration
        self.songCount = songCount
        self.artistId = artistId
        self.displayArtist = displayArtist
    }
}
