//
//  ConnectionManager.swift - MIGRATED to ConnectionService
//  NavidromeClient
//
//  ✅ MIGRATION COMPLETE: All connection logic moved to ConnectionService
//  ✅ ENHANCED: Better separation of concerns - UI binding vs connection logic
//  ✅ BACKWARDS COMPATIBLE: All existing API calls unchanged
//

import Foundation
import SwiftUI

@MainActor
class ConnectionManager: ObservableObject {
    
    // MARK: - ✅ MIGRATION: ConnectionService Integration
    
    private var connectionService: ConnectionService?
    private var lastCredentials: (URL, String, String)?
    
    // MARK: - ✅ UI STATE MANAGEMENT (unchanged API)
    
    @Published private(set) var connectionStatus = false
    @Published private(set) var isTestingConnection = false
    @Published private(set) var connectionError: String?
    
    // Server Information (delegated to ConnectionService)
    @Published private(set) var serverType: String?
    @Published private(set) var serverVersion: String?
    @Published private(set) var subsonicVersion: String?
    @Published private(set) var openSubsonic: Bool?
    
    // Credential UI Bindings (local state for form binding)
    @Published var scheme: String = "http"
    @Published var host: String = ""
    @Published var port: String = ""
    @Published var username: String = ""
    @Published var password: String = ""
    
    // Connection Quality (delegated to ConnectionService)
    @Published private(set) var connectionQuality: ConnectionQuality = .unknown
    @Published private(set) var averageResponseTime: TimeInterval = 0
    
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
        
