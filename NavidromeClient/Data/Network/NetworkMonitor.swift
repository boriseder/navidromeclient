//
//  NetworkMonitor.swift - FIXED: ConnectionManager/ConnectionService Integration
//  NavidromeClient
//
//   FIXED: Direct ConnectionService access for detailed monitoring
//   FIXED: Simplified ConnectionManager usage for UI state
//   BACKWARDS COMPATIBLE: All existing API calls unchanged
//

import Foundation
import Network
import SwiftUI

@MainActor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    // Existing network properties (unchanged)
    @Published var isConnected = true
    @Published var connectionType: NetworkConnectionType = .unknown
    
    //  FIXED: Enhanced server connection status via ConnectionService
    @Published var isServerReachable = true
    @Published var lastServerCheck: Date?
    @Published var serverConnectionQuality: ConnectionQuality = .unknown
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    //  FIXED: ConnectionManager instead of direct service
    private var serverCheckTimer: Timer?
    private weak var connectionManager: ConnectionManager?
    
    enum NetworkConnectionType {
        case wifi, cellular, ethernet, unknown
    }
    
    //  FIXED: Simplified ConnectionQuality (no longer from ConnectionManager)
    enum ConnectionQuality {
        case unknown, excellent, good, poor, timeout
        
        var description: String {
            switch self {
            case .unknown: return "Unknown"
            case .excellent: return "Excellent"
            case .good: return "Good"
            case .poor: return "Poor"
            case .timeout: return "Timeout"
            }
        }
    }
    
    private init() {
        startMonitoring()
        startServerMonitoring()
    }
    
    deinit {
        monitor.cancel()
        serverCheckTimer?.invalidate()
    }
    
    // MARK: - Network Monitoring (unchanged)
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasConnected = self?.isConnected ?? false
                self?.isConnected = path.status == .satisfied
                self?.connectionType = self?.getConnectionType(path) ?? .unknown
                
                if self?.isConnected == true {
                    print("📶 Network connected: \(self?.connectionType ?? .unknown)")
                    // When network comes back, immediately check server via ConnectionManager
                    self?.checkServerConnection()
                } else {
                    print("📵 Network disconnected")
                    self?.isServerReachable = false
                    self?.serverConnectionQuality = .unknown
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    private func getConnectionType(_ path: NWPath) -> NetworkConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else {
            return .unknown
        }
    }
    
    // MARK: -  FIXED: Enhanced Server Monitoring via ConnectionManager/ConnectionService
    
    /// FIXED: Now accepts ConnectionManager instead of SubsonicService
    func setConnectionManager(_ manager: ConnectionManager?) {
        self.connectionManager = manager
        
        if manager != nil {
            print(" NetworkMonitor: ConnectionManager configured")
            checkServerConnection()
        } else {
            print("⚠️ NetworkMonitor: ConnectionManager removed")
            isServerReachable = false
            serverConnectionQuality = .unknown
        }
    }
    
    /// LEGACY: For backwards compatibility - extracts ConnectionManager from service
    func setService(_ service: UnifiedSubsonicService?) {
        // This method is deprecated but kept for backwards compatibility
        print("⚠️ NetworkMonitor.setService() is deprecated - use setConnectionManager() instead")
        
        if service != nil {
            // We can't easily extract ConnectionManager from service,
            // so we'll just mark as connected for legacy compatibility
            isServerReachable = true
            print(" NetworkMonitor: Legacy service configured (limited functionality)")
        } else {
            isServerReachable = false
            serverConnectionQuality = .unknown
        }
    }
    
    private func startServerMonitoring() {
        //  FIXED: Enhanced monitoring with ConnectionService integration
        serverCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.checkServerConnection()
        }
        print(" NetworkMonitor: Server monitoring started (30s intervals)")
    }
    
    func checkServerConnection() async {
        await checkServerConnectionInternal()
    }
    
    @MainActor
    private func checkServerConnectionInternal() async {
        // Only check if we have internet and ConnectionManager
        guard isConnected, let connectionManager = connectionManager else {
            if !isConnected {
                print("📵 NetworkMonitor: No internet connection")
            } else {
                print("⚠️ NetworkMonitor: No ConnectionManager configured")
            }
            isServerReachable = false
            serverConnectionQuality = .unknown
            return
        }
        
        let wasReachable = isServerReachable
        
        //  FIXED: Use ConnectionManager simplified API
        await connectionManager.performQuickHealthCheck()
        let serverReachable = connectionManager.isConnected
        
        //  FIXED: Get connection quality from ConnectionService if available
        var connectionQuality: ConnectionQuality = .unknown
        
        if let connectionService = connectionManager.getConnectionService() {
            let health = await connectionService.performHealthCheck()
            connectionQuality = mapConnectionServiceQuality(health.quality)
        } else {
            // Fallback to basic quality assessment
            connectionQuality = serverReachable ? .good : .timeout
        }
        
        isServerReachable = serverReachable
        serverConnectionQuality = connectionQuality
        lastServerCheck = Date()
        
        // Enhanced logging with ConnectionService data
        if wasReachable != serverReachable {
            if serverReachable {
                print("🟢 NetworkMonitor: Server reachable via ConnectionService (\(connectionQuality.description))")
            } else {
                print("🔴 NetworkMonitor: Server unreachable via ConnectionService - switching to offline mode")
                // Post notification for automatic offline switch
                NotificationCenter.default.post(name: .serverUnreachable, object: nil)
            }
        } else if serverReachable {
            print("🔄 NetworkMonitor: Server health check (\(connectionQuality.description))")
        }
    }
    
    private func checkServerConnection() {
        Task { @MainActor in
            await checkServerConnectionInternal()
        }
    }
    
    // MARK: -  FIXED: Enhanced Computed Properties with ConnectionService data
    
    /// True if both internet AND server are reachable via ConnectionService
    var canLoadOnlineContent: Bool {
        return isConnected && isServerReachable
    }
    
    /// True if we should force offline mode (no server access via ConnectionService)
    var shouldForceOfflineMode: Bool {
        return !canLoadOnlineContent
    }
    
    /// Enhanced connection status including server quality
    var connectionStatusDescription: String {
        if !isConnected {
            return "No Internet"
        } else if !isServerReachable {
            return "Server Unreachable"
        } else {
            return "Online (\(serverConnectionQuality.description))"
        }
    }
    
    /// Get comprehensive network diagnostics
    func getNetworkDiagnostics() -> NetworkDiagnostics {
        return NetworkDiagnostics(
            isConnected: isConnected,
            connectionType: connectionType,
            isServerReachable: isServerReachable,
            serverQuality: serverConnectionQuality,
            lastServerCheck: lastServerCheck,
            hasConnectionManager: connectionManager != nil
        )
    }
    
    struct NetworkDiagnostics {
        let isConnected: Bool
        let connectionType: NetworkConnectionType
        let isServerReachable: Bool
        let serverQuality: ConnectionQuality
        let lastServerCheck: Date?
        let hasConnectionManager: Bool
        
        var summary: String {
            var status: [String] = []
            
            status.append("Internet: \(isConnected ? "" : "❌")")
            status.append("Server: \(isServerReachable ? "" : "❌")")
            
            if let lastCheck = lastServerCheck {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                status.append("Last Check: \(formatter.string(from: lastCheck))")
            }
            
            status.append("ConnectionManager: \(hasConnectionManager ? "" : "❌")")
            
            return status.joined(separator: " | ")
        }
        
        var canLoadContent: Bool {
            return isConnected && isServerReachable && hasConnectionManager
        }
    }
    
    // MARK: -  FIXED: Enhanced Server Health Features
    
    /// Force immediate server health check via ConnectionService
    func forceServerHealthCheck() async {
        guard let connectionManager = connectionManager else {
            print("❌ NetworkMonitor: No ConnectionManager for health check")
            return
        }
        
        print("🏥 NetworkMonitor: Forcing server health check via ConnectionService...")
        await connectionManager.performQuickHealthCheck()
        
        // Update our state based on ConnectionManager results
        let isReachable = connectionManager.isConnected
        var quality: ConnectionQuality = .unknown
        
        if let connectionService = connectionManager.getConnectionService() {
            let health = await connectionService.performHealthCheck()
            quality = mapConnectionServiceQuality(health.quality)
        } else {
            quality = isReachable ? .good : .timeout
        }
        
        await MainActor.run {
            self.isServerReachable = isReachable
            self.serverConnectionQuality = quality
            self.lastServerCheck = Date()
        }
    }
    
    /// Get server connection quality score (0.0 - 1.0)
    var serverHealthScore: Double {
        guard isConnected && isServerReachable else { return 0.0 }
        
        switch serverConnectionQuality {
        case .unknown: return 0.5
        case .excellent: return 1.0
        case .good: return 0.8
        case .poor: return 0.4
        case .timeout: return 0.1
        }
    }
    
    // MARK: -  FIXED: Private Helper Methods
    
    /// Map ConnectionService.ConnectionQuality to local enum
    private func mapConnectionServiceQuality(_ serviceQuality: ConnectionService.ConnectionQuality) -> ConnectionQuality {
        switch serviceQuality {
        case .unknown: return .unknown
        case .excellent: return .excellent
        case .good: return .good
        case .poor: return .poor
        case .timeout: return .timeout
        }
    }
    
    // MARK: -  FIXED: Reset & Cleanup
    
    func reset() {
        connectionManager = nil
        isServerReachable = false
        serverConnectionQuality = .unknown
        lastServerCheck = nil
        
        print(" NetworkMonitor: Reset completed")
    }
    
    // MARK: -  DEBUG & DIAGNOSTICS
    
    #if DEBUG
    func printDiagnostics() {
        Task {
            let diagnostics = getNetworkDiagnostics()
            
            var connectionServiceStatus = "❌"
            var healthDetails = "Not available"
            
            if let connectionManager = connectionManager,
               let connectionService = connectionManager.getConnectionService() {
                connectionServiceStatus = ""
                let health = await connectionService.performHealthCheck()
                healthDetails = """
                Quality: \(health.quality.description)
                Response Time: \(String(format: "%.0f", health.responseTime * 1000))ms
                Health Score: \(String(format: "%.1f", health.healthScore * 100))%
                """
            }
            
            print("""
            🌐 NETWORKMONITOR DIAGNOSTICS:
            \(diagnostics.summary)
            
            Connection Architecture:
            - Network Monitor: 
            - ConnectionManager: \(connectionManager != nil ? "" : "❌")
            - ConnectionService: \(connectionServiceStatus)
            
            ConnectionService Details:
            \(healthDetails)
            
            Health Score: \(String(format: "%.1f", serverHealthScore * 100))%
            """)
        }
    }
    #endif
}

// MARK: - Notification Names (unchanged)
extension Notification.Name {
    static let serverUnreachable = Notification.Name("serverUnreachable")
}
