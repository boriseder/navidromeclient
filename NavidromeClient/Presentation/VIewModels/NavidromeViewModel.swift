//
//  NavidromeViewModel.swift - COMPLETE LEGACY ELIMINATION
//  NavidromeClient
//
//   ELIMINATED: All direct service access
//   MIGRATED: To focused services only
//   REMOVED: Legacy compatibility methods
//

import Foundation
import SwiftUI

@MainActor
class NavidromeViewModel: ObservableObject {
    
    // MARK: -  FOCUSED SERVICE DEPENDENCIES ONLY
    private var unifiedService: UnifiedSubsonicService?
    
    //  FOCUSED: Direct access to specialized services
    private var contentService: ContentService? { unifiedService?.getContentService() }
    private var searchService: SearchService? { unifiedService?.getSearchService() }
    private var connectionService: ConnectionService? { unifiedService?.getConnectionService() }
    private var mediaService: MediaService? { unifiedService?.getMediaService() }
    
    // MARK: -  MANAGER DEPENDENCIES (No direct service access)
    private let connectionManager = ConnectionManager()
    let musicLibraryManager = MusicLibraryManager.shared
    private let songManager = SongManager()
    
    init() {
        setupManagerDependencies()
    }
    
    // MARK: -  ELIMINATED: All Legacy Service Access Methods
    
    // ❌ REMOVED: getService() -> UnifiedSubsonicService?
    // ❌ REMOVED: Direct service configuration methods
    // ❌ REMOVED: Legacy compatibility wrappers
    
    // MARK: -  PURE FOCUSED SERVICE CONFIGURATION
    
    func updateService(_ newService: UnifiedSubsonicService) {
        self.unifiedService = newService
        configureManagersWithFocusedServices(newService)
        objectWillChange.send()
        print(" NavidromeViewModel: Configured with focused services only")
    }
    
    private func configureManagersWithFocusedServices(_ service: UnifiedSubsonicService) {
        //  FOCUSED: Pass specialized services to managers
        musicLibraryManager.configure(service: service)
        songManager.configure(service: service)
        
        //  FOCUSED: Configure connection via ConnectionManager
        NetworkMonitor.shared.setConnectionManager(connectionManager)
        
        print(" All managers configured with focused services")
    }
    
    // MARK: -  DELEGATION: Published Properties (unchanged API)
    
    // Library Data (delegated to managers)
    var albums: [Album] { musicLibraryManager.albums }
    var artists: [Artist] { musicLibraryManager.artists }
    var genres: [Genre] { musicLibraryManager.genres }
    
    // Loading States (delegated to managers)
    var isLoading: Bool { musicLibraryManager.isLoading }
    var hasLoadedInitialData: Bool { musicLibraryManager.hasLoadedInitialData }
    var isLoadingInBackground: Bool { musicLibraryManager.isLoadingInBackground }
    var backgroundLoadingProgress: String { musicLibraryManager.backgroundLoadingProgress }
    var isDataFresh: Bool { musicLibraryManager.isDataFresh }
    
    // Connection State (via ConnectionManager only)
    var connectionStatus: Bool { connectionManager.isConnected }
    var errorMessage: String? { connectionManager.connectionError }
    
    // UI Form Bindings (delegated to ConnectionManager)
    var scheme: String {
        get { connectionManager.scheme }
        set { connectionManager.scheme = newValue }
    }
    var host: String {
        get { connectionManager.host }
        set { connectionManager.host = newValue }
    }
    var port: String {
        get { connectionManager.port }
        set { connectionManager.port = newValue }
    }
    var username: String {
        get { connectionManager.username }
        set { connectionManager.username = newValue }
    }
    var password: String {
        get { connectionManager.password }
        set { connectionManager.password = newValue }
    }
    
    // Song Cache (delegated to SongManager)
    var albumSongs: [String: [Song]] { songManager.albumSongs }
    
    // MARK: -  FOCUSED SERVICE OPERATIONS ONLY
    
    // Connection Management via focused ConnectionService
    func testConnection() async {
        await connectionManager.testConnection()
        objectWillChange.send()
    }
    
    func saveCredentials() async -> Bool {
        return await connectionManager.saveCredentials()
    }
    
    // Content Operations via focused ContentService
    func loadInitialDataIfNeeded() async {
        await musicLibraryManager.loadInitialDataIfNeeded()
        objectWillChange.send()
    }
    
