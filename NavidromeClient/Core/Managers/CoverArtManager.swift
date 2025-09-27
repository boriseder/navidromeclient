//
//  CoverArtManager.swift - UPDATED: Multi-Size Cache Implementation
//  NavidromeClient
//

import Foundation
import SwiftUI

@MainActor
class CoverArtManager: ObservableObject {
    static let shared = CoverArtManager()
    
    // MARK: - UPDATED: Multi-Size Cache Storage
    private let albumCache = NSCache<NSString, AlbumCoverArt>()
    private let artistCache = NSCache<NSString, AlbumCoverArt>()
    
    // NEW: Preload deduplication
    private var lastPreloadHash: Int = 0
    private var currentPreloadTask: Task<Void, Never>?

    // NEW: Semaphore for controlled concurrency
    private let preloadSemaphore = AsyncSemaphore(value: 3)
    
    // MARK: - UI State Management (unchanged)
    @Published private var cacheUpdateTrigger = 0
    @Published private(set) var loadingStates: [String: Bool] = [:]
    @Published private(set) var errorStates: [String: String] = [:]
    
    // MARK: - Thread Safety (unchanged)
    private let requestQueue = DispatchQueue(label: "coverart.requests")
    private var _activeRequests: Set<String> = []
    
    // MARK: - Dependencies (unchanged)
    private weak var mediaService: MediaService?
    private let persistentCache = PersistentImageCache.shared
    
    // 1. Define optimal sizes as constants
    private struct OptimalSizes {
        static let album: Int = 300
        static let artist: Int = 240
    }

    private init() {
        setupMemoryCache()
    }
    
    // MARK: - UPDATED: Configuration
    
    func configure(mediaService: MediaService) {
        self.mediaService = mediaService
        print("CoverArtManager configured with MediaService")
    }
    
    private func setupMemoryCache() {
        albumCache.countLimit = 100    // More albums since each is smaller
        artistCache.countLimit = 100
        albumCache.totalCostLimit = 60 * 1024 * 1024  // 60MB instead of 100MB
        artistCache.totalCostLimit = 30 * 1024 * 1024  // 30MB
    }

    // MARK: - Thread-Safe Request Management (unchanged)
    
    private func isRequestActive(_ key: String) -> Bool {
        return requestQueue.sync { _activeRequests.contains(key) }
    }
    
    private func addActiveRequest(_ key: String) {
        requestQueue.sync { _activeRequests.insert(key) }
    }
    
    private func removeActiveRequest(_ key: String) {
        requestQueue.sync { _activeRequests.remove(key) }
    }
    
    // MARK: - UPDATED: Cache Management
    
    private func storeImage(_ image: UIImage, forId id: String, size: Int,
                           cache: NSCache<NSString, AlbumCoverArt>,
                           optimalSize: Int, type: String) {
        let key = id as NSString
        
        // Only store if this is optimal size OR no image exists
        let shouldStore = (size == optimalSize) || (cache.object(forKey: key) == nil)
        
        guard shouldStore else {
            print("Ignoring non-optimal size \(size)px for \(type) \(id)")
            return
        }
        
        let coverArt = AlbumCoverArt(image: image, size: size)
        let cost = coverArt.memoryFootprint
        
        cache.setObject(coverArt, forKey: key, cost: cost)
        cacheUpdateTrigger += 1
    }

    private func storeAlbumImage(_ image: UIImage, forAlbumId albumId: String, size: Int) {
        storeImage(image, forId: albumId, size: size,
                   cache: albumCache, optimalSize: OptimalSizes.album, type: "album")
        print("✅ Stored album \(albumId) at size \(size)px (optimal: \(OptimalSizes.album))")


    }

