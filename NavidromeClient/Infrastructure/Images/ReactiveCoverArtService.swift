//
//  ReactiveCoverArtService.swift - FIXED VERSION
//  NavidromeClient
//
//  ✅ FIXES:
//  - Removed memory duplication (no more @Published images dict)
//  - Added unified async API for bypass cases
//  - Smart size-key strategy (store original, scale down)
//  - Configurable batching with performance monitoring
//

import Foundation
import SwiftUI

// MARK: - Performance Configuration
struct CoverArtConfig {
    static var batchSize: Int = 10
    static var batchInterval: TimeInterval = 0.1 // 100ms
    static var memoryLimit: Int = 50 // MB
    static var enableScaling: Bool = true
    static var originalSize: Int = 500 // Store original at 500px
    
    #if DEBUG
    static var enableProfiling = true
    #endif
}

@MainActor
class ReactiveCoverArtService: ObservableObject {
    static let shared = ReactiveCoverArtService()
    
    // ✅ FIX: Single source of truth - only PersistentImageCache for storage
    // NO MORE @Published images dict - eliminates memory duplication
    
    // Request Deduplication
    private var pendingRequests: Set<String> = []
    
    // Batch Processing for UI Updates
    private var pendingUIUpdates: Set<String> = []
    private var updateTimer: Timer?
    
    // Dependencies
    private let persistentCache = PersistentImageCache.shared
    private weak var navidromeService: SubsonicService?
    
    #if DEBUG
    // Performance Monitoring
    private var performanceMetrics = PerformanceMetrics()
    #endif
    
    private init() {}
    
    // MARK: - Configuration
    
    func configure(service: SubsonicService) {
        self.navidromeService = service
    }
    
    // MARK: - ✅ REACTIVE API (for SwiftUI Views)
    
    /// Returns current image or nil. Views automatically update when image loads.
    func image(for id: String, size: Int = 300) -> UIImage? {
        let cacheKey = smartCacheKey(for: id, requestedSize: size)
        
        #if DEBUG
        if CoverArtConfig.enableProfiling {
            performanceMetrics.recordRequest()
        }
        #endif
        
        // ✅ FIX: Single source - check PersistentImageCache only
        if let cached = persistentCache.image(for: cacheKey) {
            #if DEBUG
            if CoverArtConfig.enableProfiling {
                performanceMetrics.recordCacheHit()
            }
            #endif
            return scaleImageIfNeeded(cached, requestedSize: size)
        }
        
        // Start loading if not already pending
        if !pendingRequests.contains(cacheKey) {
            Task {
                await loadImageInternal(id: id, requestedSize: size, cacheKey: cacheKey)
            }
        }
        
        return nil
    }
    
    /// Request image loading (fire-and-forget)
    func requestImage(for id: String, size: Int = 300) {
        let cacheKey = smartCacheKey(for: id, requestedSize: size)
        
        // Skip if already cached or loading
        guard persistentCache.image(for: cacheKey) == nil && !pendingRequests.contains(cacheKey) else {
            return
        }
        
        Task {
            await loadImageInternal(id: id, requestedSize: size, cacheKey: cacheKey)
        }
    }
    
    // MARK: - ✅ NEW: ASYNC API (for ViewModels - replaces bypass calls)
    
    /// Async loading for ViewModels that need immediate results
    func loadImage(for id: String, size: Int = 300) async -> UIImage? {
        let cacheKey = smartCacheKey(for: id, requestedSize: size)
        
        // Check cache first
        if let cached = persistentCache.image(for: cacheKey) {
            return scaleImageIfNeeded(cached, requestedSize: size)
        }
        
        // Load from network
        return await loadImageInternal(id: id, requestedSize: size, cacheKey: cacheKey)
    }
    
    /// Convenience method for Album objects
    func loadAlbumCover(_ album: Album, size: Int = 300) async -> UIImage? {
        return await loadImage(for: album.id, size: size)
    }
    
    /// Convenience method for Artist objects
    func loadArtistImage(_ artist: Artist, size: Int = 120) async -> UIImage? {
        guard let coverArt = artist.coverArt else { return nil }
        return await loadImage(for: coverArt, size: size)
    }
    
    // MARK: - Batch Operations
    
    func preloadImages(for ids: [String], size: Int = 200) async {
        let idsToLoad = Array(ids.prefix(CoverArtConfig.batchSize))
        
        await withTaskGroup(of: Void.self) { group in
            for id in idsToLoad {
                let cacheKey = smartCacheKey(for: id, requestedSize: size)
                
                guard persistentCache.image(for: cacheKey) == nil &&
                      !pendingRequests.contains(cacheKey) else {
                    continue
                }
                
                group.addTask {
                    await self.loadImageInternal(id: id, requestedSize: size, cacheKey: cacheKey)
                }
            }
        }
    }
    
