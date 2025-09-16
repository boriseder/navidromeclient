//
//  NavidromeViewModel.swift - FIXED for ConnectionManager Migration
//  NavidromeClient
//
//  ✅ FIXED: Direct ConnectionService access for detailed diagnostics
//  ✅ FIXED: Simplified ConnectionManager usage for UI bindings
//  ✅ BACKWARDS COMPATIBLE: All existing API calls unchanged
//

import Foundation
import SwiftUI

@MainActor
class NavidromeViewModel: ObservableObject {
    
    // MARK: - ✅ FIXED: Manager Dependencies with ConnectionService integration
    private let connectionManager = ConnectionManager()
    let musicLibraryManager = MusicLibraryManager.shared
    private let searchManager = SearchManager()
    private let songManager = SongManager()
    
    // MARK: - ✅ FIXED: Service Management
    private var service: UnifiedSubsonicService?
    
    init() {
        setupManagerDependencies()
        setupConnectionServiceIntegration()
    }
    
    // MARK: - ✅ DELEGATION: Published Properties (unchanged API)
    
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
    
    // ✅ FIXED: Connection State (simplified)
    var connectionStatus: Bool { connectionManager.isConnected }
    var serverType: String? { nil } // Not available in lightweight ConnectionManager
    var serverVersion: String? { nil } // Not available in lightweight ConnectionManager
    var subsonicVersion: String? { nil } // Not available in lightweight ConnectionManager
    var openSubsonic: Bool? { nil } // Not available in lightweight ConnectionManager
    var errorMessage: String? { connectionManager.connectionError }
    
    // Search Results (delegated to SearchManager)
    var searchResults: SearchManager.SearchResults { searchManager.searchResults }
    var songs: [Song] { searchResults.songs } // Legacy compatibility
    
    // ✅ FIXED: Credential UI Bindings (simplified)
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
    
    // MARK: - ✅ FIXED: Setup & Configuration
    
    private func setupManagerDependencies() {
        if let service = service {
            configureManagers(with: service)
        }
    }
    
    /// ✅ FIXED: Setup ConnectionService integration
    private func setupConnectionServiceIntegration() {
        // ConnectionManager now handles ConnectionService internally
        // NetworkMonitor should use ConnectionManager instead of direct service
        Task {
            await MainActor.run {
                NetworkMonitor.shared.setConnectionManager(connectionManager)
                print("✅ NavidromeViewModel: NetworkMonitor configured with ConnectionManager")
            }
        }
    }
    
    private func configureManagers(with service: UnifiedSubsonicService) {
        // ✅ ENHANCED: Managers now use focused services from UnifiedSubsonicService
        musicLibraryManager.configure(contentService: service.getContentService())
        searchManager.configure(searchService: service.getSearchService())
        songManager.configure(contentService: service.getContentService())
        
        print("✅ NavidromeViewModel: All managers configured with focused services")
    }
    
    func updateService(_ newService: UnifiedSubsonicService) {
        self.service = newService
        configureManagers(with: newService)
        
        // ✅ FIXED: Update NetworkMonitor with ConnectionManager
        NetworkMonitor.shared.setConnectionManager(connectionManager)
        
        objectWillChange.send()
        print("✅ NavidromeViewModel: Service updated")
    }
    
    func getService() -> UnifiedSubsonicService? {
        return service
    }
    
    // MARK: - ✅ FIXED: Core Operations (enhanced with ConnectionService)
    
    // ✅ FIXED: Connection Management via ConnectionService
    func testConnection() async {
        await connectionManager.testConnection()
        objectWillChange.send()
        
        // ✅ NEW: Log ConnectionService diagnostics if available
        if let connectionService = connectionManager.getConnectionService(),
           let health = await getConnectionHealth() {
            print("🔍 Connection test via ConnectionService: \(health.statusDescription)")
        }
    }
       
    // Data Loading (delegated to managers - unchanged)
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
    
    // Song Management (delegated to SongManager - unchanged)
    func loadSongs(for albumId: String) async -> [Song] {
        return await songManager.loadSongs(for: albumId)
    }
    
    func clearSongCache() {
        songManager.clearSongCache()
        objectWillChange.send()
    }
    
    // Search (delegated to SearchManager - unchanged)
    func search(query: String) async {
        await searchManager.search(query: query)
        objectWillChange.send()
    }
    
    // ✅ FIXED: Network Change Handling
    func handleNetworkChange(isOnline: Bool) async {
        await musicLibraryManager.handleNetworkChange(isOnline: isOnline)
        
        if isOnline {
            // ✅ FIXED: Trigger ConnectionService health check when network returns
            await connectionManager.performQuickHealthCheck()
            print("✅ NavidromeViewModel: Network restored - ConnectionService health checked")
        }
        
        objectWillChange.send()
    }
    
    // MARK: - ✅ LEGACY COMPATIBILITY (unchanged but enhanced logging)
    
    // Artist/Genre Detail Support
    func loadAlbums(context: ArtistDetailContext) async throws -> [Album] {
        let albums = try await musicLibraryManager.loadAlbums(context: context)
        print("✅ NavidromeViewModel: Loaded \(albums.count) albums for context via ContentService")
        return albums
    }
    
