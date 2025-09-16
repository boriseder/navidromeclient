//
//  NavidromeViewModel.swift - UPDATED for ConnectionManager Migration
//  NavidromeClient
//
//  ✅ UPDATED: ConnectionManager now uses ConnectionService internally
//  ✅ ENHANCED: Better service configuration and diagnostics
//  ✅ BACKWARDS COMPATIBLE: All existing API calls unchanged
//

import Foundation
import SwiftUI

@MainActor
class NavidromeViewModel: ObservableObject {
    
    // MARK: - ✅ UPDATED: Manager Dependencies with ConnectionService integration
    private let connectionManager = ConnectionManager()
    let musicLibraryManager = MusicLibraryManager.shared
    private let searchManager = SearchManager()
    private let songManager = SongManager()
    
    // MARK: - ✅ ENHANCED: Service Management with ConnectionService
    private var service: UnifiedSubsonicService? {
        connectionManager.getService()
    }
    
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
    
    // ✅ UPDATED: Connection State (now powered by ConnectionService)
    var connectionStatus: Bool { connectionManager.connectionStatus }
    var serverType: String? { connectionManager.serverType }
    var serverVersion: String? { connectionManager.serverVersion }
    var subsonicVersion: String? { connectionManager.subsonicVersion }
    var openSubsonic: Bool? { connectionManager.openSubsonic }
    var errorMessage: String? { connectionManager.connectionError }
    
    // Search Results (delegated to SearchManager)
    var searchResults: SearchManager.SearchResults { searchManager.searchResults }
    var songs: [Song] { searchResults.songs } // Legacy compatibility
    
    // ✅ UPDATED: Credential UI Bindings (now managed by ConnectionManager with ConnectionService)
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
    
    // MARK: - ✅ UPDATED: Setup & Configuration with ConnectionService
    
    private func setupManagerDependencies() {
        if let service = service {
            configureManagers(with: service)
        }
    }
    
    /// ✅ NEW: Setup ConnectionService integration
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
        connectionManager.updateService(newService)
        configureManagers(with: newService)
        
        // ✅ UPDATED: Update NetworkMonitor with ConnectionManager
        NetworkMonitor.shared.setConnectionManager(connectionManager)
        
