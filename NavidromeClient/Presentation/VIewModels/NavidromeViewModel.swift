import Foundation
import SwiftUI

@MainActor
class NavidromeViewModel: ObservableObject {
    
    // MARK: - Service Dependencies
    private var unifiedService: UnifiedSubsonicService?
    
    // MARK: - Manager Dependencies
    private let connectionManager = ConnectionViewModel()
    let musicLibraryManager = MusicLibraryManager.shared
    
    init() {}
    
    // MARK: - Service Configuration
    
    func updateService(_ newService: UnifiedSubsonicService) {
        self.unifiedService = newService
        musicLibraryManager.configure(service: newService)
        objectWillChange.send()
        print("NavidromeViewModel configured with UnifiedSubsonicService facade")
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
            print("NavidromeViewModel: Network restored - health checked")
        }
        
        objectWillChange.send()
    }
    
    
    // MARK: - Connection Health
    
    func getConnectionHealth() async -> ConnectionHealth? {
        guard let service = unifiedService else {
            print("UnifiedSubsonicService not available for health check")
            return nil
        }
        
        return await service.performHealthCheck()
    }
    
    func performConnectionHealthCheck() async {
        await connectionManager.performQuickHealthCheck()
        
        if let health = await getConnectionHealth() {
            print("NavidromeViewModel: Health check completed - \(health.statusDescription)")
        }
        
        objectWillChange.send()
    }
    
    
    // MARK: - Reset & Cleanup
    
    func reset() {
        connectionManager.reset()
        musicLibraryManager.reset()
        unifiedService = nil
        
        objectWillChange.send()
        print("NavidromeViewModel: Complete reset")
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
            print(diagnostics.architectureSummary)
            
            if let health = await getConnectionHealth() {
                print("""
                
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
        let connection = connectionDiagnostics.isConnected
        let network = networkDiagnostics.state.isConnected  // Use state directly
        let server = connectionDiagnostics.hasService

        if connection && network && server {
            return "All systems operational"
        } else if network {
            return "Network issues detected"
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
    let isConnected: Bool
    let connectionHealth: ConnectionHealth?
    let errorMessage: String?
    let hasService: Bool
    
    var summary: String {
        if hasService, let health = connectionHealth {
            return """
            FACADE ARCHITECTURE:
            - Service: Available
            - Connection: \(isConnected ? "Connected" : "Not Connected")
            - Health: \(health.statusDescription)
            """
        } else {
            return """
            FACADE ARCHITECTURE:
            - Service: Not Available
            - Connection: \(isConnected ? "Connected" : "Not Connected")
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
    
    var connectionQualityDescription: String {
        return connectionManager.connectionStatusText
    }
    
    var connectionResponseTime: String {
        return connectionManager.isConnected ? "< 1000 ms" : "No connection"
    }
}