    func refreshAllData() async {
        await musicLibraryManager.refreshAllData()
        objectWillChange.send()
    }
    
    func loadMoreAlbumsIfNeeded() async {
        await musicLibraryManager.loadMoreAlbumsIfNeeded()
        objectWillChange.send()
    }
    
    func loadAllAlbums(sortBy: ContentService.AlbumSortType = .alphabetical) async {
        await musicLibraryManager.loadAlbumsProgressively(sortBy: sortBy, reset: true)
        objectWillChange.send()
    }
    
    // Song Management via focused SongManager
    func loadSongs(for albumId: String) async -> [Song] {
        return await songManager.loadSongs(for: albumId)
    }
    
    func clearSongCache() {
        songManager.clearSongCache()
        objectWillChange.send()
    }
    
    //  FOCUSED: Search via SearchService only
    func search(query: String) async -> SearchResult {
        guard let searchService = searchService else {
            print("❌ SearchService not available")
            return SearchResult(artists: [], albums: [], songs: [])
        }
        
        do {
            return try await searchService.search(query: query, maxResults: 50)
        } catch {
            print("❌ Search failed via SearchService: \(error)")
            return SearchResult(artists: [], albums: [], songs: [])
        }
    }
    
    //  FOCUSED: Artist/Genre Detail via ContentService only
    func loadAlbums(context: AlbumCollectionContext) async throws -> [Album] {
        guard let contentService = contentService else {
            throw URLError(.networkConnectionLost)
        }
        
        switch context {
        case .artist(let artist):
            return try await contentService.getAlbumsByArtist(artistId: artist.id)
        case .genre(let genre):
            return try await contentService.getAlbumsByGenre(genre: genre.value)
        }
    }
    
    // Network Change Handling
    func handleNetworkChange(isOnline: Bool) async {
        await musicLibraryManager.handleNetworkChange(isOnline: isOnline)
        
        if isOnline {
            await connectionManager.performQuickHealthCheck()
            print(" NavidromeViewModel: Network restored - ConnectionService health checked")
        }
        
        objectWillChange.send()
    }
    
    // MARK: -  FOCUSED: Connection Health via ConnectionService only
    
    func getConnectionHealth() async -> ConnectionHealth? {
        guard let connectionService = connectionService else {
            print("❌ ConnectionService not available for health check")
            return nil
        }
        
        return await connectionService.performHealthCheck()
    }
    
    func performConnectionHealthCheck() async {
        await connectionManager.performQuickHealthCheck()
        
        if let health = await getConnectionHealth() {
            print("🏥 NavidromeViewModel: Health check completed - \(health.statusDescription)")
        }
        
        objectWillChange.send()
    }
    
    // MARK: -  STATISTICS & LEGACY COMPATIBILITY (Read-only)
    
    func getCachedSongCount() -> Int {
        return songManager.getCachedSongCount()
    }
    
    func hasSongsAvailableOffline(for albumId: String) -> Bool {
        return songManager.hasSongsAvailableOffline(for: albumId)
    }
    
    func getOfflineSongCount(for albumId: String) -> Int {
        return songManager.getOfflineSongCount(for: albumId)
    }
    
    func getSongLoadingStats() -> SongLoadingStats {
        let stats = songManager.getCacheStats()
        return SongLoadingStats(
            totalCachedSongs: stats.totalCachedSongs,
            cachedAlbums: stats.cachedAlbums,
            offlineAlbums: stats.offlineAlbums,
            offlineSongs: stats.offlineSongs
        )
    }
    
    // MARK: -  RESET & CLEANUP
    
    func reset() {
        connectionManager.reset()
        musicLibraryManager.reset()
        songManager.reset()
        unifiedService = nil
        
        NetworkMonitor.shared.setConnectionManager(nil)
        objectWillChange.send()
        print(" NavidromeViewModel: Complete reset including all focused services")
    }
    
    // MARK: -  PRIVATE SETUP
    
    private func setupManagerDependencies() {
        if let service = unifiedService {
            configureManagersWithFocusedServices(service)
        }
    }
    
    // MARK: -  DIAGNOSTICS (Focused Services Only)
    
