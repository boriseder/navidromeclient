//
//  CoverArtManager.swift - REFACTORED from ReactiveCoverArtService
//  NavidromeClient
//
//  ✅ ENHANCED: Centralized image state management + component logic extraction
//

import Foundation
import SwiftUI

@MainActor
class CoverArtManager: ObservableObject {
    static let shared = CoverArtManager()
    
    // MARK: - Centralized Image State
    @Published private(set) var albumImages: [String: UIImage] = [:]
    @Published private(set) var artistImages: [String: UIImage] = [:]
    @Published private(set) var loadingStates: [String: Bool] = [:]
    
    // Dependencies
    private let persistentCache = PersistentImageCache.shared
    private weak var navidromeService: SubsonicService?
    
    // Request management
    private var activeRequests: Set<String> = []
    private let maxConcurrentRequests = 3
    private let staggerDelay: UInt64 = 50_000_000 // 50ms
    private let maxStaggerDelay: UInt64 = 500_000_000 // 500ms
    
    private init() {}
    
    // MARK: - Configuration
    
    func configure(service: SubsonicService) {
        self.navidromeService = service
    }
    
    // MARK: - ✅ PRIMARY API: Smart Image Loading with State Management
    
    /// Load album image with centralized state management
    func loadAlbumImage(album: Album, size: Int = 200, staggerIndex: Int = 0) async -> UIImage? {
        let cacheKey = "album_\(album.id)_\(size)"
        let stateKey = album.id
        
        // 1. Return cached state if available
        if let cached = albumImages[stateKey] {
            return cached
        }
        
        // 2. Check persistent cache
        if let cached = persistentCache.image(for: cacheKey) {
            let optimized = optimizeImageSize(cached, requestedSize: size) ?? cached
            albumImages[stateKey] = optimized
            return optimized
        }
        
        // 3. Load with staggering and state management
        return await loadImageWithStateManagement(
            key: stateKey,
            cacheKey: cacheKey,
            staggerIndex: staggerIndex,
            imageType: .album(album),
            size: size
        )
    }
    
    /// Load artist image with centralized state management
    func loadArtistImage(artist: Artist, size: Int = 120, staggerIndex: Int = 0) async -> UIImage? {
        guard let coverArt = artist.coverArt, !coverArt.isEmpty else { return nil }
        
        let cacheKey = "artist_\(coverArt)_\(size)"
        let stateKey = artist.id
        
        // 1. Return cached state if available
        if let cached = artistImages[stateKey] {
            return cached
        }
        
        // 2. Check persistent cache
        if let cached = persistentCache.image(for: cacheKey) {
            let optimized = optimizeImageSize(cached, requestedSize: size) ?? cached
            artistImages[stateKey] = optimized
            return optimized
        }
        
        // 3. Load with staggering and state management
        return await loadImageWithStateManagement(
            key: stateKey,
            cacheKey: cacheKey,
            staggerIndex: staggerIndex,
            imageType: .artist(artist),
            size: size
        )
    }
    
    /// Load song image (from album) with centralized state management
    func loadSongImage(song: Song, size: Int = 100) async -> UIImage? {
        guard let albumId = song.albumId else { return nil }
        
        // Try to get album metadata for proper loading
        if let albumMetadata = AlbumMetadataCache.shared.getAlbum(id: albumId) {
            return await loadAlbumImage(album: albumMetadata, size: size)
        }
        
        // Fallback: create minimal album object
        let fallbackAlbum = Album(
            id: albumId,
            name: song.album ?? "Unknown Album",
            artist: song.artist ?? "Unknown Artist",
            year: song.year,
            genre: song.genre,
            coverArt: song.coverArt,
            coverArtId: song.coverArt,
            duration: nil,
            songCount: nil,
            artistId: song.artistId,
            displayArtist: nil
        )
        
        return await loadAlbumImage(album: fallbackAlbum, size: size)
    }
    
    // MARK: - ✅ REACTIVE GETTERS: For UI Components
    
    /// Get album image from centralized state
    func getAlbumImage(for albumId: String, size: Int = 200) -> UIImage? {
        return albumImages[albumId]
    }
    
    /// Get artist image from centralized state
    func getArtistImage(for artistId: String, size: Int = 120) -> UIImage? {
        return artistImages[artistId]
    }
    
    /// Check if image is currently loading
    func isLoadingImage(for key: String) -> Bool {
        return loadingStates[key] == true
    }
    
    /// Get song image (via album)
    func getSongImage(for song: Song, size: Int = 100) -> UIImage? {
        guard let albumId = song.albumId else { return nil }
        return getAlbumImage(for: albumId, size: size)
    }
    
    // MARK: - ✅ CACHE-ONLY Methods (fast, non-blocking)
    