    func preloadAlbums(_ albums: [Album], size: Int = 200) async {
        let albumIds = albums.map { $0.id }
        await preloadImages(for: albumIds, size: size)
    }
    
    // MARK: - ✅ Smart Cache Key Strategy
    
    private func smartCacheKey(for id: String, requestedSize: Int) -> String {
        if CoverArtConfig.enableScaling && requestedSize < CoverArtConfig.originalSize {
            // Store at original size, scale down on demand
            return id
        } else {
            // Store at requested size
            return "\(id)_\(requestedSize)"
        }
    }
    
    // MARK: - ✅ Image Scaling
    
    private func scaleImageIfNeeded(_ image: UIImage, requestedSize: Int) -> UIImage? {
        guard CoverArtConfig.enableScaling else { return image }
        
        let currentSize = max(image.size.width, image.size.height)
        
        // Only scale down, never up
        guard requestedSize < Int(currentSize) else { return image }
        
        let targetSize = CGSize(width: requestedSize, height: requestedSize)
        
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return scaledImage
    }
    
    // MARK: - Private Loading Logic
    
    @discardableResult
    private func loadImageInternal(id: String, requestedSize: Int, cacheKey: String) async -> UIImage? {
        guard let service = navidromeService else { return nil }
        
        // Mark as pending
        pendingRequests.insert(cacheKey)
        defer { pendingRequests.remove(cacheKey) }
        
        #if DEBUG
        if CoverArtConfig.enableProfiling {
            performanceMetrics.recordNetworkRequest()
        }
        #endif
        
        // Determine actual size to request
        let networkSize = CoverArtConfig.enableScaling ? CoverArtConfig.originalSize : requestedSize
        
        // Load from network
        let image = await service.getCoverArt(for: id, size: networkSize)
        
        if let image = image {
            // Store in persistent cache
            persistentCache.store(image, for: cacheKey)
            
            // ✅ FIX: Batch UI updates to prevent excessive SwiftUI refreshes
            scheduleUIUpdate(for: cacheKey)
            
            print("✅ Cover art loaded: \(cacheKey)")
            
            // Return scaled version if needed
            return scaleImageIfNeeded(image, requestedSize: requestedSize)
        }
        
        return nil
    }
    
    // MARK: - ✅ Batched UI Updates
    
    private func scheduleUIUpdate(for cacheKey: String) {
        pendingUIUpdates.insert(cacheKey)
        
        // Cancel existing timer
        updateTimer?.invalidate()
        
        // Schedule batch update
        updateTimer = Timer.scheduledTimer(withTimeInterval: CoverArtConfig.batchInterval, repeats: false) { [weak self] _ in
            self?.flushUIUpdates()
        }
    }
    
    private func flushUIUpdates() {
        guard !pendingUIUpdates.isEmpty else { return }
        
        // Single objectWillChange notification for all pending updates
        objectWillChange.send()
        
        #if DEBUG
        if CoverArtConfig.enableProfiling {
            print("🔄 Batched UI update for \(pendingUIUpdates.count) images")
        }
        #endif
        
        pendingUIUpdates.removeAll()
    }
    
    // MARK: - SwiftUI Helper Methods
    
    func coverImage(for album: Album, size: Int = 300) -> UIImage? {
        return image(for: album.id, size: size)
    }
    
    func artistImage(for artist: Artist, size: Int = 300) -> UIImage? {
        guard let coverArt = artist.coverArt else { return nil }
        return image(for: coverArt, size: size)
    }
    
    // MARK: - Memory Management & Stats
    
    func clearMemoryCache() {
        persistentCache.clearCache()
        pendingRequests.removeAll()
        pendingUIUpdates.removeAll()
        updateTimer?.invalidate()
    }
    
    func getCacheStats() -> (persistent: Int, networkRequests: Int) {
        let persistentStats = persistentCache.getCacheStats()
        
        #if DEBUG
        if CoverArtConfig.enableProfiling {
            return (persistentStats.diskCount, performanceMetrics.networkRequests)
        }
        #endif
        
        return (persistentStats.diskCount, 0)
    }
    
    // MARK: - Performance Monitoring (Debug)
    
    #if DEBUG
    private struct PerformanceMetrics {
        var totalRequests = 0
        var cacheHits = 0
        var networkRequests = 0
        
        mutating func recordRequest() {
            totalRequests += 1
        }
        
        mutating func recordCacheHit() {
            cacheHits += 1
        }
        
        mutating func recordNetworkRequest() {
            networkRequests += 1
        }
        
        var cacheHitRate: Double {
            guard totalRequests > 0 else { return 0 }
            return Double(cacheHits) / Double(totalRequests) * 100
        }
    }
    
    private func getPerformanceStats() -> PerformanceMetrics {
        return performanceMetrics
    }
    #endif
}
