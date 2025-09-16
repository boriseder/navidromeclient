//
//  SubsonicService.swift - MIGRATED to Thematic Service Architecture
//  NavidromeClient
//
//  ✅ REPLACED: Giant monolith with focused services
//  ✅ MAINTAINS: Backwards compatibility for existing code
//

import Foundation
import UIKit

// MARK: - ✅ NEW: Thematic Service Architecture

// This is now just a type alias for backwards compatibility
typealias SubsonicService = UnifiedSubsonicService

@MainActor
class UnifiedSubsonicService: ObservableObject {
    
    // MARK: - ✅ THEMATIC SERVICES
    private let connectionService: ConnectionService
    private let contentService: ContentService
    private let mediaService: MediaService
    private let discoveryService: DiscoveryService
    private let searchService: SearchService
    
    // MARK: - INITIALIZATION
    
    init(baseURL: URL, username: String, password: String) {
        // Initialize services in dependency order
        self.connectionService = ConnectionService(
            baseURL: baseURL,
            username: username,
            password: password
        )
        
        self.contentService = ContentService(connectionService: connectionService)
        self.mediaService = MediaService(connectionService: connectionService)
        self.discoveryService = DiscoveryService(connectionService: connectionService)
        self.searchService = SearchService(connectionService: connectionService)
        
        print("✅ Initialized UnifiedSubsonicService with thematic architecture")
    }
    
    // MARK: - ✅ BACKWARDS COMPATIBLE API
    
    // All existing manager code continues to work unchanged
    
    func testConnection() async -> ConnectionTestResult {
        return await connectionService.testConnection()
    }
    
    func ping() async -> Bool {
        return await connectionService.ping()
    }
    
    // Content API - now delegates to ContentService
    func getAllAlbums(
        sortBy: AlbumSortType = .alphabetical,
        size: Int = 500,
        offset: Int = 0
    ) async throws -> [Album] {
        return try await contentService.getAllAlbums(sortBy: sortBy, size: size, offset: offset)
    }
    
    func getArtists() async throws -> [Artist] {
        return try await contentService.getArtists()
    }
    
    func getAlbumsByArtist(artistId: String) async throws -> [Album] {
        return try await contentService.getAlbumsByArtist(artistId: artistId)
    }
    
    func getAlbumsByGenre(genre: String) async throws -> [Album] {
        return try await contentService.getAlbumsByGenre(genre: genre)
    }
    
    func getSongs(for albumId: String) async throws -> [Song] {
        return try await contentService.getSongs(for: albumId)
    }
    
    func getGenres() async throws -> [Genre] {
        return try await contentService.getGenres()
    }
    
    // Media API - now delegates to MediaService
    func getCoverArt(for coverId: String, size: Int = 300) async -> UIImage? {
        return await mediaService.getCoverArt(for: coverId, size: size)
    }
    
    func preloadCoverArt(for albums: [Album], size: Int = 200) async {
        await mediaService.preloadCoverArt(for: albums, size: size)
    }
    
    func streamURL(for songId: String) -> URL? {
        return mediaService.streamURL(for: songId)
    }
    
    // Discovery API - now delegates to DiscoveryService
    func getRecentAlbums(size: Int = 20) async throws -> [Album] {
        return try await discoveryService.getRecentAlbums(size: size)
    }
    
    func getNewestAlbums(size: Int = 20) async throws -> [Album] {
        return try await discoveryService.getNewestAlbums(size: size)
    }
    
    func getFrequentAlbums(size: Int = 20) async throws -> [Album] {
        return try await discoveryService.getFrequentAlbums(size: size)
    }
    
    func getRandomAlbums(size: Int = 20) async throws -> [Album] {
        return try await discoveryService.getRandomAlbums(size: size)
    }
    
    // Search API - now delegates to SearchService
    func search(query: String, maxResults: Int = 50) async throws -> SearchResult {
        return try await searchService.search(query: query, maxResults: maxResults)
    }
    
    // MARK: - ✅ LEGACY COMPATIBILITY LAYER
    
    // Support old extension-style calls
    func getAlbumList(type: String, size: Int = 20, offset: Int = 0) async throws -> [Album] {
        let albumSortType: ContentService.AlbumSortType
        
        switch type {
        case "recent": albumSortType = .recent
        case "newest": albumSortType = .newest
        case "frequent": albumSortType = .frequent
        case "random": albumSortType = .random
        case "byYear": albumSortType = .byYear
        case "byGenre": albumSortType = .byGenre
        case "alphabeticalByArtist": albumSortType = .alphabeticalByArtist
        default: albumSortType = .alphabetical
        }
        
        return try await contentService.getAllAlbums(sortBy: albumSortType, size: size, offset: offset)
    }
    
