//
//  CoverArtManager.swift
//  NavidromeClient
//
//  Manages album and artist cover art with multi-layer caching:
//  - Memory cache (NSCache) for fast access
//  - Persistent disk cache for offline availability
//  - Published state for immediate UI updates
//

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
    
    // MARK: - Storage
    
    // Multi-size cache storage
    private let albumCache = NSCache<NSString, AlbumCoverArt>()
    private let artistCache = NSCache<NSString, AlbumCoverArt>()
    
    // Published state for immediate UI access
    @Published private var albumImages: [String: UIImage] = [:]
    @Published private var artistImages: [String: UIImage] = [:]
    
    // UI state management
    @Published private(set) var loadingStates: [String: Bool] = [:]
    @Published private(set) var errorStates: [String: String] = [:]
    
    // MARK: - Dependencies
    
    private weak var mediaService: MediaService?
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
    
    func configure(mediaService: MediaService) {
        self.mediaService = mediaService
        print("CoverArtManager configured with MediaService")
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
        return getCachedImage(
            for: albumId,
            from: albumImages,
            cache: albumCache,
            size: size
        )
    }
    
    func getArtistImage(for artistId: String, size: Int) -> UIImage? {
        return getCachedImage(
            for: artistId,
            from: artistImages,
            cache: artistCache,
            size: size
        )
    }
    
    func getSongImage(for song: Song, size: Int) -> UIImage? {
        guard let albumId = song.albumId else { return nil }
        return getAlbumImage(for: albumId, size: size)
    }
    
    private func getCachedImage(
        for id: String,
        from publishedImages: [String: UIImage],
        cache: NSCache<NSString, AlbumCoverArt>,
        size: Int
    ) -> UIImage? {
        // Check published state first for immediate UI access
        if let publishedImage = publishedImages[id] {
            return scaleImageIfNeeded(publishedImage, to: size)
        }
        
        // Fallback to memory cache
        let key = id as NSString
        if let coverArt = cache.object(forKey: key) {
            return coverArt.getImage(for: size)
        }
        
        return nil
    }
    
    // MARK: - Image Loading
    
    func loadAlbumImage(
        album: Album,
        size: Int = OptimalSizes.album,
        staggerIndex: Int = 0
    ) async -> UIImage? {
        let albumKey = album.id as NSString
        let requestKey = "album_\(album.id)_\(size)"
        
        // Check memory cache first
        if let coverArt = albumCache.object(forKey: albumKey) {
            return coverArt.getImage(for: size)
        }
        
        // Prevent duplicate requests
        if isRequestActive(album.id, type: "album") {
            return nil
        }
        
        addActiveRequest(album.id, type: "album")
        defer { removeActiveRequest(album.id, type: "album") }
        
        // Check persistent cache
        let cacheKey = "album_\(album.id)_\(OptimalSizes.album)"
        if let cached = persistentCache.image(for: cacheKey) {
            await MainActor.run {
                storeAlbumImage(cached, forAlbumId: album.id, size: OptimalSizes.album)
            }
            return albumCache.object(forKey: albumKey)?.getImage(for: size)
        }
        
        // Load from network
        return await loadImageFromNetwork(
            id: album.id,
            size: OptimalSizes.album,
            requestKey: requestKey,
            staggerIndex: staggerIndex,
            cacheKey: cacheKey,
            storeAction: { [weak self] image in
                await self?.storeAlbumImage(image, forAlbumId: album.id, size: OptimalSizes.album)
            }
        )
    }
    
    func loadArtistImage(
        artist: Artist,
        size: Int = OptimalSizes.artist,
        staggerIndex: Int = 0
    ) async -> UIImage? {
        let artistKey = artist.id as NSString
        let requestKey = "artist_\(artist.id)_\(size)"
        
        // Check memory cache first
        if let coverArt = artistCache.object(forKey: artistKey) {
            return coverArt.getImage(for: size)
        }
        
        // Prevent duplicate requests
        if isRequestActive(artist.id, type: "artist") {
            return nil
        }
        
        addActiveRequest(artist.id, type: "artist")
        defer { removeActiveRequest(artist.id, type: "artist") }
        
        // Check persistent cache
        let cacheKey = "artist_\(artist.id)_\(OptimalSizes.artist)"
        if let cached = persistentCache.image(for: cacheKey) {
            await MainActor.run {
                storeArtistImage(cached, forArtistId: artist.id, size: OptimalSizes.artist)
            }
            return artistCache.object(forKey: artistKey)?.getImage(for: size)
        }
        
        // Load from network
        return await loadImageFromNetwork(
            id: artist.id,
            size: OptimalSizes.artist,
            requestKey: requestKey,
            staggerIndex: staggerIndex,
            cacheKey: cacheKey,
            storeAction: { [weak self] image in
                await self?.storeArtistImage(image, forArtistId: artist.id, size: OptimalSizes.artist)
            }
        )
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
        guard let service = mediaService else {
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
    
    private func storeAlbumImage(_ image: UIImage, forAlbumId albumId: String, size: Int) {
        storeImageInCache(
            image,
            forId: albumId,
            size: size,
            cache: albumCache,
            optimalSize: OptimalSizes.album,
            type: "album"
        )
        
        // Update published state for immediate UI access
        albumImages[albumId] = image
    }
    
    private func storeArtistImage(_ image: UIImage, forArtistId artistId: String, size: Int) {
        storeImageInCache(
            image,
            forId: artistId,
            size: size,
            cache: artistCache,
            optimalSize: OptimalSizes.artist,
            type: "artist"
        )
        
        // Update published state for immediate UI access
        artistImages[artistId] = image
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
    
    func preloadAlbums(_ albums: [Album], size: Int = OptimalSizes.album) async {
        let albumIds = albums.map(\.id)
        let currentHash = albumIds.hashValue
        
        // Skip if same albums already being preloaded
        guard currentHash != lastPreloadHash else { return }
        
        // Cancel existing preload task
        currentPreloadTask?.cancel()
        lastPreloadHash = currentHash
        
        currentPreloadTask = Task {
            guard mediaService != nil else { return }
            
            await withTaskGroup(of: Void.self) { group in
                for (index, album) in albums.enumerated() {
                    if index >= 5 { break } // Limit concurrent preloads
                    
                    // Only preload if not already cached
                    if getAlbumImage(for: album.id, size: size) == nil {
                        group.addTask {
                            _ = await self.loadAlbumImage(album: album, size: size, staggerIndex: index)
                        }
                    }
                }
            }
        }
        
        await currentPreloadTask?.value
    }
    
    func preloadArtists(_ artists: [Artist], size: Int = OptimalSizes.artist) async {
        let artistIds = artists.map(\.id)
        let currentHash = artistIds.hashValue
        
        guard currentHash != lastPreloadHash else { return }
        
        currentPreloadTask?.cancel()
        lastPreloadHash = currentHash
        
        currentPreloadTask = Task {
            guard mediaService != nil else { return }
            
            await withTaskGroup(of: Void.self) { group in
                for (index, artist) in artists.enumerated() {
                    if index >= 5 { break }
                    
                    if getArtistImage(for: artist.id, size: size) == nil {
                        group.addTask {
                            _ = await self.loadArtistImage(artist: artist, size: size, staggerIndex: index)
                        }
                    }
                }
            }
        }
        
        await currentPreloadTask?.value
    }
    
    func preloadWhenIdle(_ albums: [Album], size: Int = OptimalSizes.album) {
        Task(priority: .background) {
            for (index, album) in albums.enumerated() {
                guard !Task.isCancelled else { break }
                
                if getAlbumImage(for: album.id, size: size) == nil {
                    _ = await loadAlbumImage(album: album, size: size)
                    
                    // Gentle delay between loads
                    if index < albums.count - 1 {
                        try? await Task.sleep(nanoseconds: 200_000_000)
                    }
                }
            }
        }
    }
    
    func preloadArtistsWhenIdle(_ artists: [Artist], size: Int = OptimalSizes.artist) {
        Task(priority: .background) {
            for (index, artist) in artists.enumerated() {
                guard !Task.isCancelled else { break }
                
                if getArtistImage(for: artist.id, size: size) == nil {
                    _ = await loadArtistImage(artist: artist, size: size)
                    
                    if index < artists.count - 1 {
                        try? await Task.sleep(nanoseconds: 200_000_000)
                    }
                }
            }
        }
    }
    
    func preloadAlbumsControlled(_ albums: [Album], size: Int = OptimalSizes.album) async {
        await withTaskGroup(of: Void.self) { group in
            for album in albums.prefix(10) {
                if getAlbumImage(for: album.id, size: size) == nil {
                    group.addTask {
                        await self.preloadSemaphore.wait()
                        defer {
                            Task { await self.preloadSemaphore.signal() }
                        }
                        
                        _ = await self.loadAlbumImage(album: album, size: size)
                    }
                }
            }
        }
    }
    
    // MARK: - Cache Management
    
    func clearMemoryCache() {
        albumCache.removeAllObjects()
        artistCache.removeAllObjects()
        loadingStates.removeAll()
        errorStates.removeAll()
        albumImages.removeAll()
        artistImages.removeAll()
        persistentCache.clearCache()
        
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
        - Published Images: \(albumImages.count) albums, \(artistImages.count) artists
        
        Service: \(mediaService != nil ? "Available" : "Not Available")
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
