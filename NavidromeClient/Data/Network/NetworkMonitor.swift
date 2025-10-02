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
        self.state = NetworkState(
            isConnected: true,
            isConfigured: false,
            hasServerErrors: false,
            manualOfflineMode: false
        )
        
        startNetworkMonitoring()
        observeAppConfigChanges()
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
    
    func updateConfiguration(isConfigured: Bool) {
        updateState(isConfigured: isConfigured)
    }
    
    func reportServerError() {
        hasRecentServerErrors = true
        updateState()
        print("[NetworkMonitor] Server error reported")
    }
    
    func clearServerErrors() {
        hasRecentServerErrors = false
        updateState()
        print("[NetworkMonitor] Server errors cleared")
    }
    
    func setManualOfflineMode(_ enabled: Bool) {
        guard state.isConnected else {
            print("[NetworkMonitor] Cannot change offline mode: no network connection")
            return
        }
        
        guard state.isConfigured else {
            print("[NetworkMonitor] Cannot change offline mode: server not configured")
            return
        }
        
        guard !hasRecentServerErrors else {
            print("[NetworkMonitor] Cannot change offline mode: server has errors")
            return
        }
        
        manualOfflineMode = enabled
        updateState()
        print("[NetworkMonitor] Manual offline mode: \(enabled ? "enabled" : "disabled")")
    }
    
    func reset() {
        hasRecentServerErrors = false
        manualOfflineMode = false
        updateState()
        print("[NetworkMonitor] Reset completed")
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
                print("[NetworkMonitor] Strategy changed: \(oldStrategy.displayName) -> \(newStrategy.displayName)")
                
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
                    print("[NetworkMonitor] Network restored: \(self.connectionType.displayName)")
                    self.hasRecentServerErrors = false
                } else if !isNowConnected && wasConnected {
                    print("[NetworkMonitor] Network lost")
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
    
    // MARK: - AppConfig Integration
    
    private func observeAppConfigChanges() {
        NotificationCenter.default.addObserver(
            forName: .servicesNeedInitialization,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleServiceConfigurationChange()
            }
        }
    }
    
    private func handleServiceConfigurationChange() {
        hasRecentServerErrors = false
        print("[NetworkMonitor] Service configuration change detected")
        updateState(isConfigured: true)  // Tell it the server is configured
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
        
        print("""
        
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
        print("[NetworkMonitor] DEBUG: Forced state to \(state.contentLoadingStrategy.displayName)")
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
