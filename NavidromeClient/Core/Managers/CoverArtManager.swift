//
//  CoverArtManager.swift
//  NavidromeClient
//
//  Manages album and artist cover art with multi-layer caching:
//  - Memory cache (NSCache) for fast access
//  - Persistent disk cache for offline availability
//  - Published state for immediate UI updates
//
//  CoverArtManager.swift
//  Manages cover art loading with multi-level caching
//  Responsibilities: Load/cache album and artist images, memory and disk cache

import Foundation
import SwiftUI

@MainActor
class CoverArtManager: ObservableObject {
    static let shared = CoverArtManager()
    
    // MARK: - Cache Configuration
    
    private struct OptimalSizes {
        static let album: Int = 300
        static let artist: Int = 240
    }
    
    private struct CacheLimits {
        static let albumCount: Int = 100
        static let artistCount: Int = 100
        static let albumMemory: Int = 60 * 1024 * 1024  // 60MB
        static let artistMemory: Int = 30 * 1024 * 1024 // 30MB
    }
    
    private enum CoverArtType {
        case album
        case artist
        
        var cache: NSCache<NSString, AlbumCoverArt> {
            switch self {
            case .album: return CoverArtManager.shared.albumCache
            case .artist: return CoverArtManager.shared.artistCache
            }
        }
        
