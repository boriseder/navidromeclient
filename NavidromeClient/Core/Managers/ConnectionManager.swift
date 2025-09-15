//
//  ConnectionManager.swift - Service & Network State Specialist
//  NavidromeClient
//
//  ✅ CLEAN: Single Responsibility - Service State & Connection Management
//  ✅ EXTRACTS: All connection/service logic from NavidromeViewModel
//

import Foundation
import SwiftUI

@MainActor
class ConnectionManager: ObservableObject {
    
    // MARK: - Connection State
    
    @Published private(set) var connectionStatus = false
    @Published private(set) var isTestingConnection = false
    @Published private(set) var connectionError: String?
    
    // MARK: - Server Information
    
    @Published private(set) var serverType: String?
    @Published private(set) var serverVersion: String?
    @Published private(set) var subsonicVersion: String?
    @Published private(set) var openSubsonic: Bool?
    
    // MARK: - Credential State (for UI binding)
    
    @Published var scheme: String = "http"
    @Published var host: String = ""
    @Published var port: String = ""
    @Published var username: String = ""
    @Published var password: String = ""
    
    // MARK: - Service Management
    
    private var service: SubsonicService?
    private var lastSuccessfulConnection: Date?
    
    // MARK: - Connection Quality Tracking
    
    @Published private(set) var connectionQuality: ConnectionQuality = .unknown
    @Published private(set) var averageResponseTime: TimeInterval = 0
    
    enum ConnectionQuality {
        case unknown
        case excellent  // < 500ms
        case good       // 500ms - 1.5s
        case poor       // 1.5s - 3s
        case timeout    // > 3s
        
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
    
    // MARK: - Initialization
    
    init() {
        loadSavedCredentials()
    }
    
    // MARK: - ✅ SERVICE ACCESS
    
    /// Get current service instance
    func getService() -> SubsonicService? {
        return service
    }
    
    /// Update service instance (used by app coordinator)
    func updateService(_ newService: SubsonicService) {
        self.service = newService
        print("✅ ConnectionManager: Service updated")
    }
    
    /// Check if service is available and configured
    var isServiceAvailable: Bool {
        return service != nil && connectionStatus
    }
    
    // MARK: - ✅ CONNECTION TESTING
    
