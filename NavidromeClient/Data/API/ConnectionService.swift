//
//  ConnectionService.swift
//  NavidromeClient
//
//  Created by Boris Eder on 16.09.25.
//


//
//  ConnectionService.swift - Core Connection & Authentication
//  NavidromeClient
//
//   FOCUSED: Connection, auth, ping, health checks only
//

import Foundation
import CryptoKit

@MainActor
class ConnectionService: ObservableObject {
    private let baseURL: URL
    private let username: String
    private let password: String
    private let session: URLSession
    
    // MARK: - Connection State
    @Published private(set) var isConnected = false
    @Published private(set) var connectionQuality: ConnectionQuality = .unknown
    @Published private(set) var lastSuccessfulConnection: Date?
    
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
    
    // MARK: - Initialization
    init(baseURL: URL, username: String, password: String) {
        self.baseURL = baseURL
        self.username = username
        self.password = password
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpAdditionalHeaders = [
            "User-Agent": "NavidromeClient/1.0 iOS",
            "Accept": "application/json"
        ]
        config.urlCache = nil
        config.httpCookieAcceptPolicy = .never
        
        self.session = URLSession(configuration: config)
    }
    
    // MARK: -  CONNECTION TESTING
    func testConnection() async -> ConnectionTestResult {
        let startTime = Date()
        
        do {
            // Step 1: Basic ping
            let pingInfo = try await pingWithInfo()
            
            // Step 2: Verify with actual API call AND parse response
            let testURL = buildURL(endpoint: "getAlbumList2", params: ["type": "recent", "size": "1"])!
            let (data, response) = try await session.data(from: testURL)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.serverUnreachable)
            }
            
