//
//  ReactiveCoverArtService.swift - REFACTORED WITHOUT ImageType
//  NavidromeClient
//
//  ✅ CLEAN: Type-safe, unified API without ImageType enum
//

import Foundation
import SwiftUI

@MainActor
class ReactiveCoverArtService: ObservableObject {
    static let shared = ReactiveCoverArtService()
    
    // Dependencies
    private let persistentCache = PersistentImageCache.shared
    private weak var navidromeService: SubsonicService?
    
    // Request management
    private var activeRequests: Set<String> = []
    private let maxConcurrentRequests = 3
    
    private init() {}
    
    // MARK: - Configuration
    
    func configure(service: SubsonicService) {
        self.navidromeService = service
    }
    
    // MARK: - ✅ PRIMARY API: Type-Safe Album/Artist Loading
    
    /// Load album cover (async only - no UI blocking)
    func loadAlbumCover(_ album: Album, size: Int = 300) async -> UIImage? {
        let cacheKey = "album_\(album.id)_\(size)"
        
        // 1. Fast cache check (non-blocking)
        if let cached = persistentCache.image(for: cacheKey) {
            return optimizeImageSize(cached, requestedSize: size)
        }
        
        // 2. Async network loading with concurrency control
        return await loadFromNetwork(coverId: album.id, size: size, cacheKey: cacheKey)
    }
    
    /// Load artist image (async only - no UI blocking)
    func loadArtistImage(_ artist: Artist, size: Int = 120) async -> UIImage? {
        guard let coverArt = artist.coverArt, !coverArt.isEmpty else { return nil }
        let cacheKey = "artist_\(coverArt)_\(size)"
        
        // 1. Fast cache check (non-blocking)
        if let cached = persistentCache.image(for: cacheKey) {
            return optimizeImageSize(cached, requestedSize: size)
        }
        
        // 2. Async network loading with concurrency control
        return await loadFromNetwork(coverId: coverArt, size: size, cacheKey: cacheKey)
    }
    
    // MARK: - ✅ CACHE-ONLY Methods (for quick checks)
    
    /// Check if album image is in cache (fast, non-blocking)
    func hasCachedAlbumCover(_ album: Album, size: Int) -> Bool {
        let cacheKey = "album_\(album.id)_\(size)"
        return persistentCache.image(for: cacheKey) != nil
    }
    
    /// Get cached album image immediately (fast, non-blocking)
    func getCachedAlbumCover(_ album: Album, size: Int = 300) -> UIImage? {
        let cacheKey = "album_\(album.id)_\(size)"
        if let cached = persistentCache.image(for: cacheKey) {
            return optimizeImageSize(cached, requestedSize: size)
        }
        return nil
    }
    
    /// Check if artist image is in cache (fast, non-blocking)
    func hasCachedArtistImage(_ artist: Artist, size: Int) -> Bool {
        guard let coverArt = artist.coverArt, !coverArt.isEmpty else { return false }
        let cacheKey = "artist_\(coverArt)_\(size)"
        return persistentCache.image(for: cacheKey) != nil
    }
    
    /// Get cached artist image immediately (fast, non-blocking)
    func getCachedArtistImage(_ artist: Artist, size: Int = 120) -> UIImage? {
        guard let coverArt = artist.coverArt, !coverArt.isEmpty else { return nil }
        let cacheKey = "artist_\(coverArt)_\(size)"
        if let cached = persistentCache.image(for: cacheKey) {
            return optimizeImageSize(cached, requestedSize: size)
        }
        return nil
    }
    
    // MARK: - ✅ UNIFIED NETWORK LOADING
    
    private func loadFromNetwork(coverId: String, size: Int, cacheKey: String) async -> UIImage? {
        // Concurrency control
        while activeRequests.count >= maxConcurrentRequests {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        // Deduplication
        guard !activeRequests.contains(cacheKey) else {
            // Wait for existing request
            while activeRequests.contains(cacheKey) {
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            }
            // Check cache again
            return persistentCache.image(for: cacheKey)
        }
        
        activeRequests.insert(cacheKey)
        defer { activeRequests.remove(cacheKey) }
        
        guard let service = navidromeService else { return nil }
        
        let networkSize = size > 300 ? size : 500 // Load higher res for caching
        let image = await service.getCoverArt(for: coverId, size: networkSize)
        
        if let image = image {
            persistentCache.store(image, for: cacheKey)
            
            // Notify UI on main thread
            Task { @MainActor in
                self.objectWillChange.send()
            }
            
            return optimizeImageSize(image, requestedSize: size)
        }
        
        return nil
    }
    
    private func optimizeImageSize(_ image: UIImage, requestedSize: Int) -> UIImage? {
        let currentSize = max(image.size.width, image.size.height)
        
        guard requestedSize < Int(currentSize * 0.8) else {
            return image
        }
        
        let cgSize = CGSize(width: requestedSize, height: requestedSize)
        let renderer = UIGraphicsImageRenderer(size: cgSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: cgSize))
        }
    }
    
    // MARK: - Batch Operations
    
    func preloadAlbums(_ albums: [Album], size: Int = 200) async {
        let albumsToLoad = albums.prefix(10) // Limit batch size
        
        await withTaskGroup(of: Void.self) { group in
            for album in albumsToLoad {
                group.addTask {
                    _ = await self.loadAlbumCover(album, size: size)
                }
            }
        }
    }
    
    func preloadArtists(_ artists: [Artist], size: Int = 120) async {
        let artistsToLoad = artists.prefix(10).filter { $0.coverArt != nil }
        
        await withTaskGroup(of: Void.self) { group in
            for artist in artistsToLoad {
                group.addTask {
                    _ = await self.loadArtistImage(artist, size: size)
                }
            }
        }
    }
    
    // MARK: - Memory Management
    
    func clearMemoryCache() {
        persistentCache.clearCache()
        activeRequests.removeAll()
    }
    
    func getCacheStats() -> CacheStats {
        let persistentStats = persistentCache.getCacheStats()
        
        return CacheStats(
            persistent: persistentStats.diskCount,
            networkRequests: activeRequests.count
        )
    }
    
    struct CacheStats {
        let persistent: Int
        let networkRequests: Int
    }
}