        var optimalSize: Int {
            switch self {
            case .album: return OptimalSizes.album
            case .artist: return OptimalSizes.artist
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
    
    // Multi-size cache storage
    private let albumCache = NSCache<NSString, AlbumCoverArt>()
    private let artistCache = NSCache<NSString, AlbumCoverArt>()
        
    // UI state management
    @Published private(set) var loadingStates: [String: Bool] = [:]
    @Published private(set) var errorStates: [String: String] = [:]

    // MARK: - Dependencies
    
    private weak var service: UnifiedSubsonicService?
    private let persistentCache = PersistentImageCache.shared
    
    // MARK: - Concurrency Control
    
    private let requestQueue = DispatchQueue(label: "coverart.requests")
    private var activeRequests: Set<String> = []
    
    // Preload optimization
    private var lastPreloadHash: Int = 0
    private var currentPreloadTask: Task<Void, Never>?
    private let preloadSemaphore = AsyncSemaphore(value: 3)
    
    
    
    // MARK: - Initialization
    
    private init() {
        setupMemoryCache()
    }
    
    func configure(service: UnifiedSubsonicService) {
        self.service = service
        print("CoverArtManager configured with UnifiedSubsonicService")
    }

    private func setupMemoryCache() {
        albumCache.countLimit = CacheLimits.albumCount
        albumCache.totalCostLimit = CacheLimits.albumMemory
        
        artistCache.countLimit = CacheLimits.artistCount
        artistCache.totalCostLimit = CacheLimits.artistMemory
    }
    
    // MARK: - Thread-Safe Request Management
    
    private func isRequestActive(_ id: String, type: String) -> Bool {
        return requestQueue.sync {
            activeRequests.contains("\(type)_\(id)")
        }
    }
    
    private func addActiveRequest(_ id: String, type: String) {
        requestQueue.sync {
            activeRequests.insert("\(type)_\(id)")
        }
    }
    
    private func removeActiveRequest(_ id: String, type: String) {
        requestQueue.sync {
            activeRequests.remove("\(type)_\(id)")
        }
    }
    
    // MARK: - Image Retrieval
    
    func getAlbumImage(for albumId: String, size: Int) -> UIImage? {
        return getCachedImage(for: albumId, cache: albumCache, size: size)
    }

    func getArtistImage(for artistId: String, size: Int) -> UIImage? {
        return getCachedImage(for: artistId, cache: artistCache, size: size)
    }

    func getSongImage(for song: Song, size: Int) -> UIImage? {
        guard let albumId = song.albumId else { return nil }
        return getAlbumImage(for: albumId, size: size)
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

    // MARK: - Image Loading
    
    private func loadCoverArt(
        id: String,
        type: CoverArtType,
        size: Int,
        staggerIndex: Int = 0
    ) async -> UIImage? {
        let key = id as NSString
        let cache = type.cache
        
        // Check memory cache
        if let coverArt = cache.object(forKey: key) {
            return coverArt.getImage(for: size)
        }
        
        // Prevent duplicate requests
        if isRequestActive(id, type: type.name) {
            return nil
        }
        
        addActiveRequest(id, type: type.name)
        defer { removeActiveRequest(id, type: type.name) }
        
        // Check persistent cache
        let optimalSize = type.optimalSize
        let cacheKey = "\(type.name)_\(id)_\(optimalSize)"
        if let cached = persistentCache.image(for: cacheKey) {
            storeImage(cached, forId: id, type: type, size: optimalSize)
            return cache.object(forKey: key)?.getImage(for: size)
        }
        
        // Load from network
        return await loadImageFromNetwork(
            id: id,
            size: optimalSize,
            requestKey: "\(type.name)_\(id)_\(size)",
            staggerIndex: staggerIndex,
            cacheKey: cacheKey,
            storeAction: { [weak self] image in
                await MainActor.run {
                    self?.storeImage(image, forId: id, type: type, size: optimalSize)
                }
            }
        )
    }
    
    func loadAlbumImage(album: Album, size: Int = OptimalSizes.album, staggerIndex: Int = 0) async -> UIImage? {
        return await loadCoverArt(id: album.id, type: .album, size: size, staggerIndex: staggerIndex)
    }

    func loadArtistImage(artist: Artist, size: Int = OptimalSizes.artist, staggerIndex: Int = 0) async -> UIImage? {
        return await loadCoverArt(id: artist.id, type: .artist, size: size, staggerIndex: staggerIndex)
    }

    
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
    
    // MARK: - Network Loading Helper
    
    private func loadImageFromNetwork(
        id: String,
        size: Int,
        requestKey: String,
        staggerIndex: Int,
        cacheKey: String,
        storeAction: @escaping (UIImage) async -> Void
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
        
        // Stagger requests to prevent server overload
        if staggerIndex > 0 {
            try? await Task.sleep(nanoseconds: UInt64(staggerIndex * 100_000_000))
        }
        
        if let image = await service.getCoverArt(for: id, size: size) {
            await storeAction(image)
            await MainActor.run {
                errorStates.removeValue(forKey: requestKey)
            }
            
            persistentCache.store(image, for: cacheKey)
            return image
        } else {
            await MainActor.run {
                errorStates[requestKey] = "Failed to load image"
            }
            return nil
        }
    }
    
    // MARK: - Image Storage
    
    private func storeImage(_ image: UIImage, forId id: String, type: CoverArtType, size: Int) {
        storeImageInCache(
            image,
            forId: id,
            size: size,
            cache: type.cache,
            optimalSize: type.optimalSize,
            type: type.name
        )
        
        cacheQueue.async(flags: .barrier) {
            self._cacheVersion += 1
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }

    private func storeImageInCache(
        _ image: UIImage,
        forId id: String,
        size: Int,
        cache: NSCache<NSString, AlbumCoverArt>,
        optimalSize: Int,
        type: String
    ) {
        let key = id as NSString
        
        // Only store if this is optimal size OR no image exists
        let shouldStore = (size == optimalSize) || (cache.object(forKey: key) == nil)
        
        guard shouldStore else { return }
        
        let coverArt = AlbumCoverArt(image: image, size: size)
        let cost = coverArt.memoryFootprint
        
        cache.setObject(coverArt, forKey: key, cost: cost)
    }
    
    // MARK: - Image Scaling
    
    private func scaleImageIfNeeded(_ image: UIImage, to size: Int) -> UIImage {
        let currentSize = Int(max(image.size.width, image.size.height))
        if currentSize == size {
            return image
        }
        
        // Validate all dimensions
        guard size > 0 && size <= 4096,
              image.size.width > 0 && image.size.height > 0,
              image.size.width.isFinite && image.size.height.isFinite else {
            print("Invalid scaling parameters: target=\(size), source=\(image.size)")
            return image
        }
        
        let targetSize = CGSize(width: size, height: size)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
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
    
    // MARK: - Preload Operations
    
    private func preloadCoverArt<T>(
        items: [T],
        type: CoverArtType,
        priority: PreloadPriority = .immediate,
        getId: @escaping (T) -> String
    ) async {
        let itemIds = items.map(getId)
        let currentHash = itemIds.hashValue
        
        guard currentHash != lastPreloadHash else { return }
        
        currentPreloadTask?.cancel()
        lastPreloadHash = currentHash
        
        currentPreloadTask = Task {
            guard service != nil else { return }
            
            switch priority {
            case .immediate:
                await withTaskGroup(of: Void.self) { group in
                    for (index, item) in items.enumerated().prefix(5) {
                        let id = getId(item)
                        if getCachedImage(for: id, cache: type.cache, size: type.optimalSize) == nil {
                            group.addTask {
                                _ = await self.loadCoverArt(id: id, type: type, size: type.optimalSize, staggerIndex: index)
                            }
                        }
                    }
                }
                
            case .background:
                for (index, item) in items.enumerated() {
                    guard !Task.isCancelled else { break }
                    let id = getId(item)
                    if getCachedImage(for: id, cache: type.cache, size: type.optimalSize) == nil {
                        _ = await self.loadCoverArt(id: id, type: type, size: type.optimalSize)
                        if index < items.count - 1 {
                            try? await Task.sleep(nanoseconds: 200_000_000)
                        }
                    }
                }
                
            case .controlled:
                await withTaskGroup(of: Void.self) { group in
                    for item in items.prefix(10) {
                        let id = getId(item)
                        if getCachedImage(for: id, cache: type.cache, size: type.optimalSize) == nil {
                            group.addTask {
                                await self.preloadSemaphore.wait()
                                defer { Task { await self.preloadSemaphore.signal() } }
                                _ = await self.loadCoverArt(id: id, type: type, size: type.optimalSize)
                            }
                        }
                    }
                }
            }
        }
        
        await currentPreloadTask?.value
    }
    
    func preloadAlbums(_ albums: [Album], size: Int = OptimalSizes.album) async {
        await preloadCoverArt(items: albums, type: .album, priority: .immediate) { $0.id }
    }

    func preloadArtists(_ artists: [Artist], size: Int = OptimalSizes.artist) async {
        await preloadCoverArt(items: artists, type: .artist, priority: .immediate) { $0.id }
    }

    func preloadWhenIdle(_ albums: [Album], size: Int = OptimalSizes.album) {
        Task {
            await preloadCoverArt(items: albums, type: .album, priority: .background) { $0.id }
        }
    }

    func preloadArtistsWhenIdle(_ artists: [Artist], size: Int = OptimalSizes.artist) {
        Task {
            await preloadCoverArt(items: artists, type: .artist, priority: .background) { $0.id }
        }
    }

    func preloadAlbumsControlled(_ albums: [Album], size: Int = OptimalSizes.album) async {
        await preloadCoverArt(items: albums, type: .album, priority: .controlled) { $0.id }
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
            memoryCount: 0,  // NSCache doesn't expose count reliably
            diskCount: persistentStats.diskCount,
            diskSize: persistentStats.diskSize,
            activeRequests: loadingStates.count,
            errorCount: errorStates.count
        )
    }
    
    func getHealthStatus() -> CoverArtHealthStatus {
        let stats = getCacheStats()
        
        // Use activeRequests + errorCount as health indicator since memoryCount is unreliable
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
        print("CoverArtManager: Performance stats reset")
    }
    
    func printDiagnostics() {
        let stats = getCacheStats()
        let health = getHealthStatus()
        
        print("""
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
        // Use disk cache as proxy for hit rate
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

