//
//  MediaService.swift
//  NavidromeClient
//
//  Created by Boris Eder on 16.09.25.
//


//
//  MediaService.swift - Media URLs & Cover Art
//  NavidromeClient
//
//   FOCUSED: Cover art, streaming URLs, downloads
//

import Foundation
import UIKit

@MainActor
class MediaService {
    private let connectionService: ConnectionService
    private let session: URLSession
    
    // Request deduplication for cover art
    private var activeRequests: Set<String> = []
    
    init(connectionService: ConnectionService) {
        self.connectionService = connectionService
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 120 // Longer for media downloads
        self.session = URLSession(configuration: config)
    }
    
    // MARK: -  COVER ART API
    
    func getCoverArt(for coverId: String, size: Int = 300) async -> UIImage? {
        let cacheKey = "\(coverId)_\(size)"
        
        // Request deduplication
        guard !activeRequests.contains(cacheKey) else {
            // Wait for ongoing request
            while activeRequests.contains(cacheKey) {
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            }
            // Check cache again after waiting
            return PersistentImageCache.shared.image(for: cacheKey)
        }
        
        activeRequests.insert(cacheKey)
        defer { activeRequests.remove(cacheKey) }
        
        // Check cache first
        if let cached = PersistentImageCache.shared.image(for: cacheKey) {
            return cached
        }
        
        // Load from server
        guard let url = connectionService.buildURL(
            endpoint: "getCoverArt",
            params: ["id": coverId, "size": "\(size)"]
        ) else {
            return nil
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let image = UIImage(data: data) else {
                return nil
            }
            
            // Cache the image
            PersistentImageCache.shared.store(image, for: cacheKey)
            return image
            
        } catch {
            print("❌ Cover art load error: \(error)")
            return nil
        }
    }
    
    func preloadCoverArt(for albums: [Album], size: Int = 200) async {
        let albumsToPreload = albums.prefix(5) // Limit concurrent requests
        
        await withTaskGroup(of: Void.self) { group in
            for album in albumsToPreload {
                group.addTask {
                    _ = await self.getCoverArt(for: album.id, size: size)
                }
            }
        }
        
        print(" Preloaded cover art for \(albumsToPreload.count) albums")
    }
    
    // MARK: -  STREAMING URLS
    
    func streamURL(for songId: String) -> URL? {
        guard !songId.isEmpty else { return nil }
        return connectionService.buildURL(endpoint: "stream", params: ["id": songId])
    }
    
    func downloadURL(for songId: String, maxBitRate: Int? = nil) -> URL? {
        guard !songId.isEmpty else { return nil }
        
        var params = ["id": songId]
        if let bitRate = maxBitRate {
            params["maxBitRate"] = "\(bitRate)"
        }
        
        return connectionService.buildURL(endpoint: "download", params: params)
    }
    
    // MARK: -  MEDIA METADATA
    
    func getMediaInfo(for songId: String) async throws -> MediaInfo? {
        guard !songId.isEmpty else { return nil }
        
        // This would call a hypothetical getMediaInfo endpoint
        // For now, we'll extract from song data
        return nil
    }
    
    // MARK: -  BATCH COVER ART OPERATIONS
    
    func getCoverArtBatch(
        items: [(id: String, size: Int)],
        maxConcurrent: Int = 3
    ) async -> [String: UIImage] {
        var results: [String: UIImage] = [:]
        
        await withTaskGroup(of: (String, UIImage?).self) { group in
            var activeCount = 0
            var pendingItems = items
            
            while !pendingItems.isEmpty || activeCount > 0 {
                // Start new tasks up to limit
                while activeCount < maxConcurrent && !pendingItems.isEmpty {
                    let item = pendingItems.removeFirst()
                    activeCount += 1
                    
                    group.addTask {
                        let image = await self.getCoverArt(for: item.id, size: item.size)
                        return (item.id, image)
                    }
                }
                
                // Wait for at least one task to complete
                if let (id, image) = await group.next() {
                    activeCount -= 1
                    if let image = image {
                        results[id] = image
                    }
                }
            }
        }
        
        return results
    }
    
    // MARK: -  AUDIO QUALITY OPTIMIZATION
    
    func getOptimalStreamURL(
        for songId: String,
        preferredBitRate: Int? = nil,
        connectionQuality: ConnectionService.ConnectionQuality
    ) -> URL? {
        
        let optimalBitRate: Int?
        
        switch connectionQuality {
        case .excellent:
            optimalBitRate = preferredBitRate ?? 320 // High quality
        case .good:
            optimalBitRate = 192 // Balanced
        case .poor:
            optimalBitRate = 128 // Lower for poor connections
        case .timeout, .unknown:
            optimalBitRate = 96 // Very conservative
        }
        
        var params = ["id": songId]
        if let bitRate = optimalBitRate {
            params["maxBitRate"] = "\(bitRate)"
        }
        
        return connectionService.buildURL(endpoint: "stream", params: params)
    }
    
    // MARK: -  CACHE MANAGEMENT
    
    func clearCoverArtCache() {
        PersistentImageCache.shared.clearCache()
        activeRequests.removeAll()
        print("🧹 Cleared media cache")
    }
    
    func getCacheStats() -> MediaCacheStats {
        let cacheStats = PersistentImageCache.shared.getCacheStats()
        
        return MediaCacheStats(
            imageCount: cacheStats.diskCount,
            cacheSize: cacheStats.diskSize,
            activeRequests: activeRequests.count
        )
    }
}

// MARK: -  SUPPORTING TYPES

struct MediaInfo {
    let bitRate: Int?
    let format: String?
    let duration: TimeInterval?
    let fileSize: Int64?
}

struct MediaCacheStats {
    let imageCount: Int
    let cacheSize: Int64
    let activeRequests: Int
    
    var cacheSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: cacheSize, countStyle: .file)
    }
    
    var summary: String {
        return "Images: \(imageCount), Size: \(cacheSizeFormatted), Active: \(activeRequests)"
    }
}