            // Check HTTP status
            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 401 {
                    return .failure(.invalidCredentials)
                }
                return .failure(.serverUnreachable)
            }
            
            // ✨ NEW: Parse and check for Subsonic errors
            do {
                let decodedResponse = try JSONDecoder().decode(
                    SubsonicResponse<SubsonicResponseContent>.self,
                    from: data
                )
                
                // Check if response contains error
                if decodedResponse.subsonicResponse.status == "failed" {
                    if let error = decodedResponse.subsonicResponse.error {
                        print("❌ Subsonic error: code=\(error.code), message=\(error.message)")
                        
                        // Error code 40 = Wrong username/password
                        if error.code == 40 || error.code == 41 {
                            return .failure(.invalidCredentials)
                        }
                        
                        return .failure(.networkError(error.message))
                    }
                    return .failure(.invalidCredentials)
                }
                
                // Success!
                let responseTime = Date().timeIntervalSince(startTime)
                updateConnectionState(responseTime: responseTime, success: true)
                
                let connectionInfo = ConnectionInfo(
                    version: pingInfo.version,
                    type: pingInfo.type,
                    serverVersion: pingInfo.serverVersion,
                    openSubsonic: pingInfo.openSubsonic
                )
                
                return .success(connectionInfo)
                
            } catch {
                print("❌ Failed to parse response: \(error)")
                return .failure(.invalidServerType)
            }
            
        } catch {
            updateConnectionState(responseTime: 0, success: false)
            return .failure(mapError(error))
        }
    }

    func ping() async -> Bool {
        do {
            let url = buildURL(endpoint: "ping")!
            let (_, response) = try await session.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                let success = httpResponse.statusCode == 200
                updateConnectionState(responseTime: 1.0, success: success)
                return success
            }
            return false
        } catch {
            updateConnectionState(responseTime: 0, success: false)
            return false
        }
    }
    
    private func pingWithInfo() async throws -> PingInfo {
        let url = buildURL(endpoint: "ping")!
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SubsonicError.unauthorized
        }
        
        let decoded = try JSONDecoder().decode(SubsonicResponse<PingInfo>.self, from: data)
        return decoded.subsonicResponse
    }
    
    // MARK: -  URL BUILDING & SECURITY
    
    func buildURL(endpoint: String, params: [String: String] = [:]) -> URL? {
        // Input validation
        guard validateEndpoint(endpoint) else {
            print("❌ Invalid endpoint: \(endpoint)")
            return nil
        }
        
        guard var components = URLComponents(string: baseURL.absoluteString) else {
            return nil
        }
        
        components.path = "/rest/\(endpoint).view"
        
        let salt = generateSecureSalt()
        let token = (password + salt).md5()
        
        var queryItems = [
            URLQueryItem(name: "u", value: username),
            URLQueryItem(name: "t", value: token),
            URLQueryItem(name: "s", value: salt),
            URLQueryItem(name: "f", value: "json"),
            URLQueryItem(name: "v", value: "1.16.1"),
            URLQueryItem(name: "c", value: "NavidromeClient")
        ]
        
        // Validate and add parameters mit proper encoding
        for (key, value) in params {
            guard validateParameter(key: key, value: value) else {
                print("❌ Invalid parameter: \(key)")
                continue
            }
            
            // URL-encode den Wert für Sonderzeichen
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        
        components.queryItems = queryItems
        return components.url
    }
    // MARK: -  HEALTH MONITORING
    
    func performHealthCheck() async -> ConnectionHealth {
        let startTime = Date()
        let isReachable = await ping()
        let responseTime = Date().timeIntervalSince(startTime)
        
        return ConnectionHealth(
            isConnected: isReachable,
            quality: determineConnectionQuality(responseTime: responseTime),
            responseTime: responseTime,
            lastSuccessfulConnection: lastSuccessfulConnection
        )
    }
    
    // MARK: -  PRIVATE HELPERS
    
    private func updateConnectionState(responseTime: TimeInterval, success: Bool) {
        isConnected = success
        connectionQuality = determineConnectionQuality(responseTime: responseTime)
        
        if success {
            lastSuccessfulConnection = Date()
        }
    }
    
    private func determineConnectionQuality(responseTime: TimeInterval) -> ConnectionQuality {
        switch responseTime {
        case 0..<0.5: return .excellent
        case 0.5..<1.5: return .good
        case 1.5..<3.0: return .poor
        default: return .timeout
        }
    }
    
    private func validateEndpoint(_ endpoint: String) -> Bool {
        let allowedEndpoints = [
            "ping", "getArtists", "getArtist", "getAlbum", "getAlbumList2",
            "getCoverArt", "stream", "getGenres", "search2",
            "star", "unstar", "getStarred2"
        ]
        return allowedEndpoints.contains(endpoint) &&
               endpoint.allSatisfy { $0.isLetter || $0.isNumber }
    }
    
    private func validateParameter(key: String, value: String) -> Bool {
        guard key.count <= 50, value.count <= 1000 else { return false }
        
        // Nur echte Security-Risiken blocken, nicht Genre-Zeichen
        let dangerousChars = CharacterSet(charactersIn: "<>\"'")
        return key.rangeOfCharacter(from: dangerousChars) == nil &&
               value.rangeOfCharacter(from: dangerousChars) == nil
    }
    
    private func generateSecureSalt() -> String {
        let saltLength = 12
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<saltLength).compactMap { _ in characters.randomElement() })
    }
    
    private func mapError(_ error: Error) -> ConnectionError {
        if let subsonicError = error as? SubsonicError {
            switch subsonicError {
            case .unauthorized: return .invalidCredentials
            case .timeout: return .timeout
            case .network: return .serverUnreachable
            default: return .networkError(subsonicError.localizedDescription)
            }
        } else if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut: return .timeout
            case .cannotConnectToHost, .cannotFindHost: return .serverUnreachable
            case .notConnectedToInternet: return .networkError("No internet connection")
            default: return .networkError(urlError.localizedDescription)
            }
        } else {
            return .networkError(error.localizedDescription)
        }
    }
}

// MARK: - Supporting Types

enum ConnectionTestResult {
    case success(ConnectionInfo)
    case failure(ConnectionError)
}

struct ConnectionInfo {
    let version: String
    let type: String
    let serverVersion: String
    let openSubsonic: Bool
}

enum ConnectionError {
    case invalidCredentials
    case serverUnreachable
    case timeout
    case networkError(String)
    case invalidServerType
    case invalidURL
    
    var userMessage: String {
        switch self {
        case .invalidCredentials:
            return "Invalid username or password"
        case .serverUnreachable:
            return "Server unreachable"
        case .timeout:
            return "Connection timeout"
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidServerType:
            return "Invalid server response"
        case .invalidURL:
            return "Invalid server URL"
        }
    }
}

struct ConnectionHealth {
    let isConnected: Bool
    let quality: ConnectionService.ConnectionQuality
    let responseTime: TimeInterval
    let lastSuccessfulConnection: Date?
    
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

extension String {
    func md5() -> String {
        let digest = Insecure.MD5.hash(data: Data(self.utf8))
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}
