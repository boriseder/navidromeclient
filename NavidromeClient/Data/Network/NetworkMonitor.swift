//
//  NetworkMonitor.swift - UNIFIED: Single Source of Truth for Content Loading
//  NavidromeClient
//
//   UNIFIED: Single ContentLoadingStrategy eliminates state inconsistencies
//   CENTRALIZED: All state decisions flow through one coordinator
//   CLEAN: Eliminates race conditions and redundant state logic
//

import Foundation
import Network
import SwiftUI

@MainActor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    // MARK: - Core Network State
    @Published var isConnected = true
    @Published var connectionType: NetworkConnectionType = .unknown
    @Published var canLoadOnlineContent = true
    
    // MARK: - SINGLE SOURCE OF TRUTH
    @Published private(set) var contentLoadingStrategy: ContentLoadingStrategy = .online
    
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
        observeOfflineModeChanges()
    }
    
    deinit {
        monitor.cancel()
    }
    
    // MARK: - Content Loading Strategy (Single Source of Truth)
    
    /// The authoritative source for all content loading decisions
    var shouldLoadOnlineContent: Bool {
        contentLoadingStrategy.shouldLoadOnlineContent
    }
    
    /// Legacy compatibility - maps to new strategy system
    var effectiveConnectionState: EffectiveConnectionState {
        switch contentLoadingStrategy {
        case .online: return .online
        case .offlineOnly(let reason):
            switch reason {
            case .noNetwork: return .disconnected
            case .serverUnreachable: return .serverUnreachable
            case .userChoice: return .userOffline
            }
        }
    }
    
    // MARK: - CENTRALIZED STATE CALCULATION
    
    private func updateContentLoadingStrategy() {
        let newStrategy: ContentLoadingStrategy
        
        if !isConnected {
            newStrategy = .offlineOnly(reason: .noNetwork)
        } else if !canLoadOnlineContent {
            newStrategy = .offlineOnly(reason: .serverUnreachable)
        } else if OfflineManager.shared.isOfflineMode {
            newStrategy = .offlineOnly(reason: .userChoice)
        } else {
            newStrategy = .online
        }
        
        if contentLoadingStrategy != newStrategy {
            let previousStrategy = contentLoadingStrategy
            contentLoadingStrategy = newStrategy
            
            print("📊 Content loading strategy: \(previousStrategy.displayName) → \(newStrategy.displayName)")
            
            // Trigger reactive updates in dependent managers
            objectWillChange.send()
            
            // Notify other systems
            NotificationCenter.default.post(
                name: .contentLoadingStrategyChanged,
                object: newStrategy
            )
            
            // Update dependent managers
            MusicLibraryManager.shared.objectWillChange.send()
        }
    }
    
    // MARK: - Network Monitoring
    
    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                let wasConnected = self.isConnected
                let isNowConnected = path.status == .satisfied
                
                self.isConnected = isNowConnected
                self.connectionType = self.getConnectionType(path)
                
                // Reset server availability when network disconnects
                if !isNowConnected && wasConnected {
                    self.canLoadOnlineContent = false
                }
                
                // Update the unified strategy
                self.updateContentLoadingStrategy()
                
                // Handle network state changes
                if wasConnected != isNowConnected {
                    self.handleNetworkStateChange(wasConnected: wasConnected, isNowConnected: isNowConnected)
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
    
    private func handleNetworkStateChange(wasConnected: Bool, isNowConnected: Bool) {
        if isNowConnected && !wasConnected {
            print("📶 Network restored: \(connectionType.displayName)")
            
            // Notify OfflineManager to handle automatic mode switching
            OfflineManager.shared.handleNetworkRestored()
            
        } else if !isNowConnected && wasConnected {
            print("📵 Network lost")
            
            // Force offline mode when network is completely lost
            OfflineManager.shared.handleNetworkLoss()
        }
    }
    
    // MARK: - Server Availability Management
    
    func updateServerAvailability(_ isAvailable: Bool) {
        let wasAvailable = canLoadOnlineContent
        canLoadOnlineContent = isAvailable
        
        if wasAvailable != isAvailable {
            print("🏥 Server availability: \(wasAvailable ? "✅" : "❌") → \(isAvailable ? "✅" : "❌")")
            updateContentLoadingStrategy()
        }
    }
    
    // MARK: - Offline Mode Integration
    
    private func observeOfflineModeChanges() {
        NotificationCenter.default.addObserver(
            forName: .offlineModeChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.updateContentLoadingStrategy()
        }
    }
    
    // MARK: - Public State Queries
    
    var connectionStatusDescription: String {
        contentLoadingStrategy.displayName
    }
    
    // MARK: - Diagnostics
    
    func getNetworkDiagnostics() -> NetworkDiagnostics {
        return NetworkDiagnostics(
            isConnected: isConnected,
            connectionType: connectionType,
            canLoadOnlineContent: canLoadOnlineContent,
            contentLoadingStrategy: contentLoadingStrategy
        )
    }
    
    struct NetworkDiagnostics {
        let isConnected: Bool
        let connectionType: NetworkConnectionType
        let canLoadOnlineContent: Bool
        let contentLoadingStrategy: ContentLoadingStrategy
        
        var summary: String {
            var status: [String] = []
            
            status.append("Network: \(isConnected ? "✅" : "❌")")
            status.append("Type: \(connectionType.displayName)")
            status.append("Server: \(canLoadOnlineContent ? "✅" : "❌")")
            status.append("Strategy: \(contentLoadingStrategy.displayName)")
            
            return status.joined(separator: " | ")
        }
        
        var canLoadContent: Bool {
            return contentLoadingStrategy.shouldLoadOnlineContent
        }
    }
    
    // MARK: - Reset & Debug
    
    func reset() {
        canLoadOnlineContent = false
        updateContentLoadingStrategy()
        print("🔄 NetworkMonitor: Reset completed")
    }
    
    #if DEBUG
    func printDiagnostics() {
        let diagnostics = getNetworkDiagnostics()
        
        print("""
        🌐 NETWORKMONITOR UNIFIED STATE DIAGNOSTICS:
        \(diagnostics.summary)
        
        Unified Architecture:
        - Single Source of Truth: ContentLoadingStrategy
        - Strategy: \(contentLoadingStrategy.displayName)
        - Should Load Online: \(shouldLoadOnlineContent)
        - Eliminates Race Conditions: ✅
        """)
    }
    
    /// Force a specific strategy for testing
    func debugSetStrategy(_ strategy: ContentLoadingStrategy) {
        contentLoadingStrategy = strategy
        objectWillChange.send()
        print("🧪 DEBUG: Forced strategy to \(strategy.displayName)")
    }
    #endif
}

