//
//  NetworkMonitor.swift - CLEAN: Network State Only
//  NavidromeClient
//
//   REMOVED: All server health checking logic
//   REMOVED: All service dependencies and dual configuration patterns
//   REMOVED: All timers and complex diagnostics
//   CLEAN: Pure network connectivity monitoring only
//

import Foundation
import Network
import SwiftUI

@MainActor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    // MARK: - Core Network State Only
    @Published var isConnected = true
    @Published var connectionType: NetworkConnectionType = .unknown
    
    // MARK: - Server Health (Set Externally)
    @Published var canLoadOnlineContent = true
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    enum NetworkConnectionType {
        case wifi, cellular, ethernet, unknown
        
        var displayName: String {
            switch self {
            case .wifi: return "WiFi"
            case .cellular: return "Cellular"
            case .ethernet: return "Ethernet"
            case .unknown: return "Unknown"
            }
        }
    }
    
    private init() {
        startNetworkMonitoring()
    }
    
    deinit {
        monitor.cancel()
    }
    
    // MARK: - Network Monitoring Only
    
    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasConnected = self?.isConnected ?? false
                let isNowConnected = path.status == .satisfied
                
                self?.isConnected = isNowConnected
                self?.connectionType = self?.getConnectionType(path) ?? .unknown
                
                // Reset server availability when network disconnects
                if !isNowConnected {
                    self?.canLoadOnlineContent = false
                }
                
                // Log significant changes only
                if wasConnected != isNowConnected {
                    if isNowConnected {
                        print("📶 Network connected: \(self?.connectionType.displayName ?? "Unknown")")
                    } else {
                        print("📵 Network disconnected")
                    }
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
    
    // MARK: - External Server Health Updates
    
    func updateServerAvailability(_ isAvailable: Bool) {
        canLoadOnlineContent = isAvailable
    }
    
    // MARK: - Computed Properties
    
    var connectionStatusDescription: String {
        if !isConnected {
            return "No Internet"
        } else if !canLoadOnlineContent {
            return "Server Unreachable"
        } else {
            return "Online"
        }
    }
    
    // MARK: - Simple Diagnostics
    
    func getNetworkDiagnostics() -> NetworkDiagnostics {
        return NetworkDiagnostics(
            isConnected: isConnected,
            connectionType: connectionType,
            canLoadOnlineContent: canLoadOnlineContent
        )
    }
    
    struct NetworkDiagnostics {
        let isConnected: Bool
        let connectionType: NetworkConnectionType
        let canLoadOnlineContent: Bool
        
        var summary: String {
            var status: [String] = []
            
            status.append("Network: \(isConnected ? "✅" : "❌")")
            status.append("Type: \(connectionType.displayName)")
            status.append("Server: \(canLoadOnlineContent ? "✅" : "❌")")
            
            return status.joined(separator: " | ")
        }
        
        var canLoadContent: Bool {
            return isConnected && canLoadOnlineContent
        }
    }
    
    // MARK: - Reset
    
    func reset() {
        canLoadOnlineContent = false
        print("🔄 NetworkMonitor: Reset completed")
    }
    
    // MARK: - Debug
    
    #if DEBUG
    func printDiagnostics() {
        let diagnostics = getNetworkDiagnostics()
        
        print("""
        🌐 NETWORKMONITOR DIAGNOSTICS:
        \(diagnostics.summary)
        
        Network Architecture:
        - Network Monitor: ✅ Pure network state only
        - Server Health: External coordination
        - Timers: ❌ Removed
        - Services: ❌ Removed
        """)
    }
    #endif
}

// MARK: - Notification Names
extension Notification.Name {
    static let networkStateChanged = Notification.Name("networkStateChanged")
}