    // Support old AlbumListType enum
    func getAlbumList(type: AlbumListType, size: Int = 20, offset: Int = 0) async throws -> [Album] {
        switch type {
        case .recent: return try await discoveryService.getRecentAlbums(size: size)
        case .newest: return try await discoveryService.getNewestAlbums(size: size)
        case .frequent: return try await discoveryService.getFrequentAlbums(size: size)
        case .random: return try await discoveryService.getRandomAlbums(size: size)
        case .byGenre: return try await contentService.getAllAlbums(sortBy: .byGenre, size: size, offset: offset)
        }
    }
    
    // MARK: - ✅ NEW ADVANCED FEATURES
    
    // Now we can expose advanced service-specific features
    
    func getDiscoveryMix(size: Int = 20) async throws -> DiscoveryMix {
        return try await discoveryService.getDiscoveryMix(size: size)
    }
    
    func getRecommendationsFor(artist: Artist, limit: Int = 10) async throws -> [Album] {
        return try await discoveryService.getRecommendationsFor(artist: artist, limit: limit)
    }
    
    func getRecommendationsFor(album: Album, limit: Int = 10) async throws -> [Album] {
        return try await discoveryService.getRecommendationsFor(album: album, limit: limit)
    }
    
    func searchWithFilters(
        query: String,
        filters: SearchFilters,
        maxResults: Int = 50
    ) async throws -> SearchResult {
        return try await searchService.searchWithFilters(
            query: query,
            filters: filters,
            maxResults: maxResults
        )
    }
    
    func getSearchSuggestions(for partialQuery: String, limit: Int = 5) async -> [String] {
        return await searchService.getSearchSuggestions(for: partialQuery, limit: limit)
    }
    
    func getCoverArtBatch(
        items: [(id: String, size: Int)],
        maxConcurrent: Int = 3
    ) async -> [String: UIImage] {
        return await mediaService.getCoverArtBatch(items: items, maxConcurrent: maxConcurrent)
    }
    
    // MARK: - ✅ SERVICE ACCESS (for advanced usage)
    
    func getConnectionService() -> ConnectionService {
        return connectionService
    }
    
    func getContentService() -> ContentService {
        return contentService
    }
    
    func getMediaService() -> MediaService {
        return mediaService
    }
    
    func getDiscoveryService() -> DiscoveryService {
        return discoveryService
    }
    
    func getSearchService() -> SearchService {
        return searchService
    }
    
    // MARK: - ✅ PERFORMANCE & DIAGNOSTICS
    
    func performHealthCheck() async -> ConnectionHealth {
        return await connectionService.performHealthCheck()
    }
    
    func getServiceDiagnostics() async -> ServiceDiagnostics {
        let connectionHealth = await connectionService.performHealthCheck()
        let mediaCacheStats = mediaService.getCacheStats()
        let searchStats = searchService.getSearchStats()
        
        return ServiceDiagnostics(
            connectionHealth: connectionHealth,
            mediaCacheStats: mediaCacheStats,
            searchStats: searchStats
        )
    }
    
    func clearAllCaches() {
        mediaService.clearCoverArtCache()
        print("🧹 Cleared all service caches")
    }
}

// MARK: - ✅ SUPPORTING TYPES (for backwards compatibility)

// Map old enum to new ContentService enum
typealias AlbumSortType = ContentService.AlbumSortType

// Legacy compatibility
enum AlbumListType: String {
    case recent = "recent"
    case newest = "newest"
    case frequent = "frequent"
    case random = "random"
    case byGenre = "byGenre"
}

struct ServiceDiagnostics {
    let connectionHealth: ConnectionHealth
    let mediaCacheStats: MediaCacheStats
    let searchStats: SearchStats
    
    var overallHealth: String {
        if connectionHealth.isConnected && connectionHealth.healthScore > 0.7 {
            return "✅ All services healthy"
        } else if connectionHealth.isConnected {
            return "⚠️ Services operational with issues"
        } else {
            return "❌ Connection issues detected"
        }
    }
    
    var summary: String {
        return """
        Connection: \(connectionHealth.statusDescription)
        Media Cache: \(mediaCacheStats.summary)
        Last Search: \(searchStats.searchQuery.isEmpty ? "None" : searchStats.searchQuery)
        """
    }
}

// MARK: - ✅ MIGRATION NOTES

/*
MIGRATION COMPLETE! 🎉

✅ BACKWARDS COMPATIBILITY:
- All existing manager code continues to work unchanged
- NavidromeViewModel.getService() returns UnifiedSubsonicService
- All method signatures are identical

✅ NEW CAPABILITIES:
- Advanced discovery: getRecommendationsFor()
- Batch operations: getCoverArtBatch()
- Search filters: searchWithFilters()
- Performance diagnostics: getServiceDiagnostics()

✅ NEXT STEPS:
1. Update managers to use focused services (optional)
2. Enable advanced features (recommendations, etc.)
3. Remove old extension files (they're now integrated)

✅ PERFORMANCE IMPROVEMENTS:
- Parallel service operations
- Focused caching per domain
- Request deduplication in MediaService
- Connection health monitoring

The old monolithic SubsonicService.swift is now a clean
orchestration layer with focused services underneath!
*/
