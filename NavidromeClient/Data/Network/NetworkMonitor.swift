// NetworkMonitor.swift - Enhanced Version

import Foundation
import Network
import SwiftUI

@MainActor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    // Existing properties
    @Published var isConnected = true
    @Published var connectionType: NetworkConnectionType = .unknown
    
    // Enhanced: Server connection status
    @Published var isServerReachable = true
    @Published var lastServerCheck: Date?
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    // Enhanced: Server ping management
    private var serverCheckTimer: Timer?
    private var currentService: SubsonicService?
    
    enum NetworkConnectionType {
        case wifi, cellular, ethernet, unknown
    }
    
    private init() {
        startMonitoring()
        startServerMonitoring()
    }
    
    deinit {
        monitor.cancel()
        serverCheckTimer?.invalidate()
    }
    
    // MARK: - Network Monitoring (existing)
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasConnected = self?.isConnected ?? false
                self?.isConnected = path.status == .satisfied
                self?.connectionType = self?.getConnectionType(path) ?? .unknown
                
                if self?.isConnected == true {
                    print("📶 Network connected: \(self?.connectionType ?? .unknown)")
                    // When network comes back, immediately check server
                    self?.checkServerConnection()
                } else {
                    print("📵 Network disconnected")
                    self?.isServerReachable = false
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
    
    // MARK: - FIX: Enhanced Server Monitoring
    
    func setService(_ service: SubsonicService?) {
        self.currentService = service
        if service != nil {
            checkServerConnection()
        }
    }
    
    private func startServerMonitoring() {
        // Check server every 30 seconds when app is active
        serverCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.checkServerConnection()
        }
    }
    
    func checkServerConnection() async {
        await checkServerConnectionInternal()
    }
    
    @MainActor
    private func checkServerConnectionInternal() async {
        // Only check if we have internet
        guard isConnected, let service = currentService else {
            isServerReachable = false
            return
        }
        
        let wasReachable = isServerReachable
        let serverReachable = await service.ping()
        
        isServerReachable = serverReachable
        lastServerCheck = Date()
        
        if wasReachable != serverReachable {
            if serverReachable {
                print("🟢 Navidrome server is reachable again")
            } else {
                print("🔴 Navidrome server is unreachable - switching to offline mode")
                // FIX: Post notification for automatic offline switch
                NotificationCenter.default.post(name: .serverUnreachable, object: nil)
            }
        }
    }
    
    private func checkServerConnection() {
        Task { @MainActor in
            await checkServerConnectionInternal()
        }
    }
    
    // MARK: - FIX: Enhanced Computed Properties
    
    /// True if both internet AND server are reachable
    var canLoadOnlineContent: Bool {
        return isConnected && isServerReachable
    }
    
    /// True if we should force offline mode (no server access)
    var shouldForceOfflineMode: Bool {
        return !canLoadOnlineContent
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let serverUnreachable = Notification.Name("serverUnreachable")
}