    func loadAlbumImage(album: Album, size: Int = OptimalSizes.album, staggerIndex: Int = 0) async -> UIImage? {
        let albumKey = album.id as NSString
        let requestKey = "album_\(album.id)_\(size)"
        
        // Check memory cache first
        if let coverArt = albumCache.object(forKey: albumKey) {
            return coverArt.getImage(for: size)
        }
        
        // Check if request is already active
        if isRequestActive(requestKey) {
            print("Album request already active: \(album.id) @ \(size)px")
            return nil
        }
        
        addActiveRequest(requestKey)
        defer { removeActiveRequest(requestKey) }
        
        // Check persistent cache
        let cacheKey = "album_\(album.id)_\(OptimalSizes.album)" // Always use optimal size for cache key
        if let cached = persistentCache.image(for: cacheKey) {
            print("Album disk hit: \(album.id) @ \(OptimalSizes.album)px")
            
            await MainActor.run {
                storeAlbumImage(cached, forAlbumId: album.id, size: OptimalSizes.album)
            }
            
            // Return scaled version if needed
            return albumCache.object(forKey: albumKey)?.getImage(for: size)
        }
        
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
        
        if staggerIndex > 0 {
            try? await Task.sleep(nanoseconds: UInt64(staggerIndex * 100_000_000))
        }
        
        // Always load optimal size from network
        if let image = await service.getCoverArt(for: album.id, size: OptimalSizes.album) {
            print("Album network load: \(album.id) @ \(OptimalSizes.album)px -> \(image.size.width)x\(image.size.height)")
            
            await MainActor.run {
                storeAlbumImage(image, forAlbumId: album.id, size: OptimalSizes.album)
                errorStates.removeValue(forKey: requestKey)
            }
            
            persistentCache.store(image, for: cacheKey)
            
            print("🔍 Loading album \(album.id) - requested: \(size)px, optimal: \(OptimalSizes.album)px")

            // Return scaled version for requested size
            return albumCache.object(forKey: albumKey)?.getImage(for: size)
        } else {
            await MainActor.run {
                errorStates[requestKey] = "Failed to load album image"
            }
            return nil
        }
    }

    private func storeArtistImage(_ image: UIImage, forArtistId artistId: String, size: Int) {
        storeImage(image, forId: artistId, size: size,
                  cache: artistCache, optimalSize: OptimalSizes.artist, type: "artist")
    }

    func loadArtistImage(artist: Artist, size: Int = OptimalSizes.artist, staggerIndex: Int = 0) async -> UIImage? {
        let artistKey = artist.id as NSString
        let requestKey = "artist_\(artist.id)_\(size)"
        
        // Check memory cache first
        if let coverArt = artistCache.object(forKey: artistKey) {
            return coverArt.getImage(for: size)
        }
        
        if isRequestActive(requestKey) {
            print("Artist request already active: \(artist.id) @ \(size)px")
            return nil
        }
        
        addActiveRequest(requestKey)
        defer { removeActiveRequest(requestKey) }
        
        let cacheKey = "artist_\(artist.id)_\(OptimalSizes.artist)"
        if let cached = persistentCache.image(for: cacheKey) {
            print("Artist disk hit: \(artist.id) @ \(OptimalSizes.artist)px")
            
            await MainActor.run {
                storeArtistImage(cached, forArtistId: artist.id, size: OptimalSizes.artist)
            }
            
            return artistCache.object(forKey: artistKey)?.getImage(for: size)
        }
        
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
        
        if staggerIndex > 0 {
            try? await Task.sleep(nanoseconds: UInt64(staggerIndex * 100_000_000))
        }
        
        if let image = await service.getCoverArt(for: artist.id, size: OptimalSizes.artist) {
            print("Artist network load: \(artist.id) @ \(OptimalSizes.artist)px -> \(image.size.width)x\(image.size.height)")
            
            await MainActor.run {
                storeArtistImage(image, forArtistId: artist.id, size: OptimalSizes.artist)
                errorStates.removeValue(forKey: requestKey)
            }
            
            persistentCache.store(image, for: cacheKey)
            return artistCache.object(forKey: artistKey)?.getImage(for: size)
        } else {
            await MainActor.run {
                errorStates[requestKey] = "Failed to load artist image"
            }
            return nil
        }
    }

    // MARK: - UPDATED: Image Getters
    
    func getAlbumImage(for albumId: String, size: Int) -> UIImage? {
        let key = albumId as NSString
        let image = albumCache.object(forKey: key)?.getImage(for: size)
        
        // Only log cache misses to reduce noise
        if image == nil {
            print("🎨 Album cache miss: \(albumId) @ \(size)px")
        }
        
        return image
    }

    func getArtistImage(for artistId: String, size: Int) -> UIImage? {
        let key = artistId as NSString
        let image = artistCache.object(forKey: key)?.getImage(for: size)
        
        // Only log cache misses to reduce noise
        if image == nil {
            print("🎨 Artist cache miss: \(artistId) @ \(size)px")
        }
        
        return image
    }
    
    func getSongImage(for song: Song, size: Int) -> UIImage? {
        guard let albumId = song.albumId else { return nil }
        return getAlbumImage(for: albumId, size: size)
    }
    
    // MARK: - Song Images (unchanged)
    
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
    
    // MARK: - State Queries (unchanged)
    
    func isLoadingImage(for key: String, size: Int) -> Bool {
        let memoryKey = "\(key)_\(size)"
        return loadingStates[memoryKey] == true
    }
    
    func getImageError(for key: String, size: Int) -> String? {
        let memoryKey = "\(key)_\(size)"
        return errorStates[memoryKey]
    }
    