    /// Check if album image is in persistent cache
    func hasCachedAlbumImage(_ album: Album, size: Int) -> Bool {
        let cacheKey = "album_\(album.id)_\(size)"
        return persistentCache.image(for: cacheKey) != nil
    }
    
    /// Check if artist image is in persistent cache
    func hasCachedArtistImage(_ artist: Artist, size: Int) -> Bool {
        guard let coverArt = artist.coverArt, !coverArt.isEmpty else { return false }
        let cacheKey = "artist_\(coverArt)_\(size)"
        return persistentCache.image(for: cacheKey) != nil
    }
    
    // MARK: - ✅ UNIFIED IMAGE LOADING with State Management
    
    private func loadImageWithStateManagement(
        key: String,
        cacheKey: String,
        staggerIndex: Int,
        imageType: ImageType,
        size: Int
    ) async -> UIImage? {
        
        // Set loading state
        loadingStates[key] = true
        defer { loadingStates[key] = false }
        
        // Concurrency control
        while activeRequests.count >= maxConcurrentRequests {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        // Request deduplication
        guard !activeRequests.contains(cacheKey) else {
            while activeRequests.contains(cacheKey) {
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            }
            // Check cache again after waiting
            if let cached = persistentCache.image(for: cacheKey) {
                let optimized = optimizeImageSize(cached, requestedSize: size) ?? cached
                updateImageState(key: key, image: optimized, imageType: imageType)
                return optimized
            }
            return nil
        }
        
        activeRequests.insert(cacheKey)
        defer { activeRequests.remove(cacheKey) }
        
        // Staggered loading to prevent thundering herd
        if staggerIndex > 0 {
            let delay = min(UInt64(staggerIndex) * staggerDelay, maxStaggerDelay)
            try? await Task.sleep(nanoseconds: delay)
        }
        
        guard let service = navidromeService else { return nil }
        
        // Load from network
        let coverId: String
        let networkSize = size > 300 ? size : 500 // Load higher res for caching
        
        switch imageType {
        case .album(let album):
            coverId = album.id
        case .artist(let artist):
            coverId = artist.coverArt ?? artist.id
        }
        
        let image = await service.getCoverArt(for: coverId, size: networkSize)
        
        if let image = image {
            persistentCache.store(image, for: cacheKey)
            let optimized = optimizeImageSize(image, requestedSize: size) ?? image
            updateImageState(key: key, image: optimized, imageType: imageType)
            return optimized
        }
        
        return nil
    }
    
    private func updateImageState(key: String, image: UIImage, imageType: ImageType) {
        switch imageType {
        case .album:
            albumImages[key] = image
        case .artist:
            artistImages[key] = image
        }
    }
    
    private enum ImageType {
        case album(Album)
        case artist(Artist)
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
            for (index, album) in albumsToLoad.enumerated() {
                group.addTask {
                    _ = await self.loadAlbumImage(album: album, size: size, staggerIndex: index)
                }
            }
        }
    }
    
    func preloadArtists(_ artists: [Artist], size: Int = 120) async {
        let artistsToLoad = artists.prefix(10).filter { $0.coverArt != nil }
        
        await withTaskGroup(of: Void.self) { group in
            for (index, artist) in artistsToLoad.enumerated() {
                group.addTask {
                    _ = await self.loadArtistImage(artist: artist, size: size, staggerIndex: index)
                }
            }
        }
    }
    
    // MARK: - Memory Management
    
    func clearMemoryCache() {
        albumImages.removeAll()
        artistImages.removeAll()
        loadingStates.removeAll()
        activeRequests.removeAll()
        persistentCache.clearCache()
    }
    
    func clearAlbumImages() {
        albumImages.removeAll()
    }
    
    func clearArtistImages() {
        artistImages.removeAll()
    }
    
    // MARK: - Statistics
    
    func getCacheStats() -> CacheStats {
        let persistentStats = persistentCache.getCacheStats()
        
        return CacheStats(
            memoryAlbums: albumImages.count,
            memoryArtists: artistImages.count,
            persistentImages: persistentStats.diskCount,
            activeRequests: activeRequests.count,
            loadingImages: loadingStates.values.filter { $0 }.count
        )
    }
    
    struct CacheStats {
        let memoryAlbums: Int
        let memoryArtists: Int
        let persistentImages: Int
        let activeRequests: Int
        let loadingImages: Int
        
        var totalMemoryImages: Int {
            return memoryAlbums + memoryArtists
        }
        
        var summary: String {
            return "Memory: \(totalMemoryImages) images, Persistent: \(persistentImages), Loading: \(loadingImages)"
        }
    }
}

// MARK: - ✅ CONVENIENCE EXTENSIONS for Album Creation

extension Album {
    init(id: String, name: String, artist: String, year: Int?, genre: String?,
         coverArt: String?, coverArtId: String?, duration: Int?, songCount: Int?,
         artistId: String?, displayArtist: String?) {
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
