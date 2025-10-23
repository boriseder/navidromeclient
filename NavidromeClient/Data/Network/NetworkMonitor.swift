//
//  NetworkMonitor.swift
//  NavidromeClient
//
//  Pure state management for network connectivity and content loading strategy.
//  NetworkState is the single source of truth, all dependencies are explicit.
//

import Foundation
import Network
import SwiftUI

@MainActor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    // MARK: - Single Source of Truth
    @Published private(set) var state: NetworkState
    
    // MARK: - Network Monitoring Infrastructure
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    // MARK: - Internal Hardware State
    private var isConnected = true
    private var connectionType: NetworkConnectionType = .unknown
    private var hasRecentServerErrors = false
    private var manualOfflineMode = false
    
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
        // SYNCHRONOUSLY determine initial network state before publishing
        let currentPath = monitor.currentPath
        let initialConnectionState = currentPath.status == .satisfied
        
        self.state = NetworkState(
            isConnected: initialConnectionState,
            isConfigured: false,
            hasServerErrors: false,
            manualOfflineMode: false
        )
        
        // Update internal state to match
        self.isConnected = initialConnectionState
        self.connectionType = getConnectionType(currentPath)
        
        AppLogger.network.info("[NetworkMonitor] Initial state: \(initialConnectionState ? "Connected" : "Disconnected") (\(connectionType.displayName))")
        
        startNetworkMonitoring()
       //BORIS observeAppConfigChanges()
    }

    
    deinit {
        monitor.cancel()
    }
    
    // MARK: - Public API - State Queries
    
    var shouldLoadOnlineContent: Bool {
        state.contentLoadingStrategy.shouldLoadOnlineContent
    }
    
    var contentLoadingStrategy: ContentLoadingStrategy {
        state.contentLoadingStrategy
    }
    
    var currentConnectionType: NetworkConnectionType {
        connectionType
    }
    
    var canLoadOnlineContent: Bool {
        state.isConnected && state.isConfigured && !hasRecentServerErrors
    }
    
    var connectionStatusDescription: String {
        state.contentLoadingStrategy.displayName
    }
    
    // MARK: - Legacy Compatibility
    
    var effectiveConnectionState: EffectiveConnectionState {
        switch state.contentLoadingStrategy {
        case .online:
            return .online
        case .offlineOnly(let reason):
            switch reason {
            case .noNetwork:
                return .disconnected
            case .serverUnreachable:
                return .serverUnreachable
            case .userChoice:
                return .userOffline
            }
        case .setupRequired:
            return .disconnected  // Treat as disconnected for legacy compatibility
        }
    }
    
    // MARK: - Public API - State Updates
    
    func initialize(isConfigured: Bool) {
        updateState(isConfigured: isConfigured)
        AppLogger.network.info("[NetworkMonitor] Explicitly initialized (configured: \(isConfigured))")
    }
    
    func updateConfiguration(isConfigured: Bool) {
        updateState(isConfigured: isConfigured)
    }
    
    func reportServerError() {
        hasRecentServerErrors = true
        updateState()
        AppLogger.network.info("[NetworkMonitor] Server error reported")
    }
    
    func clearServerErrors() {
        hasRecentServerErrors = false
        updateState()
        AppLogger.network.info("[NetworkMonitor] Server errors cleared")
    }
    
    func setManualOfflineMode(_ enabled: Bool) {
        // When enabling manual offline: no restrictions (user can always choose to go offline)
        // When disabling manual offline: verify network is available
        
        if !enabled {
            // User wants to go online - only check network connection
            // Don't check isConfigured because user needs to go online to configure/login
            guard state.isConnected else {
                AppLogger.network.info("[NetworkMonitor] Cannot go online: no network connection")
                return
            }
            /*
            guard state.isConfigured else {
                AppLogger.network.info("[NetworkMonitor] Cannot go online: server not configured")
                return
            }
            
            guard !hasRecentServerErrors else {
             */
            // Allow going online even if not configured (needed for login)
            // Only block if there are actual server errors (not just unconfigured)
            if state.isConfigured && hasRecentServerErrors {
                 AppLogger.network.info("[NetworkMonitor] Cannot go online: server has errors")
                 return
            }
        }
        
        manualOfflineMode = enabled
        updateState()
        AppLogger.network.info("[NetworkMonitor] Manual offline mode: \(enabled ? "enabled" : "disabled")")
    }
    
    func reset() {
        hasRecentServerErrors = false
        manualOfflineMode = false
        updateState()
        AppLogger.network.info("[NetworkMonitor] Reset completed")
    }
    
    // MARK: - State Update
    
    private func updateState(isConfigured: Bool? = nil) {
        let newState = NetworkState(
            isConnected: isConnected,
            isConfigured: isConfigured ?? state.isConfigured,
            hasServerErrors: hasRecentServerErrors,
            manualOfflineMode: manualOfflineMode
        )
        
        if newState != state {
            let oldStrategy = state.contentLoadingStrategy
            let newStrategy = newState.contentLoadingStrategy
            
            state = newState
            
            if oldStrategy != newStrategy {
                AppLogger.network.info("[NetworkMonitor] Strategy changed: \(oldStrategy.displayName) -> \(newStrategy.displayName)")
                
                NotificationCenter.default.post(
                    name: .contentLoadingStrategyChanged,
                    object: newStrategy
                )
            }
        }
    }
    
    // MARK: - Network Monitoring
    
    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                let wasConnected = self.isConnected
                let isNowConnected = path.status == .satisfied
                
                self.isConnected = isNowConnected
                self.connectionType = self.getConnectionType(path)
                
                if isNowConnected && !wasConnected {
                    AppLogger.network.info("[NetworkMonitor] Network restored: \(self.connectionType.displayName)")
                    self.hasRecentServerErrors = false
                } else if !isNowConnected && wasConnected {
                    AppLogger.network.info("[NetworkMonitor] Network lost")
                }
                
                self.updateState()
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
    
    // MARK: - Diagnostics
    
    func getDiagnostics() -> NetworkDiagnostics {
        NetworkDiagnostics(
            state: state,
            connectionType: connectionType,
            hasRecentServerErrors: hasRecentServerErrors,
            manualOfflineMode: manualOfflineMode
        )
    }
    
    struct NetworkDiagnostics {
        let state: NetworkState
        let connectionType: NetworkConnectionType
        let hasRecentServerErrors: Bool
        let manualOfflineMode: Bool
        
        var summary: String {
            var status: [String] = []
            
            status.append("Network: \(state.isConnected ? "Connected" : "Disconnected")")
            status.append("Type: \(connectionType.displayName)")
            status.append("Configured: \(state.isConfigured ? "Yes" : "No")")
            status.append("Strategy: \(state.contentLoadingStrategy.displayName)")
            
            if hasRecentServerErrors {
                status.append("Errors: Yes")
            }
            if manualOfflineMode {
                status.append("Manual Offline: Yes")
            }
            
            return status.joined(separator: " | ")
        }
    }
    
    // MARK: - Debug
    
    #if DEBUG
    func printDiagnostics() {
        let diagnostics = getDiagnostics()
        
        AppLogger.network.info("""
        
        [NetworkMonitor] DIAGNOSTICS:
        \(diagnostics.summary)
        
        State Details:
        \(state.debugDescription)
        
        Hardware:
        - Connection Type: \(connectionType.displayName)
        - Recent Errors: \(hasRecentServerErrors)
        - Manual Offline: \(manualOfflineMode)
        """)
    }
    
    func debugSetState(_ state: NetworkState) {
        self.state = state
        AppLogger.network.info("[NetworkMonitor] DEBUG: Forced state to \(state.contentLoadingStrategy.displayName)")
    }
    #endif
}

// MARK: - Notification Names

extension Notification.Name {
    static let contentLoadingStrategyChanged = Notification.Name("contentLoadingStrategyChanged")
    static let networkStateChanged = Notification.Name("networkStateChanged")
}

// MARK: - Legacy Compatibility

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
}