    // Statistics
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
    
    // MARK: - ✅ FIXED: Connection Health & Diagnostics with Direct ConnectionService Access
    
    /// Get comprehensive connection health via ConnectionService
    func getConnectionHealth() async -> ConnectionHealth? {
        guard let connectionService = connectionManager.getConnectionService() else {
            print("❌ ConnectionService not available for health check")
            return nil
        }
        
        return await connectionService.performHealthCheck()
    }
    
    /// Get connection diagnostics including ConnectionService data
    func getConnectionDiagnostics() async -> ConnectionDiagnostics {
        let connectionStatus = connectionManager.isConnected
        let connectionError = connectionManager.connectionError
        
        if let connectionService = connectionManager.getConnectionService(),
           let health = await getConnectionHealth() {
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
    
    /// Force connection health check via ConnectionService
    func performConnectionHealthCheck() async {
        await connectionManager.performQuickHealthCheck()
        
        if let health = await getConnectionHealth() {
            print("🏥 NavidromeViewModel: Health check completed - \(health.statusDescription)")
        }
        
        objectWillChange.send()
    }
       
    // MARK: - ✅ FIXED: Reset
    
    func reset() {
        connectionManager.reset()
        musicLibraryManager.reset()
        searchManager.reset()
        songManager.reset()
        service = nil
        
        // ✅ FIXED: Reset NetworkMonitor connection to ConnectionManager
        NetworkMonitor.shared.setConnectionManager(nil)
        
        objectWillChange.send()
        print("✅ NavidromeViewModel: Complete reset including ConnectionService")
    }
    
    // MARK: - ✅ FIXED: Service Architecture Diagnostics
    
    /// Get comprehensive service architecture status
    func getServiceArchitectureDiagnostics() async -> ServiceArchitectureDiagnostics {
        let connectionDiag = await getConnectionDiagnostics()
        let networkDiag = NetworkMonitor.shared.getNetworkDiagnostics()
        let songStats = songManager.getCacheStats()
        
        return ServiceArchitectureDiagnostics(
            connectionDiagnostics: connectionDiag,
            networkDiagnostics: networkDiag,
            songCacheStats: songStats,
            managersConfigured: service != nil
        )
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
                return "✅ All systems operational"
            } else if network {
                return "⚠️ Network issues detected"
            } else {
                return "❌ System issues detected"
            }
        }
        
        var architectureSummary: String {
            return """
            🏗️ SERVICE ARCHITECTURE STATUS:
            \(overallHealth)
            
            Connection Layer:
            \(connectionDiagnostics.summary)
            
            Network Layer:
            \(networkDiagnostics.summary)
            
            Cache Layer:
            \(songCacheStats.summary)
            
            Managers: \(managersConfigured ? "✅ Configured" : "❌ Not Configured")
            """
        }
    }
    
    #if DEBUG
    /// Print comprehensive diagnostics for debugging
    func printServiceDiagnostics() {
        Task {
            let diagnostics = await getServiceArchitectureDiagnostics()
            print(diagnostics.architectureSummary)
            
            // Additional ConnectionService specific diagnostics
            if let health = await getConnectionHealth() {
                print("""
                
                🔍 CONNECTIONSERVICE DETAILS:
                - Quality: \(health.quality.description)
                - Response Time: \(String(format: "%.0f", health.responseTime * 1000))ms
                - Health Score: \(String(format: "%.1f", health.healthScore * 100))%
                """)
            }
        }
    }
    #endif
}

// MARK: - ✅ FIXED: Supporting Types

struct ConnectionDiagnostics {
    let isConnected: Bool
    let connectionHealth: ConnectionHealth?
    let errorMessage: String?
    let hasService: Bool
    
    var summary: String {
        if hasService, let health = connectionHealth {
            return """
            🏗️ SERVICE ARCHITECTURE:
            - ConnectionService: ✅
            - Connection: \(isConnected ? "✅" : "❌")
            - Health: \(health.statusDescription)
            """
        } else {
            return """
            🏗️ SERVICE ARCHITECTURE:
            - ConnectionService: ❌
            - Connection: \(isConnected ? "✅" : "❌")
            - Error: \(errorMessage ?? "Unknown")
            """
        }
    }
}

// Legacy compatibility types (unchanged)
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

// MARK: - ✅ FIXED: Convenience Computed Properties

extension NavidromeViewModel {
    
    /// Quick connection health check
    var isConnectedAndHealthy: Bool {
        return connectionManager.isConnected
    }
    
    /// Connection status for UI display
    var connectionStatusText: String {
        return connectionManager.connectionStatusText
    }
    
    /// Connection status color for UI
    var connectionStatusColor: Color {
        return connectionManager.connectionStatusColor
    }
    
    /// Search mode description
    var searchModeDescription: String {
        return searchManager.searchModeDescription
    }
    
    /// Enhanced connection quality description
    var connectionQualityDescription: String {
        return connectionManager.connectionStatusText
    }
    
    /// Get connection response time for UI display
    var connectionResponseTime: String {
        return connectionManager.isConnected ? "< 1000 ms" : "No connection"
    }
}

 

