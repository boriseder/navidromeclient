//
//  PersistentImageCache.swift
//  NavidromeClient
//
//  Size-aware persistent image cache
//  FIXED: Multiple sizes per image, better cache key strategy
//

import Foundation
import UIKit
import CryptoKit

@MainActor
class PersistentImageCache: ObservableObject {
    static let shared = PersistentImageCache()
    
    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let metadataFile: URL
    
    struct CacheMetadata: Codable {
        let key: String
        let filename: String
        let createdAt: Date
        let size: Int64
        var lastAccessed: Date
    }
    
    private var metadata: [String: CacheMetadata] = [:]
    private let maxCacheSize: Int64 = 200 * 1024 * 1024 // 200MB (increased for multi-size)
    private let maxAge: TimeInterval = 30 * 24 * 60 * 60 // 30 days
    
    private init() {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("CoverArtCache", isDirectory: true)
        metadataFile = cacheDirectory.appendingPathComponent("metadata.json")
        
        createCacheDirectoryIfNeeded()
        loadMetadata()
        configureMemoryCache()
        
        Task {
            await performMaintenanceCleanup()
        }
    }
    
    // MARK: - Public API
    
    func image(for key: String, size: Int) -> UIImage? {
        let cacheKey = buildCacheKey(key: key, size: size)
        
        // 1. Memory Cache
        if let cached = memoryCache.object(forKey: cacheKey as NSString) {
            updateLastAccessed(for: cacheKey)
            return cached
        }
        
        // 2. Disk Cache
        if let diskImage = loadImageFromDisk(key: cacheKey) {
            memoryCache.setObject(diskImage, forKey: cacheKey as NSString)
            updateLastAccessed(for: cacheKey)
            return diskImage
        }
        
        return nil
    }
    
    func store(_ image: UIImage, for key: String, size: Int, quality: CGFloat = 0.85) {
        let cacheKey = buildCacheKey(key: key, size: size)
        memoryCache.setObject(image, forKey: cacheKey as NSString)
        
        Task {
            await saveImageToDisk(image, key: cacheKey, quality: quality)
        }
    }
    
    func removeImage(for key: String, size: Int? = nil) {
        if let size = size {
            let cacheKey = buildCacheKey(key: key, size: size)
            memoryCache.removeObject(forKey: cacheKey as NSString)
            Task {
                await removeImageFromDisk(key: cacheKey)
            }
        } else {
            // Remove all sizes for this key
            let allSizes = [80, 100, 150, 200, 240, 300, 400, 800]
            for size in allSizes {
                let cacheKey = buildCacheKey(key: key, size: size)
                memoryCache.removeObject(forKey: cacheKey as NSString)
                Task {
                    await removeImageFromDisk(key: cacheKey)
                }
            }
        }
    }
    
    func clearCache() {
        memoryCache.removeAllObjects()
        Task {
            await clearDiskCache()
        }
    }
    
    func getCacheStats() -> CacheStats {
        let diskCount = metadata.count
        let diskSize = metadata.values.reduce(0) { $0 + $1.size }
        
        return CacheStats(
            memoryCount: memoryCache.countLimit,
            diskCount: diskCount,
            diskSize: diskSize,
            maxSize: maxCacheSize
        )
    }
    
    func performMaintenanceCleanup() async {
        await removeExpiredImages()
        await checkCacheSizeAndCleanup()
        await removeOrphanedFiles()
    }
    
    // MARK: - Cache Key Building
    
    private func buildCacheKey(key: String, size: Int) -> String {
        // FIXED: Key now comes in format "album_id_size" from CoverArtManager
        // Just use it as-is
        return key
    }
    
    // MARK: - Cache Stats
    
    struct CacheStats {
        let memoryCount: Int
        let diskCount: Int
        let diskSize: Int64
        let maxSize: Int64
        
        var diskSizeFormatted: String {
            ByteCountFormatter.string(fromByteCount: diskSize, countStyle: .file)
        }
        
        var maxSizeFormatted: String {
            ByteCountFormatter.string(fromByteCount: maxSize, countStyle: .file)
        }
        
        var usagePercentage: Double {
            guard maxSize > 0 else { return 0 }
            return Double(diskSize) / Double(maxSize) * 100
        }
    }
    
    // MARK: - Private Implementation
    
