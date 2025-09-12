//
//  ReactiveCoverArtService.swift
//  NavidromeClient
//
//  Created by Boris Eder on 12.09.25.
//


import Foundation
import SwiftUI

@MainActor
class ReactiveCoverArtService: ObservableObject {
    static let shared = ReactiveCoverArtService()
    
    // REAKTIVER STATE: Views subscriben automatisch auf Updates
    @Published private(set) var images: [String: UIImage] = [:]
    
    // Request Deduplication
    private var pendingRequests: Set<String> = []
    
    // Dependencies
    private let persistentCache = PersistentImageCache.shared
    private weak var navidromeService: SubsonicService?
    
    private init() {}
    
    // MARK: - Configuration
    
    func configure(service: SubsonicService) {
        self.navidromeService = service
    }
    
    // MARK: - REACTIVE API für Views
    
    /// Returns current image or nil. Views automatically update when image loads.
    func image(for id: String, size: Int = 300) -> UIImage? {
        let cacheKey = "\(id)_\(size)"
        
        // Return if already loaded
        if let image = images[cacheKey] {
            return image
        }
        
        // Check persistent cache - ASYNC UPDATE
        if let cached = persistentCache.image(for: cacheKey) {
            // FIX: Async publishing to avoid "Publishing changes from within view updates"
            Task { @MainActor in
                self.images[cacheKey] = cached
            }
            return cached
        }
        
        // Start loading if not already pending
        if !pendingRequests.contains(cacheKey) {
            Task {
                await loadImage(id: id, size: size, cacheKey: cacheKey)
            }
        }
        
        return nil
    }
    
    /// Request image loading (fire-and-forget)
    func requestImage(for id: String, size: Int = 300) {
        let cacheKey = "\(id)_\(size)"
        
        // Skip if already loaded or loading
        guard images[cacheKey] == nil && !pendingRequests.contains(cacheKey) else {
            return
        }
        
        // Check persistent cache first - ASYNC UPDATE
        if let cached = persistentCache.image(for: cacheKey) {
            Task { @MainActor in
                self.images[cacheKey] = cached
            }
            return
        }
        
        Task {
            await loadImage(id: id, size: size, cacheKey: cacheKey)
        }
    }
    
    // MARK: - Batch Operations
    
    func preloadImages(for ids: [String], size: Int = 200) async {
        let idsToLoad = ids.prefix(10) // Limit concurrent loads
        
        await withTaskGroup(of: Void.self) { group in
            for id in idsToLoad {
                let cacheKey = "\(id)_\(size)"
                
                // Skip if already cached
                guard images[cacheKey] == nil &&
                      persistentCache.image(for: cacheKey) == nil &&
                      !pendingRequests.contains(cacheKey) else {
                    continue
                }
                
                group.addTask {
                    await self.loadImage(id: id, size: size, cacheKey: cacheKey)
                }
            }
        }
    }
    
    func preloadAlbums(_ albums: [Album], size: Int = 200) async {
        let albumIds = albums.map { $0.id }
        await preloadImages(for: albumIds, size: size)
    }
    
    // MARK: - Preloading Extensions
    
    func preloadVisibleAlbums(_ albums: [Album]) {
        Task {
            let visibleAlbums = Array(albums.prefix(20))
            await preloadAlbums(visibleAlbums, size: 200)
        }
    }
    
    func preloadForScrollPosition(_ albums: [Album], visibleRange: Range<Int>) {
        let preloadRange = max(0, visibleRange.lowerBound - 5)..<min(albums.count, visibleRange.upperBound + 5)
        let albumsToPreload = Array(albums[preloadRange])
        
        Task {
            await preloadAlbums(albumsToPreload, size: 200)
        }
    }
    
    // MARK: - Private Loading Logic
    
    private func loadImage(id: String, size: Int, cacheKey: String) async {
        guard let service = navidromeService else { return }
        
        // Mark as pending
        pendingRequests.insert(cacheKey)
        defer { pendingRequests.remove(cacheKey) }
        
        // Load from network
        let image = await service.getCoverArt(for: id, size: size)
        
        if let image = image {
            // FIX: Ensure we're on MainActor for @Published update
            await MainActor.run {
                self.images[cacheKey] = image
            }
            
            print("✅ Cover art loaded reactively: \(cacheKey)")
        }
    }
    
    // MARK: - Memory Management
    
    func clearMemoryCache() {
        images.removeAll()
    }
    
    func getCacheStats() -> (memory: Int, persistent: Int) {
        return (images.count, persistentCache.getCacheStats().diskCount)
    }
    
    // MARK: - SwiftUI Helper
    
    func coverImage(for album: Album, size: Int = 300) -> UIImage? {
        return image(for: album.id, size: size)
    }
    
    func artistImage(for artist: Artist, size: Int = 300) -> UIImage? {
        guard let coverArt = artist.coverArt else { return nil }
        return image(for: coverArt, size: size)
    }
}