    /// Test connection with current credentials
    func testConnection() async {
        guard let url = buildCurrentURL() else {
            connectionStatus = false
            connectionError = "Invalid server URL"
            return
        }
        
        isTestingConnection = true
        connectionError = nil
        
        let startTime = Date()
        let tempService = SubsonicService(baseURL: url, username: username, password: password)
        let result = await tempService.testConnection()
        let responseTime = Date().timeIntervalSince(startTime)
        
        await MainActor.run {
            self.averageResponseTime = responseTime
            self.connectionQuality = self.determineConnectionQuality(responseTime: responseTime)
            self.isTestingConnection = false
            
            switch result {
            case .success(let connectionInfo):
                self.connectionStatus = true
                self.connectionError = nil
                self.serverType = connectionInfo.type
                self.serverVersion = connectionInfo.serverVersion
                self.subsonicVersion = connectionInfo.version
                self.openSubsonic = connectionInfo.openSubsonic
                self.lastSuccessfulConnection = Date()
                
                print("✅ Connection test successful (\(String(format: "%.0f", responseTime * 1000))ms)")
                
            case .failure(let connectionError):
                self.connectionStatus = false
                self.connectionError = connectionError.userMessage
                self.clearServerInfo()
                
                print("❌ Connection test failed: \(connectionError)")
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
        
        // If test successful, save credentials and create service
        AppConfig.shared.configure(baseURL: url, username: username, password: password)
        
        let newService = SubsonicService(baseURL: url, username: username, password: password)
        updateService(newService)
        
        print("✅ Credentials saved and service configured")
        return true
    }
    
    // MARK: - ✅ CREDENTIAL MANAGEMENT
    
    /// Load saved credentials from AppConfig
    private func loadSavedCredentials() {
        if let creds = AppConfig.shared.getCredentials() {
            self.scheme = creds.baseURL.scheme ?? "http"
            self.host = creds.baseURL.host ?? ""
            self.port = creds.baseURL.port.map { String($0) } ?? ""
            self.username = creds.username
            self.password = creds.password
            
            // Create service from saved credentials
            let service = SubsonicService(
                baseURL: creds.baseURL,
                username: creds.username,
                password: creds.password
            )
            updateService(service)
            
            // Assume connection is good if we have saved credentials
            connectionStatus = true
            
            print("✅ Loaded saved credentials for \(creds.username)")
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
    
    // MARK: - ✅ CONNECTION QUALITY ANALYSIS
    
    private func determineConnectionQuality(responseTime: TimeInterval) -> ConnectionQuality {
        switch responseTime {
        case 0..<0.5:
            return .excellent
        case 0.5..<1.5:
            return .good
        case 1.5..<3.0:
            return .poor
        default:
            return .timeout
        }
    }
    
    /// Get connection health summary
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
    
    // MARK: - ✅ SERVER INFORMATION
    
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
    
    /// Clear server information (on connection failure)
    private func clearServerInfo() {
        serverType = nil
        serverVersion = nil
        subsonicVersion = nil
        openSubsonic = nil
    }
    
    // MARK: - ✅ CONNECTION MONITORING
    
    /// Ping server to check if still reachable
    func pingServer() async -> Bool {
        guard let service = service else { return false }
        
        let startTime = Date()
        let isReachable = await service.ping()
        let responseTime = Date().timeIntervalSince(startTime)
        
        await MainActor.run {
            self.connectionStatus = isReachable
            self.averageResponseTime = responseTime
            self.connectionQuality = self.determineConnectionQuality(responseTime: responseTime)
            
            if isReachable {
                self.lastSuccessfulConnection = Date()
            }
        }
        
        return isReachable
    }
    
    /// Automatic connection health check
    func performHealthCheck() async {
        guard isServiceAvailable else { return }
        
        let isHealthy = await pingServer()
        print("🏥 Connection health check: \(isHealthy ? "Healthy" : "Unhealthy")")
        
        if !isHealthy {
            // Could trigger offline mode here
            print("⚠️ Server unreachable - consider switching to offline mode")
        }
    }
    
    // MARK: - ✅ RESET (for logout/factory reset)
    
    func reset() {
        // Clear service
        service = nil
        
        // Clear connection state
        connectionStatus = false
        isTestingConnection = false
        connectionError = nil
        
        // Clear server info
        clearServerInfo()
        
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
        
        print("✅ ConnectionManager reset completed")
    }
    
    // MARK: - ✅ DEBUG & DIAGNOSTICS
    
    /// Get connection diagnostics for troubleshooting
    func getConnectionDiagnostics() -> ConnectionDiagnostics {
        return ConnectionDiagnostics(
            hasService: service != nil,
            connectionStatus: connectionStatus,
            serverReachable: lastSuccessfulConnection != nil,
            credentialsValid: validateCredentials().isValid,
            serverInfo: getServerInfo(),
            connectionHealth: getConnectionHealth(),
            currentURL: buildCurrentURL()?.absoluteString
        )
    }
    
    struct ConnectionDiagnostics {
        let hasService: Bool
        let connectionStatus: Bool
        let serverReachable: Bool
        let credentialsValid: Bool
        let serverInfo: ServerInfo?
        let connectionHealth: ConnectionHealth
        let currentURL: String?
        
        var summary: String {
            var issues: [String] = []
            
            if !hasService { issues.append("No service configured") }
            if !connectionStatus { issues.append("Connection failed") }
            if !serverReachable { issues.append("Server unreachable") }
            if !credentialsValid { issues.append("Invalid credentials") }
            
            return issues.isEmpty ? "All systems operational" : "Issues: \(issues.joined(separator: ", "))"
        }
    }
}

// MARK: - ✅ CONVENIENCE EXTENSIONS

extension ConnectionManager {
    
    /// Quick connection status check
    var isConnectedAndHealthy: Bool {
        return connectionStatus && connectionQuality != .timeout
    }
    
    /// Get connection status for UI display
    var connectionStatusText: String {
        if isTestingConnection {
            return "Testing connection..."
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
}