    private func createCacheDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    private func configureMemoryCache() {
        memoryCache.countLimit = 100 // Increased for multi-size
        memoryCache.totalCostLimit = 80 * 1024 * 1024 // 80MB
    }
    
    private func generateFilename(for key: String) -> String {
        let hash = key.sha256()
        return "\(hash).jpg"
    }
    
    private func loadImageFromDisk(key: String) -> UIImage? {
        guard let meta = metadata[key] else { return nil }
        
        let fileURL = cacheDirectory.appendingPathComponent(meta.filename)
        
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            metadata.removeValue(forKey: key)
            saveMetadata()
            return nil
        }
        
        return image
    }
    
    private func saveImageToDisk(_ image: UIImage, key: String, quality: CGFloat) async {
        let filename = generateFilename(for: key)
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        
        guard let data = image.jpegData(compressionQuality: quality) else { return }
        
        do {
            try data.write(to: fileURL)
            
            let meta = CacheMetadata(
                key: key,
                filename: filename,
                createdAt: Date(),
                size: Int64(data.count),
                lastAccessed: Date()
            )
            
            await MainActor.run {
                metadata[key] = meta
                saveMetadata()
            }
            
            await checkCacheSizeAndCleanup()
            
        } catch {
            print("Cache save error: \(error)")
        }
    }
    
    private func removeImageFromDisk(key: String) async {
        guard let meta = metadata[key] else { return }
        
        let fileURL = cacheDirectory.appendingPathComponent(meta.filename)
        try? fileManager.removeItem(at: fileURL)
        
        await MainActor.run {
            metadata.removeValue(forKey: key)
            saveMetadata()
        }
    }
    
    private func clearDiskCache() async {
        if let contents = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) {
            for fileURL in contents {
                try? fileManager.removeItem(at: fileURL)
            }
        }
        
        await MainActor.run {
            metadata.removeAll()
            saveMetadata()
        }
    }
    
    private func loadMetadata() {
        guard fileManager.fileExists(atPath: metadataFile.path),
              let data = try? Data(contentsOf: metadataFile),
              let loadedMetadata = try? JSONDecoder().decode([String: CacheMetadata].self, from: data) else {
            return
        }
        
        metadata = loadedMetadata
    }
    
    private func saveMetadata() {
        guard let data = try? JSONEncoder().encode(metadata) else { return }
        try? data.write(to: metadataFile)
    }
    
    private func updateLastAccessed(for key: String) {
        guard var meta = metadata[key] else { return }
        meta.lastAccessed = Date()
        metadata[key] = meta
        
        if Int.random(in: 1...10) == 1 {
            saveMetadata()
        }
    }
    
    private func removeExpiredImages() async {
        let now = Date()
        var expiredKeys: [String] = []
        
        for (key, meta) in metadata {
            if now.timeIntervalSince(meta.createdAt) > maxAge {
                expiredKeys.append(key)
            }
        }
        
        for key in expiredKeys {
            await removeImageFromDisk(key: key)
        }
        
        if !expiredKeys.isEmpty {
            print("Removed \(expiredKeys.count) expired cache entries")
        }
    }
    
    private func checkCacheSizeAndCleanup() async {
        let currentSize = metadata.values.reduce(0) { $0 + $1.size }
        
        guard currentSize > maxCacheSize else { return }
        
        let sortedByAccess = metadata.sorted { $0.value.lastAccessed < $1.value.lastAccessed }
        let targetSize = maxCacheSize * 80 / 100
        
        var removedSize: Int64 = 0
        var removedCount = 0
        
        for (key, meta) in sortedByAccess {
            await removeImageFromDisk(key: key)
            removedSize += meta.size
            removedCount += 1
            
            if currentSize - removedSize <= targetSize {
                break
            }
        }
        
        print("Cache cleanup: Removed \(removedCount) items")
    }
    
    private func removeOrphanedFiles() async {
        guard let contents = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        
        let metadataFilenames = Set(metadata.values.map { $0.filename })
        var orphanedCount = 0
        
        for fileURL in contents {
            let filename = fileURL.lastPathComponent
            
            if filename == "metadata.json" { continue }
            
            if !metadataFilenames.contains(filename) {
                try? fileManager.removeItem(at: fileURL)
                orphanedCount += 1
            }
        }
        
        if orphanedCount > 0 {
            print("Removed \(orphanedCount) orphaned files")
        }
    }
}

extension String {
    func sha256() -> String {
        let inputData = Data(utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
