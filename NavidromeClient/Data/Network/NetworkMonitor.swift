//
//  NetworkMonitor.swift - FIXED: Centralized Network State Logic
//  NavidromeClient
//
//   ADDED: Single source of truth for network/offline decisions
//   FIXED: Consistent state across all views
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
    
    // MARK: - PHASE 1: Centralized State Logic
    
    /// Single source of truth for whether online content should be loaded
    var shouldLoadOnlineContent: Bool {
        return isConnected && canLoadOnlineContent && !OfflineManager.shared.isOfflineMode
    }
    
    /// Complete connection state for UI decisions
    var effectiveConnectionState: EffectiveConnectionState {
        if !isConnected {
            return .disconnected
        } else if !canLoadOnlineContent {
            return .serverUnreachable
        } else if OfflineManager.shared.isOfflineMode {
            return .userOffline
        } else {
            return .online
        }
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
                
                // PHASE 1: Notify dependent managers of state changes
                if wasConnected != isNowConnected {
                    self?.notifyStateChange(wasConnected: wasConnected, isNowConnected: isNowConnected)
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
    
    // MARK: - PHASE 1: State Change Coordination
    
    private func notifyStateChange(wasConnected: Bool, isNowConnected: Bool) {
        if isNowConnected {
            print("📶 Network connected: \(connectionType.displayName)")
            // Trigger reactive updates in dependent managers
            MusicLibraryManager.shared.objectWillChange.send()
        } else {
            print("📵 Network disconnected")
            // Force offline mode when network is lost
            OfflineManager.shared.handleNetworkLoss()
        }
        
        // Notify all views that need to update
        NotificationCenter.default.post(name: .networkStateChanged, object: effectiveConnectionState)
    }
    
    // MARK: - External Server Health Updates
    
    func updateServerAvailability(_ isAvailable: Bool) {
        let wasAvailable = canLoadOnlineContent
        canLoadOnlineContent = isAvailable
        
        // Notify if availability changed
        if wasAvailable != isAvailable {
            print("🏥 Server availability changed: \(isAvailable)")
            MusicLibraryManager.shared.objectWillChange.send()
            NotificationCenter.default.post(name: .networkStateChanged, object: effectiveConnectionState)
        }
    }
    
    // MARK: - Computed Properties
    
    var connectionStatusDescription: String {
        switch effectiveConnectionState {
        case .online: return "Online"
        case .userOffline: return "Offline Mode"
        case .serverUnreachable: return "Server Unreachable"
        case .disconnected: return "No Internet"
        }
    }
    
    // MARK: - Simple Diagnostics
    
    func getNetworkDiagnostics() -> NetworkDiagnostics {
        return NetworkDiagnostics(
            isConnected: isConnected,
            connectionType: connectionType,
            canLoadOnlineContent: canLoadOnlineContent,
            effectiveState: effectiveConnectionState
        )
    }
    
    struct NetworkDiagnostics {
        let isConnected: Bool
        let connectionType: NetworkConnectionType
        let canLoadOnlineContent: Bool
        let effectiveState: EffectiveConnectionState
        
        var summary: String {
            var status: [String] = []
            
            status.append("Network: \(isConnected ? "✅" : "❌")")
            status.append("Type: \(connectionType.displayName)")
            status.append("Server: \(canLoadOnlineContent ? "✅" : "❌")")
            status.append("State: \(effectiveState.displayName)")
            
            return status.joined(separator: " | ")
        }
        
        var canLoadContent: Bool {
            return effectiveState.shouldLoadOnlineContent
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
        - Centralized State Logic: ✅
        - Effective State: \(effectiveConnectionState.displayName)
        - Should Load Online: \(shouldLoadOnlineContent)
        """)
    }
    #endif
}

// MARK: - PHASE 1: Effective Connection State

enum EffectiveConnectionState {
    case online
    case userOffline
    case serverUnreachable
    case disconnected
    
    var shouldLoadOnlineContent: Bool {
        return self == .online
    }
    
    var displayName: String {
        switch self {
        case .online: return "Online"
        case .userOffline: return "User Offline"
        case .serverUnreachable: return "Server Unreachable"
        case .disconnected: return "Disconnected"
        }
    }
    
    var isEffectivelyOffline: Bool {
        return !shouldLoadOnlineContent
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let networkStateChanged = Notification.Name("networkStateChanged")
}
