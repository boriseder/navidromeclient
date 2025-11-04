//
//  CoverArtManager.swift
//  NavidromeClient
//
//  Context-aware multi-size caching with hybrid approach
//  Memory cache is size-specific to prevent wrong-size usage
//  AlbumCoverArt handles intelligent downscaling
//

import Foundation
import SwiftUI

@MainActor
class CoverArtManager: ObservableObject {
    
    // MARK: - Cache Configuration
    
    private struct CacheLimits {
        static let albumCount: Int = 300 // Increased for multi-size storage
        static let artistCount: Int = 200
        static let albumMemory: Int = 120 * 1024 * 1024  // 120MB
        static let artistMemory: Int = 60 * 1024 * 1024  // 60MB
    }
    
    private enum CoverArtType {
        case album
        case artist
        
        @MainActor
        func getCache(from manager: CoverArtManager) -> NSCache<NSString, AlbumCoverArt> {
            switch self {
            case .album: return manager.albumCache
            case .artist: return manager.artistCache
            }
        }
        
        var name: String {
            switch self {
            case .album: return "album"
            case .artist: return "artist"
            }
        }
    }

    private enum PreloadPriority {
        case immediate
        case background
        case controlled
    }
    
    private let cacheQueue = DispatchQueue(label: "coverart.cache", attributes: .concurrent)
    private var _cacheVersion = 0
    var cacheVersion: Int {
        cacheQueue.sync { _cacheVersion }
    }

    // MARK: - Storage
    
    private let albumCache = NSCache<NSString, AlbumCoverArt>()
    private let artistCache = NSCache<NSString, AlbumCoverArt>()
        
    // MARK: - Dependencies
    
    private weak var service: UnifiedSubsonicService?
    private let persistentCache = PersistentImageCache.shared
    
    // MARK: - Concurrency Control
    
    private let requestQueue = DispatchQueue(label: "coverart.requests")
    private var activeRequests: Set<String> = []
    
    private var lastPreloadHash: Int = 0
    private var currentPreloadTask: Task<Void, Never>?
    private let preloadSemaphore = AsyncSemaphore(value: 3)
    
    @Published private(set) var loadingStates: [String: Bool] = [:]
    @Published private(set) var errorStates: [String: String] = [:]
    @Published private(set) var cacheGeneration: Int = 0

    // Public method to increment cache generation
    func incrementCacheGeneration() {
        cacheGeneration += 1
        AppLogger.general.info("Cache generation incremented to: \(cacheGeneration)")
    }


    // MARK: - Initialization
    
    init() {
        setupMemoryCache()
        setupFactoryResetObserver()
        setupScenePhaseObserver()
        AppLogger.general.info("CoverArtManager initialized with hybrid multi-size strategy")
    }
    
    func configure(service: UnifiedSubsonicService) {
        self.service = service
        AppLogger.general.info("CoverArtManager configured with UnifiedSubsonicService")
    }

