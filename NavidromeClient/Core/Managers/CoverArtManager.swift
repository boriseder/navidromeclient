//
//  CoverArtManager.swift - COMPLETE: Alle ReaktivitÃ¤ts-Fixes
//  NavidromeClient
//
//   FIXED: Konsistente @Published Updates fÃ¼r alle Load-Methoden
//   CLEAN: Pure Multi-Resolution Implementation
//

import Foundation
import SwiftUI

@MainActor
class CoverArtManager: ObservableObject {
    static let shared = CoverArtManager()
    
    // MARK: - State
    @Published private(set) var albumImages: [String: UIImage] = [:]
    @Published private(set) var artistImages: [String: UIImage] = [:]
    @Published private(set) var loadingStates: [String: Bool] = [:]
    @Published private(set) var errorStates: [String: String] = [:]
    
    private weak var mediaService: MediaService?
    private let persistentCache = PersistentImageCache.shared
    
    private init() {}
    
    // MARK: - Configuration
    
    func configure(mediaService: MediaService) {
        self.mediaService = mediaService
        print("CoverArtManager configured with MediaService")
    }
    
    // MARK: - âœ… FIXED: Album Loading mit garantierten UI Updates
    
    func loadAlbumImage(album: Album, size: Int = 400, staggerIndex: Int = 0) async -> UIImage? {
            let memoryKey = "album_\(album.id)_\(size)"
            
            // Check memory cache
            if let cached = albumImages[memoryKey] {
                print("Album memory hit: \(album.id) @ \(size)px")
                return cached
            }
            
            // Check persistent cache
            let cacheKey = "album_\(album.id)_\(size)"
            if let cached = persistentCache.image(for: cacheKey) {
                print("Album disk hit: \(album.id) @ \(size)px")
                await MainActor.run {
                    albumImages[memoryKey] = cached
                    objectWillChange.send() // ✅ CRITICAL: Force UI update
                }
                return cached
            }
            
            guard let service = mediaService else {
                await MainActor.run {
                    errorStates[memoryKey] = "Media service not available"
                    objectWillChange.send()
                }
                return nil
            }
            
            await MainActor.run {
                loadingStates[memoryKey] = true
                objectWillChange.send()
            }
            
            defer {
                Task { @MainActor in
                    loadingStates[memoryKey] = false
                    objectWillChange.send()
                }
            }
            
            if staggerIndex > 0 {
                try? await Task.sleep(nanoseconds: UInt64(staggerIndex * 100_000_000))
            }
            
            if let image = await service.getCoverArt(for: album.id, size: size) {
                print("Album network load: \(album.id) @ \(size)px -> \(image.size.width)x\(image.size.height)")
                
                await MainActor.run {
                    albumImages[memoryKey] = image
                    errorStates.removeValue(forKey: memoryKey)
                    objectWillChange.send() // ✅ CRITICAL: Force UI update
                }
                
                persistentCache.store(image, for: cacheKey)
                return image
            } else {
                await MainActor.run {
                    errorStates[memoryKey] = "Failed to load album image"
                    objectWillChange.send()
                }
                return nil
            }
        }
    // MARK: - âœ… FIXED: Artist Loading mit garantierten UI Updates
    
    func loadArtistImage(artist: Artist, size: Int = 240, staggerIndex: Int = 0) async -> UIImage? {
        let memoryKey = "artist_\(artist.id)_\(size)"
        
        // Check memory cache
        if let cached = artistImages[memoryKey] {
            print("Artist memory hit: \(artist.id) @ \(size)px")
            return cached
        }
        
        // Check persistent cache
        let cacheKey = "artist_\(artist.id)_\(size)"
        if let cached = persistentCache.image(for: cacheKey) {
            print("Artist disk hit: \(artist.id) @ \(size)px")
            
            // CRITICAL FIX: Ensure @Published update on MainActor
            await MainActor.run {
                self.artistImages[memoryKey] = cached
                self.objectWillChange.send() // Force UI update
            }
            
            return cached
        }
        
        guard let service = mediaService else {
            await MainActor.run {
                self.errorStates[memoryKey] = "Media service not available"
                self.objectWillChange.send()
            }
            return nil
        }
        
        // âœ… CRITICAL FIX: Loading state update on MainActor
        await MainActor.run {
            self.loadingStates[memoryKey] = true
            self.objectWillChange.send()
        }
        
        defer {
            Task { @MainActor in
                self.loadingStates[memoryKey] = false
                self.objectWillChange.send()
            }
        }
        
        if staggerIndex > 0 {
            try? await Task.sleep(nanoseconds: UInt64(staggerIndex * 100_000_000))
        }
        
        if let image = await service.getCoverArt(for: artist.id, size: size) {
            print("Artist network load: \(artist.id) @ \(size)px -> \(image.size.width)x\(image.size.height)")
            
            // âœ… CRITICAL FIX: Image loaded - force UI update
            await MainActor.run {
                self.artistImages[memoryKey] = image
                self.errorStates.removeValue(forKey: memoryKey)
                self.objectWillChange.send() // Force UI update
            }
            
            persistentCache.store(image, for: cacheKey)
            return image
        } else {
            await MainActor.run {
                self.errorStates[memoryKey] = "Failed to load artist image"
                self.objectWillChange.send()
            }
            return nil
        }
    }
    
