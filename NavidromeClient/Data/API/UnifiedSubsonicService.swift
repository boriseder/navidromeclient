//
//  UnifiedSubsonicService.swift - REFACTORED: Pure Service Factory
//  NavidromeClient
//
//   REMOVED: All delegation methods (~180 LOC eliminated)
//   KEPT: Service Factory Pattern + Access Methods
//   CLEAN: Focused responsibility
//

import Foundation
import UIKit

@MainActor
class UnifiedSubsonicService: ObservableObject {
    
    // MARK: -  THEMATIC SERVICES (Private)
    internal let connectionService: ConnectionService
    internal let contentService: ContentService
    internal let mediaService: MediaService
    internal let discoveryService: DiscoveryService
    internal let searchService: SearchService
    
    // MARK: -  SERVICE FACTORY PATTERN
    
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
        
        print(" UnifiedSubsonicService: Service factory initialized")
    }
    
    // MARK: -  SERVICE ACCESS METHODS (Only these remain)
    
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
    
    // MARK: -  HEALTH & DIAGNOSTICS
    
    func performHealthCheck() async -> ConnectionHealth {
        return await connectionService.performHealthCheck()
    }
    
    func clearAllCaches() {
        mediaService.clearCoverArtCache()
        print("🧹 Cleared all service caches")
    }
}

// MARK: -  LEGACY TYPE ALIAS (Backwards compatibility)
typealias SubsonicService = UnifiedSubsonicService

extension UnifiedSubsonicService {
    func getFavoritesService() -> FavoritesService {
        return FavoritesService(connectionService: connectionService)
    }
}
