//
//  CoverArtManager.swift
//  NavidromeClient
//
//  REFACTORED: Context-aware multi-size caching
//  - Load optimal size based on display context
//  - Persistent multi-size disk cache
//  - Intelligent preloading for fullscreen
//

import Foundation
import SwiftUI

@MainActor
class CoverArtManager: ObservableObject {
    
    // MARK: - Cache Configuration
    
    private struct CacheLimits {
        static let albumCount: Int = 150
        static let artistCount: Int = 100
        static let albumMemory: Int = 80 * 1024 * 1024  // 80MB
        static let artistMemory: Int = 40 * 1024 * 1024 // 40MB
    }
    
    private enum CoverArtType {
        case album
        case artist
        
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
        
    @Published private(set) var loadingStates: [String: Bool] = [:]
    @Published private(set) var errorStates: [String: String] = [:]

    // MARK: - Dependencies
    
    private weak var service: UnifiedSubsonicService?
    private let persistentCache = PersistentImageCache.shared
    
    // MARK: - Concurrency Control
    
    private let requestQueue = DispatchQueue(label: "coverart.requests")
    private var activeRequests: Set<String> = []
    
    private var lastPreloadHash: Int = 0
    private var currentPreloadTask: Task<Void, Never>?
    private let preloadSemaphore = AsyncSemaphore(value: 3)
    
    // MARK: - Initialization
    
    init() {
        setupMemoryCache()
        setupFactoryResetObserver()
    }
    
    func configure(service: UnifiedSubsonicService) {
        self.service = service
        AppLogger.general.info("CoverArtManager configured with UnifiedSubsonicService")
    }

    private func setupMemoryCache() {
        albumCache.countLimit = CacheLimits.albumCount
        albumCache.totalCostLimit = CacheLimits.albumMemory
        
        artistCache.countLimit = CacheLimits.artistCount
        artistCache.totalCostLimit = CacheLimits.artistMemory
    }
    
    private func setupFactoryResetObserver() {
        NotificationCenter.default.addObserver(
            forName: .factoryResetRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearMemoryCache()
            AppLogger.general.info("CoverArtManager: Cleared memory cache on factory reset")
        }
    }
    
    // MARK: - Thread-Safe Request Management
    
    private func isRequestActive(_ id: String, type: String, size: Int) -> Bool {
        return requestQueue.sync {
            activeRequests.contains("\(type)_\(id)_\(size)")
        }
    }
    
    private func addActiveRequest(_ id: String, type: String, size: Int) {
        requestQueue.sync {
            activeRequests.insert("\(type)_\(id)_\(size)")
        }
    }
    
    private func removeActiveRequest(_ id: String, type: String, size: Int) {
        requestQueue.sync {
            activeRequests.remove("\(type)_\(id)_\(size)")
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
    
    private func getCachedImage(
        for id: String,
        cache: NSCache<NSString, AlbumCoverArt>,
        size: Int
    ) -> UIImage? {
        let key = id as NSString
        if let coverArt = cache.object(forKey: key) {
            return coverArt.getImage(for: size)
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
        let key = id as NSString
        let cache = type.getCache(from: self)
        
        if let coverArt = cache.object(forKey: key),
           let image = coverArt.getImage(for: size) {
            return image
        }
        
        if isRequestActive(id, type: type.name, size: size) {
            return nil
        }
        
        addActiveRequest(id, type: type.name, size: size)
        defer { removeActiveRequest(id, type: type.name, size: size) }
        
        // FIXED: Include size in cache key for proper multi-size storage
        let cacheKey = "\(type.name)_\(id)_\(size)"
        if let cached = persistentCache.image(for: cacheKey, size: size) {
            storeImage(cached, forId: id, type: type, size: size)
            // FIXED: Return cached image directly, not from memory cache lookup
            return cached
        }
        
        return await loadImageFromNetwork(
            id: id,
            size: size,
            requestKey: "\(type.name)_\(id)_\(size)",
            staggerIndex: staggerIndex,
            cacheKey: cacheKey,
            type: type
        )
    }
    
    // MARK: - Network Loading
    
    private func loadImageFromNetwork(
        id: String,
        size: Int,
        requestKey: String,
        staggerIndex: Int,
        cacheKey: String,
        type: CoverArtType
    ) async -> UIImage? {
        guard let service = service else {
            await MainActor.run {
                errorStates[requestKey] = "Media service not available"
            }
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
        
        if staggerIndex > 0 {
            try? await Task.sleep(nanoseconds: UInt64(staggerIndex * 100_000_000))
        }
        
        if let image = await service.getCoverArt(for: id, size: size) {
            await storeImage(image, forId: id, type: type, size: size)
            await MainActor.run {
                errorStates.removeValue(forKey: requestKey)
            }
            
            // FIXED: Store with size-specific key
            let sizedCacheKey = "\(type.name)_\(id)_\(size)"
            persistentCache.store(image, for: sizedCacheKey, size: size)
            return image
        } else {
            await MainActor.run {
                errorStates[requestKey] = "Failed to load image"
            }
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
        let key = id as NSString
        let cache = type.getCache(from: self)
        
        let coverArt: AlbumCoverArt
        if let existing = cache.object(forKey: key) {
            coverArt = existing
        } else {
            coverArt = AlbumCoverArt(image: image, size: size)
            let cost = coverArt.memoryFootprint
            cache.setObject(coverArt, forKey: key, cost: cost)
        }
        
        notifyChange()
        
        Task {
            await coverArt.preloadSize(size)
            await MainActor.run {
                self.notifyChange()
            }
        }
    }
    
    private func notifyChange() {
        cacheQueue.async(flags: .barrier) {
            self._cacheVersion += 1
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
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
        
        guard currentHash != lastPreloadHash else { return }
        
        currentPreloadTask?.cancel()
        lastPreloadHash = currentHash
        
        let size = context.size
        
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
    }
    
    // MARK: - Cache Management
    
    func clearMemoryCache() {
        albumCache.removeAllObjects()
        artistCache.removeAllObjects()
        loadingStates.removeAll()
        errorStates.removeAll()
        persistentCache.clearCache()
    }

    // MARK: - Diagnostics
    
    func getCacheStats() -> CoverArtCacheStats {
        let persistentStats = persistentCache.getCacheStats()
        
        return CoverArtCacheStats(
            memoryCount: 0,
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
        AppLogger.general.info("CoverArtManager: Performance stats reset")
    }
    
    func printDiagnostics() {
        let stats = getCacheStats()
        let health = getHealthStatus()
        
        AppLogger.general.info("""
        COVERARTMANAGER DIAGNOSTICS:
        Health: \(health.statusDescription)
        \(stats.summary)
        
        Multi-Size Cache Architecture:
        - Album Cache: \(CacheLimits.albumCount) entities, \(CacheLimits.albumMemory / 1024 / 1024)MB
        - Artist Cache: \(CacheLimits.artistCount) entities, \(CacheLimits.artistMemory / 1024 / 1024)MB
        - Cache Version: \(cacheVersion)
        
        Service: \(service != nil ? "Available" : "Not Available")
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
        let hitRate = diskCount > 0 ? Double(diskCount) / Double(diskCount + activeRequests) * 100 : 0.0
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