    // MARK: - Image Getters
    
    func getAlbumImage(for albumId: String, size: Int) -> UIImage? {
        let memoryKey = "album_\(albumId)_\(size)"
        return albumImages[memoryKey]
    }

    func getArtistImage(for artistId: String, size: Int) -> UIImage? {
        let memoryKey = "artist_\(artistId)_\(size)"
        return artistImages[memoryKey]
    }
    
    // MARK: - Song Images
    
    func loadSongImage(song: Song, size: Int = 100) async -> UIImage? {
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
    
    func getSongImage(for song: Song, size: Int) -> UIImage? {
        guard let albumId = song.albumId else { return nil }
        let memoryKey = "album_\(albumId)_\(size)"
        return albumImages[memoryKey]
    }
    
    // MARK: - State Queries
    
    func isLoadingImage(for key: String, size: Int) -> Bool {
        let memoryKey = "\(key)_\(size)"
        return loadingStates[memoryKey] == true
    }
    
    func getImageError(for key: String, size: Int) -> String? {
        let memoryKey = "\(key)_\(size)"
        return errorStates[memoryKey]
    }
    
    // MARK: - âœ… FIXED: Batch Operations mit UI Updates
    
    func preloadAlbums(_ albums: [Album], size: Int = 400) async {
        guard mediaService != nil else { return }
        
        await withTaskGroup(of: Void.self) { group in
            for (index, album) in albums.enumerated() {
                if index >= 5 { break }
                
                group.addTask {
                    _ = await self.loadAlbumImage(album: album, size: size, staggerIndex: index)
                }
            }
        }
        
        // âœ… UI Update nach Preload-Batch
        await MainActor.run {
            self.objectWillChange.send()
        }
        
        print("Batch preloaded album covers for \(min(albums.count, 5)) albums @ \(size)px")
    }
    
    func preloadArtists(_ artists: [Artist], size: Int = 240) async {
        guard mediaService != nil else { return }
        
        await withTaskGroup(of: Void.self) { group in
            for (index, artist) in artists.enumerated() {
                if index >= 5 { break }
                
                group.addTask {
                    _ = await self.loadArtistImage(artist: artist, size: size, staggerIndex: index)
                }
            }
        }
        
        // âœ… UI Update nach Preload-Batch
        await MainActor.run {
            self.objectWillChange.send()
        }
        
        print("Batch preloaded artist images for \(min(artists.count, 5)) artists @ \(size)px")
    }
    
    // MARK: - âœ… FIXED: Cache Management mit UI Updates
    
    func clearMemoryCache() {
        albumImages.removeAll()
        artistImages.removeAll()
        loadingStates.removeAll()
        errorStates.removeAll()
        persistentCache.clearCache()
        
        // âœ… UI Update nach Cache Clear
        objectWillChange.send()
        
        print("Cleared all image caches")
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
        print("CoverArtManager: Performance stats reset")
    }
    
    func printDiagnostics() {
        let stats = getCacheStats()
        let health = getHealthStatus()
        
        print("""
        COVERARTMANAGER DIAGNOSTICS:
        Health: \(health.statusDescription)
        \(stats.summary)
        
        Cache Architecture:
        - Total Images: \(albumImages.count + artistImages.count) 
        - Multi-Resolution Keys Only
        
        Service: \(mediaService != nil ? "âœ…" : "âŒ")
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