// MARK: - Content Loading Strategy (Single Source of Truth)

enum ContentLoadingStrategy: Equatable {
    case online                                    // Full online access
    case offlineOnly(reason: OfflineReason)        // Must use offline content
    
    enum OfflineReason: Equatable {
        case noNetwork            // Device has no internet
        case serverUnreachable    // Network exists but server down
        case userChoice          // User manually went offline
    }
    
    var shouldLoadOnlineContent: Bool {
        switch self {
        case .online: return true
        case .offlineOnly: return false
        }
    }
    
    var displayName: String {
        switch self {
        case .online: return "Online"
        case .offlineOnly(let reason):
            switch reason {
            case .noNetwork: return "No Internet"
            case .serverUnreachable: return "Server Unreachable"
            case .userChoice: return "Offline Mode"
            }
        }
    }
    
    var isEffectivelyOffline: Bool {
        return !shouldLoadOnlineContent
    }
}

// MARK: - UI Extensions for Strategy

extension ContentLoadingStrategy.OfflineReason {
    var icon: String {
        switch self {
        case .noNetwork: return "wifi.slash"
        case .serverUnreachable: return "exclamationmark.triangle"
        case .userChoice: return "icloud.slash"
        }
    }
    
    var color: Color {
        switch self {
        case .noNetwork: return DSColor.error
        case .serverUnreachable: return DSColor.warning
        case .userChoice: return DSColor.info
        }
    }
    
    var message: String {
        switch self {
        case .noNetwork: return "No internet connection - showing downloaded content"
        case .serverUnreachable: return "Server unreachable - showing downloaded content"
        case .userChoice: return "Offline mode active - showing downloaded content"
        }
    }
    
    var canGoOnline: Bool {
        switch self {
        case .noNetwork, .serverUnreachable: return false
        case .userChoice: return true
        }
    }
    
    var actionTitle: String {
        switch self {
        case .userChoice: return "Go Online"
        default: return ""
        }
    }
    
    func performAction(offlineManager: OfflineManager) {
        switch self {
        case .userChoice:
            Task {
                await offlineManager.switchToOnlineMode()
            }
        default:
            break
        }
    }
}

// MARK: - Legacy Compatibility

/// Legacy enum - maintained for backward compatibility during migration
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
    static let contentLoadingStrategyChanged = Notification.Name("contentLoadingStrategyChanged")
    static let networkStateChanged = Notification.Name("networkStateChanged") // Legacy - kept for compatibility
}