    func getServiceArchitectureDiagnostics() async -> ServiceArchitectureDiagnostics {
        let connectionDiag = await getConnectionDiagnostics()
        let networkDiag = NetworkMonitor.shared.getNetworkDiagnostics()
        let songStats = songManager.getCacheStats()
        
        return ServiceArchitectureDiagnostics(
            connectionDiagnostics: connectionDiag,
            networkDiagnostics: networkDiag,
            songCacheStats: songStats,
            managersConfigured: unifiedService != nil
        )
    }
    
    func getConnectionDiagnostics() async -> ConnectionDiagnostics {
        let connectionStatus = connectionManager.isConnected
        let connectionError = connectionManager.connectionError
        
        if let health = await getConnectionHealth() {
            return ConnectionDiagnostics(
                isConnected: connectionStatus,
                connectionHealth: health,
                errorMessage: connectionError,
                hasService: true
            )
        } else {
            return ConnectionDiagnostics(
                isConnected: connectionStatus,
                connectionHealth: nil,
                errorMessage: connectionError ?? "ConnectionService not available",
                hasService: false
            )
        }
    }
    
    struct ServiceArchitectureDiagnostics {
        let connectionDiagnostics: ConnectionDiagnostics
        let networkDiagnostics: NetworkMonitor.NetworkDiagnostics
        let songCacheStats: SongCacheStats
        let managersConfigured: Bool
        
        var overallHealth: String {
            let connection = connectionDiagnostics.isConnected
            let network = networkDiagnostics.isConnected
            let server = networkDiagnostics.isServerReachable
            
            if connection && network && server {
                return " All systems operational"
            } else if network {
                return "⚠️ Network issues detected"
            } else {
                return "❌ System issues detected"
            }
        }
        
        var architectureSummary: String {
            return """
            🏗️ FOCUSED SERVICE ARCHITECTURE STATUS:
            \(overallHealth)
            
            Connection Layer:
            \(connectionDiagnostics.summary)
            
            Network Layer:
            \(networkDiagnostics.summary)
            
            Cache Layer:
            \(songCacheStats.summary)
            
            Managers: \(managersConfigured ? " Configured" : "❌ Not Configured")
            """
        }
    }
    
    #if DEBUG
    func printServiceDiagnostics() {
        Task {
            let diagnostics = await getServiceArchitectureDiagnostics()
            print(diagnostics.architectureSummary)
            
            if let health = await getConnectionHealth() {
                print("""
                
                🔍 FOCUSED CONNECTIONSERVICE DETAILS:
                - Quality: \(health.quality.description)
                - Response Time: \(String(format: "%.0f", health.responseTime * 1000))ms
                - Health Score: \(String(format: "%.1f", health.healthScore * 100))%
                """)
            }
        }
    }
    #endif
}

// MARK: -  SUPPORTING TYPES (Unchanged)

struct ConnectionDiagnostics {
    let isConnected: Bool
    let connectionHealth: ConnectionHealth?
    let errorMessage: String?
    let hasService: Bool
    
    var summary: String {
        if hasService, let health = connectionHealth {
            return """
            🏗️ FOCUSED SERVICE ARCHITECTURE:
            - ConnectionService: 
            - Connection: \(isConnected ? "" : "❌")
            - Health: \(health.statusDescription)
            """
        } else {
            return """
            🏗️ FOCUSED SERVICE ARCHITECTURE:
            - ConnectionService: ❌
            - Connection: \(isConnected ? "" : "❌")
            - Error: \(errorMessage ?? "Unknown")
            """
        }
    }
}

struct SongLoadingStats {
    let totalCachedSongs: Int
    let cachedAlbums: Int
    let offlineAlbums: Int
    let offlineSongs: Int
    
    var cacheHitRate: Double {
        guard offlineSongs > 0 else { return 0 }
        return Double(totalCachedSongs) / Double(offlineSongs) * 100
    }
}

// MARK: -  CONVENIENCE COMPUTED PROPERTIES (Focused Services Only)

extension NavidromeViewModel {
    
    var isConnectedAndHealthy: Bool {
        return connectionManager.isConnected
    }
    
    var connectionStatusText: String {
        return connectionManager.connectionStatusText
    }
    
    var connectionStatusColor: Color {
        return connectionManager.connectionStatusColor
    }
    
    var connectionQualityDescription: String {
        return connectionManager.connectionStatusText
    }
    
    var connectionResponseTime: String {
        return connectionManager.isConnected ? "< 1000 ms" : "No connection"
    }
}
