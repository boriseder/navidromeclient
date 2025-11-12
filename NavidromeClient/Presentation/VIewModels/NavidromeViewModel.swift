import Foundation
import SwiftUI

@MainActor
class NavidromeViewModel: ObservableObject {
    
    // MARK: - Service Dependencies
    private var unifiedService: UnifiedSubsonicService?
    
    // MARK: - Manager Dependencies
    private let connectionManager = ConnectionViewModel()
    private let musicLibraryManager: MusicLibraryManager
    
    init(musicLibraryManager: MusicLibraryManager) {
        self.musicLibraryManager = musicLibraryManager
    }
    
    // MARK: - Service Configuration
    
    func updateService(_ newService: UnifiedSubsonicService) {
        self.unifiedService = newService
        musicLibraryManager.configure(service: newService)
        objectWillChange.send()
        AppLogger.general.info("NavidromeViewModel configured with UnifiedSubsonicService facade")
    }
    
    // MARK: - Published Properties (Delegated to Managers)
    
    var albums: [Album] { musicLibraryManager.albums }
    var artists: [Artist] { musicLibraryManager.artists }
    var genres: [Genre] { musicLibraryManager.genres }
    
    var isLoading: Bool { musicLibraryManager.isLoading }
    var hasLoadedInitialData: Bool { musicLibraryManager.hasLoadedInitialData }
    var isLoadingInBackground: Bool { musicLibraryManager.isLoadingInBackground }
    var backgroundLoadingProgress: String { musicLibraryManager.backgroundLoadingProgress }
    var isDataFresh: Bool { musicLibraryManager.isDataFresh }
    
    var connectionStatus: Bool { connectionManager.isConnected }
    var errorMessage: String? { connectionManager.connectionError }
    
    
    // MARK: - Connection Operations
    
    func testConnection() async {
        await connectionManager.testConnection()
        objectWillChange.send()
    }
    
    func saveCredentials() async -> Bool {
        return await connectionManager.saveCredentials()
    }
    
    
    // MARK: - Content Operations
    
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
    
    
    // MARK: - Artist/Genre Detail Operations
    
    func loadAlbums(context: AlbumCollectionContext) async throws -> [Album] {
        guard let service = unifiedService else {
            throw URLError(.networkConnectionLost)
        }
        
        switch context {
        case .byArtist(let artist):
            return try await service.getAlbumsByArtist(artistId: artist.id)
        case .byGenre(let genre):
            return try await service.getAlbumsByGenre(genre: genre.value)
        }
    }

    
    // MARK: - Network Change Handling
    
    func handleNetworkChange(isOnline: Bool) async {
        await musicLibraryManager.handleNetworkChange(isOnline: isOnline)
        
        if isOnline {
            await connectionManager.performQuickHealthCheck()
            AppLogger.general.info("NavidromeViewModel: Network restored - health checked")
        }
        
        objectWillChange.send()
    }
    
    
    // MARK: - Connection Health
    
    func getConnectionHealth() async -> ConnectionHealth? {
        guard let service = unifiedService else {
            AppLogger.general.info("UnifiedSubsonicService not available for health check")
            return nil
        }
        
        return await service.performHealthCheck()
    }
    
    func performConnectionHealthCheck() async {
        do {
            // Prüfe zuerst, ob die Methode throwable ist
            try await connectionManager.performQuickHealthCheck()
            
            if let health = await getConnectionHealth() {
                AppLogger.general.info("NavidromeViewModel: Health check completed - \(health.statusDescription)")
            } else {
                AppLogger.general.warn("NavidromeViewModel: Health check returned nil")
            }
            
        } catch {
            // Fehlerfall abfangen
            AppLogger.general.error("NavidromeViewModel: Health check failed - \(error.localizedDescription)")
        }
        
        // View aktualisieren
        objectWillChange.send()
    }
    
    // MARK: - Reset & Cleanup
    
    func reset() {
        connectionManager.reset()
        musicLibraryManager.reset()
        unifiedService = nil
        
        objectWillChange.send()
        AppLogger.general.info("NavidromeViewModel: Complete reset")
    }
    
    // MARK: - Diagnostics
        
    func getServiceArchitectureDiagnostics() async -> ServiceArchitectureDiagnostics {
        let connectionDiag = await getConnectionDiagnostics()
        let networkDiag = NetworkMonitor.shared.getDiagnostics()
        
        return ServiceArchitectureDiagnostics(
            connectionDiagnostics: connectionDiag,
            networkDiagnostics: networkDiag,
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
                errorMessage: connectionError ?? "Service not available",
                hasService: false
            )
        }
    }
    
    #if DEBUG
    func printServiceDiagnostics() {
        Task {
            let diagnostics = await getServiceArchitectureDiagnostics()
            AppLogger.general.info(diagnostics.architectureSummary)
            
            if let health = await getConnectionHealth() {
                AppLogger.general.info("""
                
                FACADE CONNECTION DETAILS:
                - Quality: \(health.quality.description)
                - Response Time: \(String(format: "%.0f", health.responseTime * 1000))ms
                - Health Score: \(String(format: "%.1f", health.healthScore * 100))%
                """)
            }
        }
    }
    #endif
}


// MARK: - Supporting Types

struct ServiceArchitectureDiagnostics {
    let connectionDiagnostics: ConnectionDiagnostics
    let networkDiagnostics: NetworkMonitor.NetworkDiagnostics
    let managersConfigured: Bool
    
    var overallHealth: String {
        let hasService = connectionDiagnostics.hasService
        let hasInternet = networkDiagnostics.hasInternet
        let isServerReachable = networkDiagnostics.isServerReachable
        let isFullyConnected = networkDiagnostics.state.isFullyConnected

        if hasService && isFullyConnected {
            return "All systems operational"
        } else if hasInternet && !isServerReachable {
            return "Server unreachable - check server status"
        } else if !hasInternet {
            return "No internet connection"
        } else if !hasService {
            return "Service not configured"
        } else {
            return "System issues detected"
        }
    }

    var architectureSummary: String {
        return """
        FACADE ARCHITECTURE STATUS:
        \(overallHealth)
        
        Connection Layer:
        \(connectionDiagnostics.summary)
        
        Network Layer:
        \(networkDiagnostics.summary)
        
        Managers: \(managersConfigured ? "Configured" : "Not Configured")
        """
    }
}

struct ConnectionDiagnostics {
    let isConnected: Bool               // Service connection established
    let connectionHealth: ConnectionHealth?
    let errorMessage: String?
    let hasService: Bool                // Service is configured
    
    var summary: String {
        if hasService, let health = connectionHealth {
            return """
            FACADE ARCHITECTURE:
            - Service: Available
            - Connection: \(isConnected ? "Established" : "Not Established")
            - Health: \(health.statusDescription)
            """
        } else {
            return """
            FACADE ARCHITECTURE:
            - Service: \(hasService ? "Available" : "Not Available")
            - Connection: \(isConnected ? "Established" : "Not Established")
            - Error: \(errorMessage ?? "Unknown")
            """
        }
    }
}


// MARK: - Convenience Computed Properties

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
}
