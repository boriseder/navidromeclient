//
//  NetworkMonitor.swift - REFACTORED: Central Content Loading Authority
//  NavidromeClient
//
//   UNIFIED: Single authority for all content loading decisions
//   ELIMINATED: State fragmentation and race conditions
//   DERIVED: All state computed from core facts
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
    
    // MARK: - Content Loading Authority (Single Source of Truth)
    @Published private(set) var contentLoadingStrategy: ContentLoadingStrategy = .online
    
    // MARK: - Internal State (Derived Logic Components)
    @Published private(set) var hasRecentServerErrors = false
    @Published private(set) var manualOfflineMode = false
    
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
        observeAppConfigChanges()
    }
    
    deinit {
        monitor.cancel()
    }
    
    // MARK: - Computed Properties (Derived State)
    
    /// The authoritative decision for content loading
    var shouldLoadOnlineContent: Bool {
        contentLoadingStrategy.shouldLoadOnlineContent
    }
    
    /// Derived server availability (no separate state)
    var canLoadOnlineContent: Bool {
        guard isConnected else { return false }
        guard AppConfig.shared.isConfigured else { return false }
        return !hasRecentServerErrors
    }
    
    /// Legacy compatibility
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
    
    // MARK: - Content Loading Strategy (Central Authority)
    
    private func updateContentLoadingStrategy() {
        let newStrategy: ContentLoadingStrategy
        
        if !isConnected {
            newStrategy = .offlineOnly(reason: .noNetwork)
        } else if !AppConfig.shared.isConfigured {
            newStrategy = .offlineOnly(reason: .serverUnreachable)
        } else if hasRecentServerErrors {
            newStrategy = .offlineOnly(reason: .serverUnreachable)
        } else if manualOfflineMode {
            newStrategy = .offlineOnly(reason: .userChoice)
        } else {
            newStrategy = .online
        }
        
        if contentLoadingStrategy != newStrategy {
            let previousStrategy = contentLoadingStrategy
            contentLoadingStrategy = newStrategy
            
            print("📊 Content loading strategy: \(previousStrategy.displayName) → \(newStrategy.displayName)")
            
            // Trigger reactive updates
            objectWillChange.send()
            
            // Notify other systems
            NotificationCenter.default.post(
                name: .contentLoadingStrategyChanged,
                object: newStrategy
            )
        }
    }
    
    // MARK: - Public API (Manual Control)
    
    func setManualOfflineMode(_ enabled: Bool) {
        guard isConnected && canLoadOnlineContent else {
            print("⚠️ Cannot change offline mode: network or server unavailable")
            return
        }
        
        manualOfflineMode = enabled
        updateContentLoadingStrategy()
        
        print("📱 Manual offline mode: \(enabled ? "enabled" : "disabled")")
    }
    
    func reportServerError() {
        hasRecentServerErrors = true
        updateContentLoadingStrategy()
        
        print("🚨 Server error reported - switching to offline mode")
    }
    
    func clearServerErrors() {
        hasRecentServerErrors = false
        updateContentLoadingStrategy()
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
                
                self.handleNetworkStateChange(wasConnected: wasConnected, isNowConnected: isNowConnected)
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
            
            // Auto-heal: Clear server errors on network restore
            hasRecentServerErrors = false
            updateContentLoadingStrategy()
            
        } else if !isNowConnected && wasConnected {
            print("📵 Network lost")
            updateContentLoadingStrategy()
        } else {
            // Network state unchanged, but might need strategy update
            updateContentLoadingStrategy()
        }
    }
    
    // MARK: - AppConfig Integration
    
    private func observeAppConfigChanges() {
        // Listen for service configuration changes
        NotificationCenter.default.addObserver(
            forName: .servicesNeedInitialization,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleServiceConfigurationChange()
        }
    }
    
    private func handleServiceConfigurationChange() {
        // Clear errors when services are reconfigured
        hasRecentServerErrors = false
        updateContentLoadingStrategy()
        
        print("🔧 Service configuration detected - updating content loading strategy")
    }
    
    // MARK: - Diagnostics
    
    func getNetworkDiagnostics() -> NetworkDiagnostics {
        return NetworkDiagnostics(
            isConnected: isConnected,
            connectionType: connectionType,
            canLoadOnlineContent: canLoadOnlineContent,
            contentLoadingStrategy: contentLoadingStrategy,
            hasRecentServerErrors: hasRecentServerErrors,
            manualOfflineMode: manualOfflineMode
        )
    }
    
    struct NetworkDiagnostics {
        let isConnected: Bool
        let connectionType: NetworkConnectionType
        let canLoadOnlineContent: Bool
        let contentLoadingStrategy: ContentLoadingStrategy
        let hasRecentServerErrors: Bool
        let manualOfflineMode: Bool
        
        var summary: String {
            var status: [String] = []
            
            status.append("Network: \(isConnected ? "✅" : "❌")")
            status.append("Type: \(connectionType.displayName)")
            status.append("Server: \(canLoadOnlineContent ? "✅" : "❌")")
            status.append("Strategy: \(contentLoadingStrategy.displayName)")
            
            if hasRecentServerErrors {
                status.append("Errors: ⚠️")
            }
            if manualOfflineMode {
                status.append("Manual: 📱")
            }
            
            return status.joined(separator: " | ")
        }
        
        var canLoadContent: Bool {
            return contentLoadingStrategy.shouldLoadOnlineContent
        }
    }
    
    var connectionStatusDescription: String {
        contentLoadingStrategy.displayName
    }
    
    // MARK: - Reset & Debug
    
    func reset() {
        hasRecentServerErrors = false
        manualOfflineMode = false
        updateContentLoadingStrategy()
        print("🔄 NetworkMonitor: Reset completed")
    }
    
    #if DEBUG
    func printDiagnostics() {
        let diagnostics = getNetworkDiagnostics()
        
        print("""
        🌐 NETWORKMONITOR CENTRAL AUTHORITY DIAGNOSTICS:
        \(diagnostics.summary)
        
        Content Loading Authority:
        - Single Source: ContentLoadingStrategy
        - Strategy: \(contentLoadingStrategy.displayName)
        - Should Load Online: \(shouldLoadOnlineContent)
        - Derived State: All computed from core facts
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
        case serverUnreachable    // Network exists but server down/unconfigured
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
