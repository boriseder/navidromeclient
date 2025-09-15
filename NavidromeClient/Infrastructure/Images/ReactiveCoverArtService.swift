//
//  ReactiveCoverArtService.swift - PROPERLY REFACTORED
//  NavidromeClient
//
//  ✅ CORRECT: True async-only API, no UI blocking
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
    
    // MARK: - ✅ CORE API: Only Async Methods
    
    /// Load album cover (async only - no UI blocking)
    func loadAlbumCover(_ album: Album, size: Int = 300) async -> UIImage? {
        return await loadImage(for: .album(album.id), size: size)
    }
    
    /// Load artist image (async only - no UI blocking)
    func loadArtistImage(_ artist: Artist, size: Int = 120) async -> UIImage? {
        guard let coverArt = artist.coverArt, !coverArt.isEmpty else { return nil }
        return await loadImage(for: .artist(coverArt), size: size)
    }
    
    /// Core async loading method
    func loadImage(for imageType: ImageType, size: Int) async -> UIImage? {
        let cacheKey = buildCacheKey(for: imageType, size: size)
        
        // 1. Fast cache check (non-blocking)
        if let cached = persistentCache.image(for: cacheKey) {
            return optimizeImageSize(cached, requestedSize: size)
        }
        
        // 2. Async network loading with concurrency control
        return await loadFromNetwork(imageType: imageType, size: size, cacheKey: cacheKey)
    }
    
    // MARK: - ✅ CACHE-ONLY Methods (for quick checks)
    
    /// Check if image is in cache (fast, non-blocking)
    func hasCachedImage(for imageType: ImageType, size: Int) -> Bool {
        let cacheKey = buildCacheKey(for: imageType, size: size)
        return persistentCache.image(for: cacheKey) != nil
    }
    
    /// Get cached image immediately (fast, non-blocking)
    func getCachedImage(for imageType: ImageType, size: Int) -> UIImage? {
        let cacheKey = buildCacheKey(for: imageType, size: size)
        if let cached = persistentCache.image(for: cacheKey) {
            return optimizeImageSize(cached, requestedSize: size)
        }
        return nil
    }
    
    // MARK: - ✅ CONVENIENCE: Cache-only methods for UI
    
    func getCachedAlbumCover(_ album: Album, size: Int = 300) -> UIImage? {
        return getCachedImage(for: .album(album.id), size: size)
    }
    
    func getCachedArtistImage(_ artist: Artist, size: Int = 120) -> UIImage? {
        guard let coverArt = artist.coverArt, !coverArt.isEmpty else { return nil }
        return getCachedImage(for: .artist(coverArt), size: size)
    }
    
    // MARK: - Private Implementation
    
    private func loadFromNetwork(imageType: ImageType, size: Int, cacheKey: String) async -> UIImage? {
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
        let image = await loadImageFromService(service: service, imageType: imageType, size: networkSize)
        
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
    
    private func loadImageFromService(service: SubsonicService, imageType: ImageType, size: Int) async -> UIImage? {
        switch imageType {
        case .album(let albumId):
            return await service.getCoverArt(for: albumId, size: size)
            
        case .artist(let artistId):
            return await service.getCoverArt(for: artistId, size: size)
        }
    }
    
    private func buildCacheKey(for imageType: ImageType, size: Int) -> String {
        return "\(imageType.cachePrefix)_\(imageType.id)_\(size)"
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
}