    private func setupMemoryCache() {
        albumCache.countLimit = CacheLimits.albumCount
        albumCache.totalCostLimit = CacheLimits.albumMemory
        albumCache.evictsObjectsWithDiscardedContent = false
        
        artistCache.countLimit = CacheLimits.artistCount
        artistCache.totalCostLimit = CacheLimits.artistMemory
        artistCache.evictsObjectsWithDiscardedContent = false
        
        // Monitor for memory warnings
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                AppLogger.general.warn("Memory warning received - incrementing cache generation")
                self?.incrementCacheGeneration()
            }
        }
        
        AppLogger.general.debug("Memory cache limits: Albums=\(CacheLimits.albumCount), Artists=\(CacheLimits.artistCount)")
    }
    
    private func setupFactoryResetObserver() {
        NotificationCenter.default.addObserver(
            forName: .factoryResetRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.clearMemoryCache()
                AppLogger.general.info("CoverArtManager: Memory cache cleared on factory reset")
            }
        }
    }
    
    // MARK: - Thread-Safe Request Management

    private func isRequestActive(_ id: String, type: String, size: Int) -> Bool {
        return requestQueue.sync {
            return activeRequests.contains("\(type)_\(id)_\(size)")
        }
    }

    private func addActiveRequest(_ id: String, type: String, size: Int) {
        requestQueue.sync {
            _ = activeRequests.insert("\(type)_\(id)_\(size)")
        }
    }

    private func removeActiveRequest(_ id: String, type: String, size: Int) {
        requestQueue.sync {
            _ = activeRequests.remove("\(type)_\(id)_\(size)")
        }
    }
    
    
    // MARK: - Context-Aware Image Retrieval
    
    func getAlbumImage(for albumId: String, context: ImageContext) -> UIImage? {
        return getCachedImage(for: albumId, cache: albumCache, size: context.size)
    }

    func getArtistImage(for artistId: String, context: ImageContext) -> UIImage? {
        return getCachedImage(for: artistId, cache: artistCache, size: context.size)
    }

    func getSongImage(for song: Song, context: ImageContext) -> UIImage? {
        guard let albumId = song.albumId else { return nil }
        return getAlbumImage(for: albumId, context: context)
    }
    
    // Size-specific cache retrieval
    // Cache key includes both ID and size to prevent wrong-size usage
    private func getCachedImage(
        for id: String,
        cache: NSCache<NSString, AlbumCoverArt>,
        size: Int
    ) -> UIImage? {
        let cacheKey = "\(id)_\(size)" as NSString
        
        if let coverArt = cache.object(forKey: cacheKey) {
            if let image = coverArt.getImage(for: size) {
                return image
            }
        }
        
        // Check if we have a larger size that can be downscaled
        let commonSizes = [80, 100, 150, 200, 240, 300, 400, 800, 1000]
        let largerSizes = commonSizes.filter { $0 > size }.sorted()
        
        for largerSize in largerSizes {
            let largerKey = "\(id)_\(largerSize)" as NSString
            if let coverArt = cache.object(forKey: largerKey),
               let image = coverArt.getImage(for: size) {
                // Cache the downscaled version for future use
                let downscaled = AlbumCoverArt(image: image, size: size)
                cache.setObject(downscaled, forKey: cacheKey, cost: downscaled.memoryFootprint)
                AppLogger.general.debug("Downscaled \(largerSize)px -> \(size)px for ID: \(id)")
                return image
            }
        }
        
        return nil
    }

    // MARK: - Context-Aware Image Loading
    
    func loadAlbumImage(
        for albumId: String,
        context: ImageContext,
        staggerIndex: Int = 0
    ) async -> UIImage? {
        return await loadCoverArt(
            id: albumId,
            type: .album,
            size: context.size,
            staggerIndex: staggerIndex
        )
    }

    func loadArtistImage(
        for artistId: String,
        context: ImageContext,
        staggerIndex: Int = 0
    ) async -> UIImage? {
        return await loadCoverArt(
            id: artistId,
            type: .artist,
            size: context.size,
            staggerIndex: staggerIndex
        )
    }
    
    func loadAlbumImage(
        album: Album,
        context: ImageContext,
        staggerIndex: Int = 0
    ) async -> UIImage? {
        return await loadAlbumImage(for: album.id, context: context, staggerIndex: staggerIndex)
    }
    
    func loadArtistImage(
        artist: Artist,
        context: ImageContext,
        staggerIndex: Int = 0
    ) async -> UIImage? {
        return await loadArtistImage(for: artist.id, context: context, staggerIndex: staggerIndex)
    }

    func loadSongImage(
        song: Song,
        context: ImageContext
    ) async -> UIImage? {
        guard let albumId = song.albumId else { return nil }
        return await loadAlbumImage(for: albumId, context: context)
    }
    
    // MARK: - Core Loading Logic
    
    private func loadCoverArt(
        id: String,
        type: CoverArtType,
        size: Int,
        staggerIndex: Int = 0
    ) async -> UIImage? {
        let cacheKey = "\(id)_\(size)" as NSString
        let cache = type.getCache(from: self)
        
        // Check size-specific memory cache
        if let coverArt = cache.object(forKey: cacheKey),
           let image = coverArt.getImage(for: size) {
            AppLogger.general.debug("Memory cache HIT: \(type.name)_\(id)_\(size)px")
            return image
        }
        
        // Check if we can downscale from a larger cached version
        if let downscaled = await checkForDownscalableVersion(id: id, requestedSize: size, type: type) {
            AppLogger.general.debug("Downscaled from larger cache entry: \(type.name)_\(id)_\(size)px")
            return downscaled
        }
        
        // Prevent duplicate requests for same ID+size
        if isRequestActive(id, type: type.name, size: size) {
            AppLogger.general.debug("Request already active: \(type.name)_\(id)_\(size)px")
            return nil
        }
        
        addActiveRequest(id, type: type.name, size: size)
        defer { removeActiveRequest(id, type: type.name, size: size) }
        
        // Check disk cache
        let diskCacheKey = "\(type.name)_\(id)_\(size)"
        if let cached = persistentCache.image(for: diskCacheKey, size: size) {
            AppLogger.general.debug("Disk cache HIT: \(diskCacheKey)")
            storeImage(cached, forId: id, type: type, size: size)
            return cached
        }
        
        // Load from network
        AppLogger.general.debug("Loading from network: \(type.name)_\(id)_\(size)px")
        return await loadImageFromNetwork(
            id: id,
            size: size,
            requestKey: "\(type.name)_\(id)_\(size)",
            staggerIndex: staggerIndex,
            type: type
        )
    }
    
    // Check if we have a larger version in cache that can be downscaled
    private func checkForDownscalableVersion(
        id: String,
        requestedSize: Int,
        type: CoverArtType
    ) async -> UIImage? {
        let cache = type.getCache(from: self)
        let commonSizes = [80, 100, 150, 200, 240, 300, 400, 800, 1000]
        let largerSizes = commonSizes.filter { $0 > requestedSize }.sorted()
        
        for largerSize in largerSizes {
            let largerKey = "\(id)_\(largerSize)" as NSString
            if let coverArt = cache.object(forKey: largerKey),
               let image = coverArt.getImage(for: requestedSize) {
                // Store downscaled version in its own cache entry
                storeImage(image, forId: id, type: type, size: requestedSize)
                return image
            }
        }
        
        return nil
    }
    
    // MARK: - Network Loading
    
    private func loadImageFromNetwork(
        id: String,
        size: Int,
        requestKey: String,
        staggerIndex: Int,
        type: CoverArtType
    ) async -> UIImage? {
        guard let service = service else {
            await MainActor.run {
                errorStates[requestKey] = "Media service not available"
            }
            AppLogger.general.error("Network load failed: Service not available")
            return nil
        }
        
        await MainActor.run {
            loadingStates[requestKey] = true
        }
        
        defer {
            Task { @MainActor in
                loadingStates[requestKey] = false
            }
        }
        
        // Stagger requests to avoid overwhelming the server
        if staggerIndex > 0 {
            try? await Task.sleep(nanoseconds: UInt64(staggerIndex * 100_000_000))
        }
        
        if let image = await service.getCoverArt(for: id, size: size) {
            storeImage(image, forId: id, type: type, size: size)
            
            await MainActor.run {
                _ = errorStates.removeValue(forKey: requestKey)
            }
            
            // Store in disk cache
            let diskCacheKey = "\(type.name)_\(id)_\(size)"
            persistentCache.store(image, for: diskCacheKey, size: size)
            
            AppLogger.general.info("Network load SUCCESS: \(requestKey)")
            return image
        } else {
            await MainActor.run {
                errorStates[requestKey] = "Failed to load image"
            }
            AppLogger.general.error("Network load FAILED: \(requestKey)")
            return nil
        }
    }
    
    
    // MARK: - Image Storage

    private func storeImage(
        _ image: UIImage,
        forId id: String,
        type: CoverArtType,
        size: Int
    ) {
        let cacheKey = "\(id)_\(size)" as NSString
        let cache = type.getCache(from: self)
        
        let coverArt = AlbumCoverArt(image: image, size: size)
        let cost = coverArt.memoryFootprint
        cache.setObject(coverArt, forKey: cacheKey, cost: cost)
        
        AppLogger.general.debug("Stored in memory cache: \(type.name)_\(id)_\(size)px (cost: \(cost) bytes)")
        notifyChange()
    }
    
    private func notifyChange() {
        Task { @MainActor in
            self._cacheVersion += 1
            self.objectWillChange.send()
        }
    }
    
    // MARK: - State Queries
    
    func isLoadingImage(for key: String, size: Int) -> Bool {
        let requestKey = "\(key)_\(size)"
        return loadingStates[requestKey] == true
    }
    
    func getImageError(for key: String, size: Int) -> String? {
        let requestKey = "\(key)_\(size)"
        return errorStates[requestKey]
    }
    
    // MARK: - Intelligent Preloading
    
    func preloadForFullscreen(albumId: String) {
        Task(priority: .userInitiated) {
            _ = await loadAlbumImage(for: albumId, context: .fullscreen)
            AppLogger.general.debug("Preloaded fullscreen image for album: \(albumId)")
        }
    }
    
    func preloadAlbums(_ albums: [Album], context: ImageContext) async {
        await preloadCoverArt(
            items: albums,
            type: .album,
            context: context,
            priority: .immediate,
            getId: { $0.id }
        )
    }

    func preloadArtists(_ artists: [Artist], context: ImageContext) async {
        await preloadCoverArt(
            items: artists,
            type: .artist,
            context: context,
            priority: .immediate,
            getId: { $0.id }
        )
    }

    func preloadWhenIdle(_ albums: [Album], context: ImageContext) {
        Task(priority: .background) {
            await preloadCoverArt(
                items: albums,
                type: .album,
                context: context,
                priority: .background,
                getId: { $0.id }
            )
        }
    }

    func preloadArtistsWhenIdle(_ artists: [Artist], context: ImageContext) {
        Task(priority: .background) {
            await preloadCoverArt(
                items: artists,
                type: .artist,
                context: context,
                priority: .background,
                getId: { $0.id }
            )
        }
    }
    func preloadAlbumsControlled(_ albums: [Album], context: ImageContext) async {
        await preloadCoverArt(
            items: albums,
            type: .album,
            context: context,
            priority: .controlled,
            getId: { $0.id }
        )
    }
    
    private func preloadCoverArt<T>(
        items: [T],
        type: CoverArtType,
        context: ImageContext,
        priority: PreloadPriority = .immediate,
        getId: @escaping (T) -> String
    ) async {
        let itemIds = items.map(getId)
        let currentHash = itemIds.hashValue
        
        guard currentHash != lastPreloadHash else { 
            AppLogger.general.debug("Skipping preload - same content hash")
            return 
        }
        
        currentPreloadTask?.cancel()
        lastPreloadHash = currentHash
        
        let size = context.size
        
        AppLogger.general.info("Starting preload: \(items.count) items, size: \(size)px, priority: \(priority)")
        
        currentPreloadTask = Task {
            guard service != nil else { return }
            
            switch priority {
            case .immediate:
                await withTaskGroup(of: Void.self) { group in
                    for (index, item) in items.enumerated().prefix(5) {
                        let id = getId(item)
                        if getCachedImage(for: id, cache: type.getCache(from: self), size: size) == nil {
                            group.addTask {
                                _ = await self.loadCoverArt(id: id, type: type, size: size, staggerIndex: index)
                            }
                        }
                    }
                }
                
            case .background:
                for (index, item) in items.enumerated() {
                    guard !Task.isCancelled else { break }
                    let id = getId(item)
                    if getCachedImage(for: id, cache: type.getCache(from: self), size: size) == nil {
                        _ = await self.loadCoverArt(id: id, type: type, size: size)
                        if index < items.count - 1 {
                            try? await Task.sleep(nanoseconds: 200_000_000)
                        }
                    }
                }
                
            case .controlled:
                await withTaskGroup(of: Void.self) { group in
                    for item in items.prefix(10) {
                        let id = getId(item)
                        if getCachedImage(for: id, cache: type.getCache(from: self), size: size) == nil {
                            group.addTask {
                                await self.preloadSemaphore.wait()
                                defer { Task { await self.preloadSemaphore.signal() } }
                                _ = await self.loadCoverArt(id: id, type: type, size: size)
                            }
                        }
                    }
                }
            }
        }
        
        await currentPreloadTask?.value
        AppLogger.general.info("Preload completed")
    }
        
    // MARK: - Cache Management
    
    func clearMemoryCache() {
        albumCache.removeAllObjects()
        artistCache.removeAllObjects()
        loadingStates.removeAll()
        errorStates.removeAll()
        incrementCacheGeneration()
        persistentCache.clearCache()
 
        AppLogger.general.info("All caches cleared")
    }


    // MARK: - Diagnostics
    
    func getCacheStats() -> CoverArtCacheStats {
        let persistentStats = persistentCache.getCacheStats()
        
        return CoverArtCacheStats(
            diskCount: persistentStats.diskCount,
            diskSize: persistentStats.diskSize,
            activeRequests: loadingStates.count,
            errorCount: errorStates.count
        )
    }
    
    func getHealthStatus() -> CoverArtHealthStatus {
        let stats = getCacheStats()
        
        let totalActivity = stats.activeRequests + stats.errorCount
        let errorRate = totalActivity > 0 ? Double(stats.errorCount) / Double(totalActivity) : 0.0
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
        AppLogger.general.info("Performance stats reset")
    }
    
    func printDiagnostics() {
        let stats = getCacheStats()
        let health = getHealthStatus()
        
        AppLogger.general.info("""
        COVERARTMANAGER DIAGNOSTICS:
        Health: \(health.statusDescription)
        \(stats.summary)
        
        Multi-Size Cache Architecture (Hybrid):
        - Size-specific memory cache (no upscaling)
        - Intelligent downscaling from larger versions
        - Album Cache: \(CacheLimits.albumCount) entries, \(CacheLimits.albumMemory / 1024 / 1024)MB
        - Artist Cache: \(CacheLimits.artistCount) entries, \(CacheLimits.artistMemory / 1024 / 1024)MB
        - Cache Version: \(cacheVersion)
        
        Service: \(service != nil ? "Available" : "Not Available")
        """)
    }
}

// MARK: - Supporting Types

struct CoverArtCacheStats {
    let diskCount: Int
    let diskSize: Int64
    let activeRequests: Int
    let errorCount: Int
    
    var summary: String {
        return "Disk: \(diskCount), Active: \(activeRequests), Errors: \(errorCount)"
    }
}

struct CoverArtHealthStatus {
    let isHealthy: Bool
    let statusDescription: String
}

// MARK: - AsyncSemaphore

actor AsyncSemaphore {
    private var value: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []
    
    init(value: Int) {
        self.value = value
    }
    
    func wait() async {
        if value > 0 {
            value -= 1
            return
        }
        
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
    
    func signal() {
        if let waiter = waiters.first {
            waiters.removeFirst()
            waiter.resume()
        } else {
            value += 1
        }
    }
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