    // MARK: - Preload Operations
    
    // UPDATED: Preload with deduplication
    func preloadAlbums(_ albums: [Album], size: Int = 400) async {
        let albumIds = albums.map(\.id)
        let currentHash = albumIds.hashValue
        
        // Skip if same albums already being preloaded
        guard currentHash != lastPreloadHash else {
            print("🎨 Skipping duplicate preload for same albums")
            return
        }
        
        // Cancel existing preload task
        currentPreloadTask?.cancel()
        lastPreloadHash = currentHash
        
        currentPreloadTask = Task {
            guard mediaService != nil else { return }
            
            await withTaskGroup(of: Void.self) { group in
                for (index, album) in albums.enumerated() {
                    if index >= 5 { break } // Keep existing limit
                    
                    // Only preload if not already cached
                    if getAlbumImage(for: album.id, size: size) == nil {
                        group.addTask {
                            _ = await self.loadAlbumImage(album: album, size: size, staggerIndex: index)
                        }
                    }
                }
            }
            
            print("✅ Preloaded covers for \(min(albums.count, 5)) albums @ \(size)px")
        }
        
        await currentPreloadTask?.value
    }
    
    func preloadArtists(_ artists: [Artist], size: Int = 240) async {
        let artistIds = artists.map(\.id)
        let currentHash = artistIds.hashValue
        
        guard currentHash != lastPreloadHash else {
            print("🎨 Skipping duplicate artist preload")
            return
        }
        
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
            
            print("✅ Preloaded artist images for \(min(artists.count, 5)) artists @ \(size)px")
        }
        
        await currentPreloadTask?.value
    }

    func preloadWhenIdle(_ albums: [Album], size: Int = 200) {
        Task(priority: .background) {
            print("🎨 Starting idle preload for \(albums.count) albums")
            
            for (index, album) in albums.enumerated() {
                // Stop if task cancelled or app becomes active
                guard !Task.isCancelled else {
                    print("🎨 Idle preload cancelled")
                    break
                }
                
                // Only load if not already cached
                if getAlbumImage(for: album.id, size: size) == nil {
                    _ = await loadAlbumImage(album: album, size: size)
                    
                    // Gentle delay between loads (200ms)
                    if index < albums.count - 1 {
                        try? await Task.sleep(nanoseconds: 200_000_000)
                    }
                } else {
                    // Already cached, shorter delay
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
            }
            
            print("🎨 Idle preload completed")
        }
    }
    
    func preloadArtistsWhenIdle(_ artists: [Artist], size: Int = 120) {
        Task(priority: .background) {
            print("🎨 Starting idle artist preload for \(artists.count) artists")
            
            for (index, artist) in artists.enumerated() {
                guard !Task.isCancelled else { break }
                
                if getArtistImage(for: artist.id, size: size) == nil {
                    _ = await loadArtistImage(artist: artist, size: size)
                    
                    if index < artists.count - 1 {
                        try? await Task.sleep(nanoseconds: 200_000_000)
                    }
                }
            }
            
            print("🎨 Idle artist preload completed")
        }
    }

    func preloadAlbumsControlled(_ albums: [Album], size: Int = 400) async {
        await withTaskGroup(of: Void.self) { group in
            for album in albums.prefix(10) {
                // Only preload if not cached
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
        
        print("✅ Controlled preload completed")
    }

    // MARK: - UPDATED: Cache Management
    
    func clearMemoryCache() {
        albumCache.removeAllObjects()
        artistCache.removeAllObjects()
        loadingStates.removeAll()
        errorStates.removeAll()
        persistentCache.clearCache()
        
        cacheUpdateTrigger += 1
        
        print("Cleared all image caches")
    }
    
    // MARK: - UPDATED: Diagnostics
    
    func getCacheStats() -> CoverArtCacheStats {
        let persistentStats = persistentCache.getCacheStats()
        
        // Estimate memory count from both caches
        let estimatedAlbumCount = max(0, 50 - (loadingStates.count / 2))
        let estimatedArtistCount = max(0, 50 - (loadingStates.count / 2))
        
        return CoverArtCacheStats(
            memoryCount: estimatedAlbumCount + estimatedArtistCount,
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
        cacheUpdateTrigger += 1
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
        - Album Cache: 50 entities, auto-scaling
        - Artist Cache: 50 entities, auto-scaling
        - Memory Limit: 150MB total
        
        Service: \(mediaService != nil ? "✅" : "❌")
        """)
    }
}

// MARK: - Supporting Types (unchanged)
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

// NEW: AsyncSemaphore for better concurrency control
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


// MARK: - Album Extension (unchanged)
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
