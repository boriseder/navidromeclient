//
//  CoverArtManager.swift - COMPLETE Missing Methods
//  NavidromeClient
//
//   ADDED: All missing methods used throughout the app
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
    
    //  NEW: Focused service dependency
    private weak var mediaService: MediaService?
    
    //  BACKWARDS COMPATIBLE: Keep old service reference
    private weak var legacyService: UnifiedSubsonicService?
    
    private let persistentCache = PersistentImageCache.shared
    
    private init() {}
    
    // MARK: -  ENHANCED: Dual Configuration Support
    
    /// NEW: Configure with focused MediaService (preferred)
    func configure(mediaService: MediaService) {
        self.mediaService = mediaService
        print(" CoverArtManager configured with focused MediaService")
    }
    
    /// LEGACY: Configure with UnifiedSubsonicService (backwards compatible)
    func configure(service: UnifiedSubsonicService) {
        self.legacyService = service
        self.mediaService = service.getMediaService()
        print(" CoverArtManager configured with legacy service (extracted MediaService)")
    }
    
    // MARK: -  ENHANCED: Smart Service Resolution
    
    private var activeMediaService: MediaService? {
        return mediaService ?? legacyService?.getMediaService()
    }
    
    // MARK: ALBUM Image Loading
    
    func loadAlbumImage(album: Album, size: Int = 200, staggerIndex: Int = 0) async -> UIImage? {
        let stateKey = "album_\(album.id)"

        // Return cached state if available
        if let cached = albumImages[stateKey] {
            return cached
        }
        
        // Check persistent cache
        let cacheKey = "album_\(album.id)_\(size)"
        if let cached = persistentCache.image(for: cacheKey) {
            albumImages[stateKey] = cached
            return cached
        }
        
        // Load from service
        guard let service = activeMediaService else {
            errorStates[stateKey] = "Media service not available"
            return nil
        }
        
        loadingStates[stateKey] = true
        defer { loadingStates[stateKey] = false }
        
        //  STAGGER LOADING: Add delay based on index
        if staggerIndex > 0 {
            try? await Task.sleep(nanoseconds: UInt64(staggerIndex * 100_000_000)) // 100ms per index
        }
        
        if let image = await service.getCoverArt(for: album.id, size: size) {
            albumImages[stateKey] = image
            errorStates.removeValue(forKey: stateKey)
            
            // Cache persistently
            persistentCache.store(image, for: cacheKey)
            
            return image
        } else {
            errorStates[stateKey] = "Failed to load album image"
            return nil
        }
    }
    
    func getAlbumImage(for albumId: String, size: Int = 200) -> UIImage? {
        return albumImages["album_\(albumId)"]
    }

    // MARK: ARTIST Image Loading

    func loadArtistImage(artist: Artist, size: Int = 200, staggerIndex: Int = 0) async -> UIImage? {
        let stateKey = "artist_\(artist.id)"
        
        // Return cached state if available
        if let cached = artistImages[stateKey] {
            return cached
        }
        
        // Check persistent cache
        let cacheKey = "artist_\(artist.id)_\(size)"
        if let cached = persistentCache.image(for: cacheKey) {
            artistImages[stateKey] = cached
            return cached
        }
        
        //  ECHTE IMPLEMENTATION: Load from MediaService
        guard let service = activeMediaService else {
            errorStates[stateKey] = "Media service not available"
            return nil
        }
        
        loadingStates[stateKey] = true
        defer { loadingStates[stateKey] = false }
        
        //  STAGGER LOADING: Add delay based on index
        if staggerIndex > 0 {
            try? await Task.sleep(nanoseconds: UInt64(staggerIndex * 100_000_000)) // 100ms per index
        }
        
        //  LOAD ARTIST IMAGE via MediaService
        if let image = await service.getCoverArt(for: artist.id, size: size) {
            artistImages[stateKey] = image
            errorStates.removeValue(forKey: stateKey)
            
            // Cache persistently
            persistentCache.store(image, for: cacheKey)
            
            return image
        } else {
            errorStates[stateKey] = "Failed to load artist image"
            return nil
        }
    }

    func getArtistImage(for artistId: String) -> UIImage? {
        return artistImages["artist_\(artistId)"]
    }

    // MARK: SONG Image Loading (for search results)
    
    func loadSongImage(song: Song, size: Int = 50) async -> UIImage? {
        // Songs use album cover art
        guard let albumId = song.albumId else { return nil }
        
        // Create minimal album object for loading
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
        return albumImages[albumId]
    }
    
    // MARK: Batch Operations
    
    // NEW: Batch album cover art loading for better performance
    func preloadAlbums(_ albums: [Album], size: Int = 200) async {
        guard let service = activeMediaService else { return }
        
        let items = albums.enumerated().map { (index, album) in
            (id: album.id, size: size, index: index)
        }
        
        await withTaskGroup(of: Void.self) { group in
            for (index, item) in items.enumerated() {
                // Limit concurrent requests
                if index >= 5 { break }
                
                group.addTask {
                    _ = await self.loadAlbumImage(
                        album: albums.first { $0.id == item.id }!,
                        size: item.size,
                        staggerIndex: item.index
                    )
                }
            }
        }
        
        print(" Batch preloaded album covers for \(min(albums.count, 5)) albums")
    }
    
    // NEW: Batch artist image loading
    func preloadArtists(_ artists: [Artist], size: Int = 120) async {
        guard let service = activeMediaService else { return }
        
        let items = artists.enumerated().map { (index, artist) in
            (artist: artist, size: size, index: index)
        }
        
        await withTaskGroup(of: Void.self) { group in
            for (index, item) in items.enumerated() {
                // Limit concurrent requests
                if index >= 5 { break }
                
                group.addTask {
                    _ = await self.loadArtistImage(
                        artist: item.artist,
                        size: item.size,
                        staggerIndex: item.index
                    )
                }
            }
        }
        
        print(" Batch preloaded artist images for \(min(artists.count, 5)) artists")
    }
    
    // MARK: Access Methods
    
    func isLoadingImage(for key: String) -> Bool {
        return loadingStates[key] == true
    }
    
    func getImageError(for key: String) -> String? {
        return errorStates[key]
    }
    
    // MARK: -  CACHE MANAGEMENT
    
    func clearMemoryCache() {
        albumImages.removeAll()
        artistImages.removeAll()
        loadingStates.removeAll()
        errorStates.removeAll()
        persistentCache.clearCache()
        print("🧹 Cleared all image caches")
    }
    
    // MARK: -  NEW: Performance & Diagnostics
      
    struct CacheStats {
        let memoryAlbums: Int
        let memoryArtists: Int
        let activeRequests: Int
        let errorCount: Int
        let persistentCount: Int
        let persistentSize: Int64
        
        var totalMemoryImages: Int {
            return memoryAlbums + memoryArtists
        }
        
        var summary: String {
            return "Memory: \(totalMemoryImages), Disk: \(persistentCount), Active: \(activeRequests), Errors: \(errorCount)"
        }
    }
        
    struct HealthStatus {
        let isHealthy: Bool
        let statusDescription: String
    }
    
    func printDiagnostics() {
        let stats = getCacheStats()
        let health = getHealthStatus()
        
        print("""
        📊 COVERARTMANAGER DIAGNOSTICS:
        Health: \(health.statusDescription)
        \(stats.summary)
        
        Service Architecture:
        - MediaService: \(mediaService != nil ? "" : "❌")
        - Legacy Service: \(legacyService != nil ? "" : "❌")
        """)
    }
    
    
    // Replace the existing getCacheStats method in CoverArtManager with this:
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
        
        return CoverArtHealthStatus(
            isHealthy: isHealthy,
            statusDescription: statusDescription
        )
    }

    
    // Add these structs to CoverArtManager.swift:
    struct CoverArtCacheStats {
        let memoryCount: Int
        let diskCount: Int
        let diskSize: Int64
        let activeRequests: Int
        let errorCount: Int
        
        var totalMemoryImages: Int { memoryCount }
        
        var summary: String {
            return "Memory: \(totalMemoryImages), Disk: \(diskCount), Active: \(activeRequests), Errors: \(errorCount)"
        }

        var performanceStats: CoverArtPerformanceStats {
            // Calculate realistic performance metrics
            let hitRate = memoryCount > 0 ? Double(memoryCount) / Double(memoryCount + activeRequests) * 100 : 0.0
            let avgTime = activeRequests > 0 ? 0.350 : 0.250 // Mock values, could be tracked properly
            
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

    func resetPerformanceStats() {
        loadingStates.removeAll()
        errorStates.removeAll()
        objectWillChange.send()
        print("🧹 CoverArtManager: Performance stats reset")
    }

    
}

// MARK: -  CONVENIENCE: Album Initializer for Song->Album conversion
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

struct CoverArtCacheStats {
    let memoryCount: Int
    let diskCount: Int
    let diskSize: Int64
    let activeRequests: Int
    let errorCount: Int
    
    var totalMemoryImages: Int { memoryCount }
    
    var summary: String {
        return "Memory: \(totalMemoryImages), Disk: \(diskCount), Active: \(activeRequests), Errors: \(errorCount)"
    }
    var performanceStats: CoverArtPerformanceStats {
        // Mock realistic values - you could track these properly
        let hitRate = memoryCount > 0 ? 85.0 : 0.0
        let avgTime = activeRequests > 0 ? 0.350 : 0.250
        
        return CoverArtPerformanceStats(
            cacheHitRate: hitRate,
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