        objectWillChange.send()
        print("✅ NavidromeViewModel: Service and ConnectionManager updated")
    }
    
    func getService() -> UnifiedSubsonicService? {
        return service
    }
    
    // MARK: - ✅ UPDATED: Core Operations (enhanced with ConnectionService)
    
    // ✅ ENHANCED: Connection Management via ConnectionService
    func testConnection() async {
        await connectionManager.testConnection()
        objectWillChange.send()
        
        // ✅ NEW: Log ConnectionService diagnostics
        let diagnostics = connectionManager.getConnectionDiagnostics()
        print("🔍 Connection test via ConnectionService: \(diagnostics.summary)")
    }
    
    func saveCredentials() async -> Bool {
        let success = await connectionManager.testAndSaveCredentials()
        if success, let service = connectionManager.getService() {
            configureManagers(with: service)
            
            // ✅ UPDATED: Update NetworkMonitor with ConnectionManager
            NetworkMonitor.shared.setConnectionManager(connectionManager)
        }
        objectWillChange.send()
        
        if success {
            print("✅ NavidromeViewModel: Credentials saved via ConnectionService")
        } else {
            print("❌ NavidromeViewModel: Failed to save credentials via ConnectionService")
        }
        
        return success
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
    
    // ✅ ENHANCED: Network Change Handling with ConnectionService
    func handleNetworkChange(isOnline: Bool) async {
        await musicLibraryManager.handleNetworkChange(isOnline: isOnline)
        
        if isOnline {
            // ✅ NEW: Trigger ConnectionService health check when network returns
            await connectionManager.performHealthCheck()
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
    
    // MARK: - ✅ ENHANCED: Connection Health & Diagnostics
    
    /// Get comprehensive connection health via ConnectionService
    func getConnectionHealth() -> ConnectionManager.ConnectionHealth {
        return connectionManager.getConnectionHealth()
    }
    
    /// Get connection diagnostics including ConnectionService data
    func getConnectionDiagnostics() -> ConnectionManager.ConnectionDiagnostics {
        return connectionManager.getConnectionDiagnostics()
    }
    
    /// Force connection health check via ConnectionService
    func performConnectionHealthCheck() async {
        await connectionManager.performHealthCheck()
        objectWillChange.send()
        
        let health = connectionManager.getConnectionHealth()
        print("🏥 NavidromeViewModel: Health check completed - \(health.statusDescription)")
    }
    
    /// Get ConnectionService instance for advanced usage
    func getConnectionService() -> ConnectionService? {
        return connectionManager.getConnectionService()
    }
    
    // MARK: - ✅ RESET (Enhanced for ConnectionService)
    
    func reset() {
        connectionManager.reset()
        musicLibraryManager.reset()
        searchManager.reset()
        songManager.reset()
        
        // ✅ UPDATED: Reset NetworkMonitor connection to ConnectionManager
        NetworkMonitor.shared.setConnectionManager(nil)
        
        objectWillChange.send()
        print("✅ NavidromeViewModel: Complete reset including ConnectionService")
    }
    
    // MARK: - ✅ NEW: Service Architecture Diagnostics
    
    /// Get comprehensive service architecture status
    func getServiceArchitectureDiagnostics() -> ServiceArchitectureDiagnostics {
        let connectionDiag = connectionManager.getConnectionDiagnostics()
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
        let connectionDiagnostics: ConnectionManager.ConnectionDiagnostics
        let networkDiagnostics: NetworkMonitor.NetworkDiagnostics
        let songCacheStats: SongCacheStats
        let managersConfigured: Bool
        
        var overallHealth: String {
            let connection = connectionDiagnostics.connectionStatus
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
            \(connectionDiagnostics.serviceArchitecture)
            
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
        let diagnostics = getServiceArchitectureDiagnostics()
        print(diagnostics.architectureSummary)
        
        // Additional ConnectionService specific diagnostics
        if let connectionService = getConnectionService() {
            let health = getConnectionHealth()
            print("""
            
            🔍 CONNECTIONSERVICE DETAILS:
            - Quality: \(health.quality.description)
            - Response Time: \(String(format: "%.0f", health.responseTime * 1000))ms
            - Health Score: \(String(format: "%.1f", health.healthScore * 100))%
            """)
        }
    }
    #endif
}

// MARK: - ✅ LEGACY COMPATIBILITY TYPES (unchanged)

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

// MARK: - ✅ ENHANCED: Convenience Computed Properties

extension NavidromeViewModel {
    
    /// Quick connection health check (enhanced with ConnectionService data)
    var isConnectedAndHealthy: Bool {
        return connectionManager.isConnectedAndHealthy
    }
    
    /// Connection status for UI display (enhanced with ConnectionService quality)
    var connectionStatusText: String {
        return connectionManager.connectionStatusText
    }
    
    /// Connection status color for UI (enhanced with ConnectionService quality)
    var connectionStatusColor: Color {
        return connectionManager.connectionStatusColor
    }
    
    /// Search mode description (enhanced with service context)
    var searchModeDescription: String {
        return searchManager.searchModeDescription
    }
    
    /// Enhanced connection quality description
    var connectionQualityDescription: String {
        let health = connectionManager.getConnectionHealth()
        return health.statusDescription
    }
    
    /// Get connection response time for UI display
    var connectionResponseTime: String {
        let health = connectionManager.getConnectionHealth()
        return String(format: "%.0f ms", health.responseTime * 1000)
    }
}

extension ConnectionManager {
    /// Get ConnectionService instance for advanced usage
    func getConnectionService() -> ConnectionService? {
        return connectionService
    }
}

extension ConnectionManager.ConnectionDiagnostics {
    var serviceArchitecture: String {
        return """
        🏗️ SERVICE ARCHITECTURE:
        - ConnectionService: \(hasConnectionService ? "✅" : "❌")
        - Legacy Service: \(hasLegacyService ? "✅" : "❌")
        - Connection: \(connectionStatus ? "✅" : "❌")
        - Health: \(connectionHealth.statusDescription)
        """
    }
}