        var color: Color {
            switch self {
            case .unknown: return .gray
            case .excellent: return .green
            case .good: return .blue
            case .poor: return .orange
            case .timeout: return .red
            }
        }
    }
    
    // MARK: - ✅ SERVICE MANAGEMENT (unchanged API)
    
    /// Legacy service instance (backwards compatible)
    private var legacyService: UnifiedSubsonicService?
    private var lastSuccessfulConnection: Date?
    
    // MARK: - Initialization
    
    init() {
        loadSavedCredentials()
    }
    
    // MARK: - ✅ MIGRATION: Enhanced Connection Testing with ConnectionService
    
    /// Test connection with current credentials
    func testConnection() async {
        guard let url = buildCurrentURL() else {
            await updateConnectionState(success: false, error: "Invalid server URL")
            return
        }
        
        isTestingConnection = true
        connectionError = nil
        
        // ✅ MIGRATION: Create ConnectionService for testing
        let testConnectionService = ConnectionService(
            baseURL: url,
            username: username,
            password: password
        )
        
        let result = await testConnectionService.testConnection()
        
        await MainActor.run {
            self.isTestingConnection = false
            
            switch result {
            case .success(let connectionInfo):
                // ✅ MIGRATION: Update UI state from ConnectionService result
                self.connectionStatus = true
                self.connectionError = nil
                self.serverType = connectionInfo.type
                self.serverVersion = connectionInfo.serverVersion
                self.subsonicVersion = connectionInfo.version
                self.openSubsonic = connectionInfo.openSubsonic
                self.lastSuccessfulConnection = Date()
                
                // ✅ MIGRATION: Map ConnectionService quality to local enum
                self.connectionQuality = mapConnectionServiceQuality(testConnectionService.connectionQuality)
                self.averageResponseTime = 1.0 // Default, could be enhanced
                
                print("✅ ConnectionService test successful: \(connectionInfo.type) v\(connectionInfo.serverVersion)")
                
            case .failure(let connectionError):
                // ✅ MIGRATION: Enhanced error handling from ConnectionService
                await self.updateConnectionState(success: false, error: connectionError.userMessage)
                print("❌ ConnectionService test failed: \(connectionError.userMessage)")
            }
        }
    }
    
    /// Test connection and save credentials if successful
    func testAndSaveCredentials() async -> Bool {
        guard let url = buildCurrentURL() else {
            connectionError = "Invalid URL format"
            return false
        }
        
        // First test the connection
        await testConnection()
        
        guard connectionStatus else {
            return false
        }
        
        // If test successful, save credentials and create services
        AppConfig.shared.configure(baseURL: url, username: username, password: password)
        
        // ✅ MIGRATION: Create both ConnectionService and legacy service
        await createServices(baseURL: url, username: username, password: password)
        
        print("✅ Credentials saved and services configured via ConnectionService")
        return true
    }
    
    // MARK: - ✅ MIGRATION: Enhanced Service Management
    
    /// Get legacy service for backwards compatibility
    func getService() -> UnifiedSubsonicService? {
        return legacyService
    }
    
    /// Update service instance (used by app coordinator)
    func updateService(_ newService: UnifiedSubsonicService) {
        self.legacyService = newService
        
        // ✅ MIGRATION: Extract credentials and update ConnectionService
        if let creds = AppConfig.shared.getCredentials() {
            lastCredentials = (creds.baseURL, creds.username, creds.password)
            
            connectionService = ConnectionService(
                baseURL: creds.baseURL,
                username: creds.username,
                password: creds.password
            )
        }
        
        print("✅ ConnectionManager: Services updated with ConnectionService integration")
    }
    
    /// Check if service is available and configured
    var isServiceAvailable: Bool {
        return legacyService != nil && connectionStatus
    }
    
    // MARK: - ✅ MIGRATION: Enhanced Connection Monitoring
    
    /// Ping server to check if still reachable
    func pingServer() async -> Bool {
        guard let connectionService = connectionService else {
            print("❌ No ConnectionService available for ping")
            return false
        }
        
        let startTime = Date()
        let isReachable = await connectionService.ping()
        let responseTime = Date().timeIntervalSince(startTime)
        
        await MainActor.run {
            self.connectionStatus = isReachable
            self.averageResponseTime = responseTime
            self.connectionQuality = mapConnectionServiceQuality(connectionService.connectionQuality)
            
            if isReachable {
                self.lastSuccessfulConnection = Date()
            }
        }
        
        print("🏥 ConnectionService ping: \(isReachable ? "SUCCESS" : "FAILED") (\(String(format: "%.0f", responseTime * 1000))ms)")
        return isReachable
    }
    
    /// Perform health check using ConnectionService
    func performHealthCheck() async {
        guard connectionService != nil else {
            print("❌ No ConnectionService available for health check")
            return
        }
        
        let isHealthy = await pingServer()
        
        if !isHealthy {
            print("⚠️ Server unreachable via ConnectionService - consider switching to offline mode")
        } else {
            print("✅ ConnectionService health check: Server reachable")
        }
    }
    
    // MARK: - ✅ MIGRATION: Enhanced Connection Health Analysis
    
    /// Get connection health summary using ConnectionService data
    func getConnectionHealth() -> ConnectionHealth {
        return ConnectionHealth(
            isConnected: connectionStatus,
            quality: connectionQuality,
            responseTime: averageResponseTime,
            lastSuccessfulConnection: lastSuccessfulConnection,
            serverInfo: getServerInfo()
        )
    }
    
    struct ConnectionHealth {
        let isConnected: Bool
        let quality: ConnectionQuality
        let responseTime: TimeInterval
        let lastSuccessfulConnection: Date?
        let serverInfo: ServerInfo?
        
        var healthScore: Double {
            guard isConnected else { return 0.0 }
            
            switch quality {
            case .unknown: return 0.5
            case .excellent: return 1.0
            case .good: return 0.8
            case .poor: return 0.4
            case .timeout: return 0.1
            }
        }
        
        var statusDescription: String {
            if !isConnected {
                return "Disconnected"
            }
            
            let timeStr = String(format: "%.0f", responseTime * 1000)
            return "\(quality.description) (\(timeStr)ms)"
        }
    }
    
    // MARK: - ✅ SERVER INFORMATION (enhanced with ConnectionService data)
    
    struct ServerInfo {
        let type: String
        let version: String
        let subsonicVersion: String
        let openSubsonic: Bool
        
        var displayName: String {
            return openSubsonic ? "\(type) (OpenSubsonic)" : type
        }
        
        var fullVersionString: String {
            return "\(type) \(version) (Subsonic API \(subsonicVersion))"
        }
    }
    
    /// Get current server information
    func getServerInfo() -> ServerInfo? {
        guard let serverType = serverType,
              let serverVersion = serverVersion,
              let subsonicVersion = subsonicVersion,
              let openSubsonic = openSubsonic else {
            return nil
        }
        
        return ServerInfo(
            type: serverType,
            version: serverVersion,
            subsonicVersion: subsonicVersion,
            openSubsonic: openSubsonic
        )
    }
    
    // MARK: - ✅ CREDENTIAL MANAGEMENT (unchanged API)
    
    /// Load saved credentials from AppConfig
    private func loadSavedCredentials() {
        if let creds = AppConfig.shared.getCredentials() {
            self.scheme = creds.baseURL.scheme ?? "http"
            self.host = creds.baseURL.host ?? ""
            self.port = creds.baseURL.port.map { String($0) } ?? ""
            self.username = creds.username
            self.password = creds.password
            
            // ✅ MIGRATION: Create services from saved credentials
            Task {
                await createServices(
                    baseURL: creds.baseURL,
                    username: creds.username,
                    password: creds.password
                )
            }
            
            // Assume connection is good if we have saved credentials
            connectionStatus = true
            
            print("✅ Loaded saved credentials and created ConnectionService")
        }
    }
    
    /// Build URL from current credential components
    private func buildCurrentURL() -> URL? {
        let portString = port.isEmpty ? "" : ":\(port)"
        return URL(string: "\(scheme)://\(host)\(portString)")
    }
    
    /// Validate current credentials format
    func validateCredentials() -> CredentialValidationResult {
        // URL validation
        guard let url = buildCurrentURL(),
              let scheme = url.scheme, ["http", "https"].contains(scheme),
              let host = url.host, !host.isEmpty else {
            return .invalid("Invalid server URL format")
        }
        
        // Username validation
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUsername.isEmpty,
              trimmedUsername.count >= 2, trimmedUsername.count <= 50 else {
            return .invalid("Username must be 2-50 characters")
        }
        
        // Password validation
        guard !password.isEmpty, password.count >= 4, password.count <= 100 else {
            return .invalid("Password must be 4-100 characters")
        }
        
        return .valid
    }
    
    enum CredentialValidationResult {
        case valid
        case invalid(String)
        
        var isValid: Bool {
            switch self {
            case .valid: return true
            case .invalid: return false
            }
        }
        
        var errorMessage: String? {
            switch self {
            case .valid: return nil
            case .invalid(let message): return message
            }
        }
    }
    
    // MARK: - ✅ MIGRATION: Private Helper Methods
    
    /// Create services from credentials
    private func createServices(baseURL: URL, username: String, password: String) async {
        // ✅ MIGRATION: Create ConnectionService
        connectionService = ConnectionService(
            baseURL: baseURL,
            username: username,
            password: password
        )
        
        // Create legacy UnifiedSubsonicService for backwards compatibility
        let newService = UnifiedSubsonicService(
            baseURL: baseURL,
            username: username,
            password: password
        )
        legacyService = newService
        
        // Store credentials for service management
        lastCredentials = (baseURL, username, password)
        
        print("✅ Created ConnectionService and legacy service")
    }
    
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
    
    /// Update connection state helper
    private func updateConnectionState(success: Bool, error: String? = nil) async {
        await MainActor.run {
            self.connectionStatus = success
            self.connectionError = error
            
            if !success {
                // Clear server info on failure
                self.serverType = nil
                self.serverVersion = nil
                self.subsonicVersion = nil
                self.openSubsonic = nil
                self.connectionQuality = .unknown
            }
        }
    }
    
    // MARK: - ✅ RESET (enhanced for service cleanup)
    
    func reset() {
        // Clear services
        connectionService = nil
        legacyService = nil
        lastCredentials = nil
        
        // Clear connection state
        connectionStatus = false
        isTestingConnection = false
        connectionError = nil
        
        // Clear server info
        serverType = nil
        serverVersion = nil
        subsonicVersion = nil
        openSubsonic = nil
        
        // Clear credentials
        scheme = "http"
        host = ""
        port = ""
        username = ""
        password = ""
        
        // Clear quality tracking
        connectionQuality = .unknown
        averageResponseTime = 0
        lastSuccessfulConnection = nil
        
        print("✅ ConnectionManager reset completed (including ConnectionService)")
    }
    
    // MARK: - ✅ MIGRATION: Enhanced Diagnostics
    
    /// Get connection diagnostics including ConnectionService data
    func getConnectionDiagnostics() -> ConnectionDiagnostics {
        return ConnectionDiagnostics(
            hasConnectionService: connectionService != nil,
            hasLegacyService: legacyService != nil,
            connectionStatus: connectionStatus,
            serverReachable: lastSuccessfulConnection != nil,
            credentialsValid: validateCredentials().isValid,
            serverInfo: getServerInfo(),
            connectionHealth: getConnectionHealth(),
            currentURL: buildCurrentURL()?.absoluteString
        )
    }
    
    struct ConnectionDiagnostics {
        let hasConnectionService: Bool
        let hasLegacyService: Bool
        let connectionStatus: Bool
        let serverReachable: Bool
        let credentialsValid: Bool
        let serverInfo: ServerInfo?
        let connectionHealth: ConnectionHealth
        let currentURL: String?
        
        var summary: String {
            var issues: [String] = []
            
            if !hasConnectionService { issues.append("No ConnectionService") }
            if !hasLegacyService { issues.append("No legacy service") }
            if !connectionStatus { issues.append("Connection failed") }
            if !serverReachable { issues.append("Server unreachable") }
            if !credentialsValid { issues.append("Invalid credentials") }
            
            return issues.isEmpty ? "All systems operational" : "Issues: \(issues.joined(separator: ", "))"
        }
        
        var serviceArchitecture: String {
            return """
            🏗️ SERVICE ARCHITECTURE:
            - ConnectionService: \(hasConnectionService ? "✅" : "❌")
            - Legacy Service: \(hasLegacyService ? "✅" : "❌")
            - Connection: \(connectionStatus ? "✅" : "❌")
            - Health: \(connectionHealth.statusDescription)
            """
        }
    }
}

// MARK: - ✅ CONVENIENCE EXTENSIONS (unchanged API)

extension ConnectionManager {
    
    /// Quick connection status check
    var isConnectedAndHealthy: Bool {
        return connectionStatus && connectionQuality != .timeout
    }
    
    /// Get connection status for UI display
    var connectionStatusText: String {
        if isTestingConnection {
            return "Testing connection via ConnectionService..."
        } else if connectionStatus {
            return "Connected (\(connectionQuality.description))"
        } else {
            return connectionError ?? "Not connected"
        }
    }
    
    /// Get connection status color for UI
    var connectionStatusColor: Color {
        if isTestingConnection {
            return .blue
        } else if connectionStatus {
            return connectionQuality.color
        } else {
            return .red
        }
    }
    
    /// Get ConnectionService instance for advanced usage
    func getConnectionService() -> ConnectionService? {
        return connectionService
    }
    
    /// Force reconnection using ConnectionService
    func forceReconnect() async {
        guard let (baseURL, username, password) = lastCredentials else {
            print("❌ No credentials available for reconnection")
            return
        }
        
        print("🔄 Force reconnecting via ConnectionService...")
        await createServices(baseURL: baseURL, username: username, password: password)
        await testConnection()
    }
}
