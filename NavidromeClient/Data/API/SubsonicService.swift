// SubsonicService.swift - Enhanced mit testConnection

import Foundation
import UIKit

// MARK: - Connection Test Result
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
            return "Benutzername oder Passwort ist falsch"
        case .serverUnreachable:
            return "Server ist nicht erreichbar"
        case .timeout:
            return "Verbindung zum Server dauert zu lange"
        case .networkError(let message):
            return "Netzwerkfehler: \(message)"
        case .invalidServerType:
            return "Ungültige Server-Antwort - möglicherweise falscher Server-Typ"
        case .invalidURL:
            return "Ungültige Server-URL"
        }
    }
}

@MainActor
class SubsonicService: ObservableObject {
    private let baseURL: URL
    private let username: String
    private let password: String
    private let session: URLSession
    
    // MARK: - Security Improvements
    private static let maxRetries = 3
    private static let retryDelay: TimeInterval = 1.0
    
    init(baseURL: URL, username: String, password: String) {
        self.baseURL = baseURL
        self.username = username
        self.password = password
        
        let config = URLSessionConfiguration.default
        
        // Verbesserte Timeout-Konfiguration für Sicherheit
        config.timeoutIntervalForRequest = 10      // Reduziert von 30s
        config.timeoutIntervalForResource = 30     // Reduziert von 60s
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        // Zusätzliche Sicherheitseinstellungen
        config.allowsCellularAccess = true
        config.waitsForConnectivity = false        // Keine langen Wartezeiten
        config.httpMaximumConnectionsPerHost = 4   // Begrenze Verbindungen
        config.httpAdditionalHeaders = [
            "User-Agent": "NavidromeClient/1.0 iOS",
            "Accept": "application/json"
        ]
        
        // Disable caching for sensitive data
        config.urlCache = nil
        config.httpCookieAcceptPolicy = .never
        
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - NEW: Enhanced Connection Test
    func testConnection() async -> ConnectionTestResult {
        do {
            // Step 1: Test basic ping
            let pingInfo = try await pingWithInfo()
            
            // Step 2: Test actual API call to verify credentials - ENHANCED
            let albums = try await getRecentAlbums(size: 1)
            
            // Step 3: CRITICAL - Check if we got meaningful data
            // If server returns 200 but empty data, it might be invalid credentials
            if albums.isEmpty {
                print("⚠️ Server returned empty albums - possible authentication issue")
                
                // Try another endpoint to double-check
                do {
                    let artists = try await getArtists()
                    if artists.isEmpty {
                        print("❌ Multiple endpoints return empty - likely invalid credentials")
                        return .failure(.invalidCredentials)
                    }
                } catch {
                    print("❌ Artist endpoint also failed - invalid credentials")
                    return .failure(.invalidCredentials)
                }
            }
            
            let connectionInfo = ConnectionInfo(
                version: pingInfo.version,
                type: pingInfo.type,
                serverVersion: pingInfo.serverVersion,
                openSubsonic: pingInfo.openSubsonic
            )
            
            print("✅ Connection test successful - got \(albums.count) albums")
            return .success(connectionInfo)
            
        } catch {
            print("❌ Connection test failed: \(error)")
            
            // Enhanced error mapping
            if let subsonicError = error as? SubsonicError {
                switch subsonicError {
                case .unauthorized:
                    return .failure(.invalidCredentials)
                case .emptyResponse, .decoding:
                    // ENHANCED: Empty responses often mean invalid auth
                    print("🔍 Empty response detected - likely invalid credentials")
                    return .failure(.invalidCredentials)
                case .timeout:
                    return .failure(.timeout)
                case .network(let underlying):
                    if let urlError = underlying as? URLError {
                        switch urlError.code {
                        case .timedOut:
                            return .failure(.timeout)
                        case .cannotConnectToHost, .cannotFindHost:
                            return .failure(.serverUnreachable)
                        case .notConnectedToInternet:
                            return .failure(.networkError("Keine Internetverbindung"))
                        default:
                            return .failure(.networkError(urlError.localizedDescription))
                        }
                    } else {
                        return .failure(.networkError(underlying.localizedDescription))
                    }
                case .server(let statusCode):
                    return .failure(.networkError("Server-Fehler (Code: \(statusCode))"))
                case .badURL:
                    return .failure(.invalidURL)
                default:
                    return .failure(.networkError(subsonicError.localizedDescription))
                }
            } else {
                return .failure(.networkError(error.localizedDescription))
            }
        }
    }
    
    // MARK: - Enhanced URL Builder mit Validation
    func buildURL(endpoint: String, params: [String: String] = [:]) -> URL? {
        // Input Validation für Endpoint
        guard validateEndpoint(endpoint) else {
            SecureLogger.shared.logSecurityEvent("Invalid endpoint attempted: \(endpoint)", severity: .high)
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
        
        // Validate and sanitize parameters
        for (key, value) in params {
            guard validateParameter(key: key, value: value) else {
                SecureLogger.shared.logSecurityEvent("Invalid parameter blocked: \(key)", severity: .medium)
                continue
            }
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        
        components.queryItems = queryItems
        return components.url
    }
    
    // MARK: - Enhanced Fetch mit Retry Logic und Rate Limiting
    func fetchData<T: Decodable>(endpoint: String, params: [String: String] = [:], type: T.Type) async throws -> T {
        return try await fetchDataWithRetry(endpoint: endpoint, params: params, type: type, attempt: 1)
    }
    
    private func fetchDataWithRetry<T: Decodable>(
        endpoint: String,
        params: [String: String] = [:],
        type: T.Type,
        attempt: Int
    ) async throws -> T {
        
        do {
            return try await performFetch(endpoint: endpoint, params: params, type: type)
        } catch {
            // Retry Logic für bestimmte Fehler
            if attempt < Self.maxRetries && shouldRetry(error: error) {
                SecureLogger.shared.logNetworkError(endpoint: endpoint, error: error)
                
                // Exponential Backoff
                let delay = Self.retryDelay * pow(2.0, Double(attempt - 1))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                return try await fetchDataWithRetry(
                    endpoint: endpoint,
                    params: params,
                    type: type,
                    attempt: attempt + 1
                )
            }
            
            throw error
        }
    }
    
    private func performFetch<T: Decodable>(endpoint: String, params: [String: String], type: T.Type) async throws -> T {
        guard let url = buildURL(endpoint: endpoint, params: params) else {
            throw SubsonicError.badURL
        }
        
        // Rate Limiting Check
        try await RateLimiter.shared.checkLimit(for: baseURL.host ?? "unknown")
        
        let startTime = Date()
        
        // Log request (OHNE sensitive Parameter)
        let sanitizedParams = sanitizeParams(params)
        SecureLogger.shared.logNetworkRequest(endpoint: "\(endpoint) \(sanitizedParams)")
        
        do {
            let (data, response) = try await session.data(from: url)
            
            let duration = Date().timeIntervalSince(startTime)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            
            SecureLogger.shared.logNetworkResponse(
                endpoint: endpoint,
                statusCode: statusCode,
                duration: duration
            )
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SubsonicError.unknown
            }

            switch httpResponse.statusCode {
            case 200:
                do {
                    return try JSONDecoder().decode(T.self, from: data)
                } catch let decodingError {
                    SecureLogger.shared.logNetworkError(endpoint: endpoint, error: decodingError)
                    throw handleDecodingError(decodingError, endpoint: endpoint)
                }
            case 401:
                SecureLogger.shared.logSecurityEvent("Unauthorized access attempt to \(endpoint)", severity: .high)
                throw SubsonicError.unauthorized
            case 429:
                throw SubsonicError.rateLimited
            case 500...599:
                throw SubsonicError.server(statusCode: httpResponse.statusCode)
            default:
                throw SubsonicError.server(statusCode: httpResponse.statusCode)
            }
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            SecureLogger.shared.logNetworkResponse(endpoint: endpoint, statusCode: -1, duration: duration)
            
            if error is SubsonicError {
                throw error
            } else {
                SecureLogger.shared.logNetworkError(endpoint: endpoint, error: error)
                
                // Enhanced: Detect timeouts specifically
                if let urlError = error as? URLError, urlError.code == .timedOut {
                    print("🕐 Request timed out for endpoint: \(endpoint)")
                    throw SubsonicError.timeout(endpoint: endpoint)
                }
                
                throw SubsonicError.network(underlying: error)
            }
        }
    }
    
    // MARK: - Fetch mit Fallback für leere Responses
    func fetchDataWithFallback<T: Decodable>(
        endpoint: String,
        params: [String: String] = [:],
        type: T.Type,
        fallback: T
    ) async throws -> T {
        do {
            return try await fetchData(endpoint: endpoint, params: params, type: type)
        } catch {
            // Enhanced: Check for empty response decoding errors
            if let subsonicError = error as? SubsonicError, subsonicError.isEmptyResponse {
                print("🔄 Using fallback for empty response: \(endpoint)")
                return fallback
            }
            
            // NEW: Handle keyNotFound specifically for albumList2, artists, etc.
            if case DecodingError.keyNotFound(let key, _) = error {
                let emptyResponseKeys = ["albumList2", "artists", "genres", "searchResult2", "album"]
                if emptyResponseKeys.contains(key.stringValue) {
                    print("🔄 Server returned empty response for '\(key.stringValue)' in \(endpoint) - using fallback")
                    return fallback
                }
            }
            
            throw error
        }
    }
    
    // MARK: - Security Validation Methods
    
    private func validateEndpoint(_ endpoint: String) -> Bool {
        // Whitelist erlaubter Endpoints
        let allowedEndpoints = [
            "ping", "getArtists", "getArtist", "getAlbum", "getAlbumList2",
            "getSongs", "getCoverArt", "stream", "getGenres", "search2",
            "scrobble", "star", "unstar", "getStarred", "getPlaylists"
        ]
        
        return allowedEndpoints.contains(endpoint) &&
               endpoint.allSatisfy { $0.isLetter || $0.isNumber }
    }
    
    private func validateParameter(key: String, value: String) -> Bool {
        // Begrenze Parameter-Längen
        guard key.count <= 50, value.count <= 1000 else { return false }
        
        // Keine gefährlichen Zeichen
        let dangerousChars = CharacterSet(charactersIn: "<>\"'&;")
        return key.rangeOfCharacter(from: dangerousChars) == nil &&
               value.rangeOfCharacter(from: dangerousChars) == nil
    }
    
    private func generateSecureSalt() -> String {
        // Verwende kryptographisch sicheren Random Generator
        let saltLength = 12 // Mindestens 6, besser 12
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<saltLength).compactMap { _ in characters.randomElement() })
    }
    
    private func shouldRetry(error: Error) -> Bool {
        if let subsonicError = error as? SubsonicError {
            switch subsonicError {
            case .network:
                return true
            case .server(let code) where code >= 500:
                return true
            case .server:
                return false // 4xx errors should not be retried
            case .rateLimited:
                return true
            case .timeout:
                return false // Don't retry timeouts - switch to offline immediately
            case .badURL, .unauthorized, .invalidInput, .decoding, .emptyResponse, .unknown:
                return false
            }
        }
        return true // Retry für unbekannte Netzwerkfehler
    }
    
    private func sanitizeParams(_ params: [String: String]) -> String {
        let allowedParams = ["type", "size", "offset", "query", "maxResults", "id"]
        let sanitized = params.map { key, value in
            allowedParams.contains(key) ? "\(key)=\(value)" : "\(key)=***"
        }
        return sanitized.joined(separator: "&")
    }
    
    private func handleDecodingError(_ error: Error, endpoint: String) -> SubsonicError {
        if case DecodingError.keyNotFound(let key, _) = error {
            // Bekannte "leere Response" Szenarien
            let emptyResponseKeys = ["album", "artist", "song", "genre"]
            if emptyResponseKeys.contains(key.stringValue) {
                print("⚠️ Server returned empty response for key '\(key.stringValue)' in endpoint: \(endpoint)")
                return SubsonicError.emptyResponse(endpoint: endpoint)
            }
        }
        
        return SubsonicError.decoding(underlying: error)
    }
    
    // MARK: - Original API Methods
    
    func streamURL(for songId: String) -> URL? {
        guard validateParameter(key: "id", value: songId) else { return nil }
        return buildURL(endpoint: "stream", params: ["id": songId])
    }
    
    func ping() async -> Bool {
        do {
            _ = try await fetchData(endpoint: "ping", type: SubsonicResponse<EmptyResponse>.self)
            return true
        } catch {
            SecureLogger.shared.logNetworkError(endpoint: "ping", error: error)
            return false
        }
    }
            
    func pingWithInfo() async throws -> PingInfo {
        guard let url = URL(string: "\(baseURL)/rest/ping.view?u=\(username)&p=\(password)&f=json") else {
            throw URLError(.badURL)
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(SubsonicResponse<PingInfo>.self, from: data)
        return decoded.subsonicResponse
    }
}

// MARK: - Rate Limiter für zusätzliche Sicherheit
@MainActor
class RateLimiter {
    static let shared = RateLimiter()
    
    private var requestCounts: [String: (count: Int, resetTime: Date)] = [:]
    private let maxRequestsPerMinute = 60
    private let windowDuration: TimeInterval = 60
    
    private init() {}
    
    func checkLimit(for host: String) async throws {
        let now = Date()
        
        // Reset alte Einträge
        if let entry = requestCounts[host], now > entry.resetTime {
            requestCounts[host] = nil
        }
        
        // Aktuelle Anzahl prüfen
        let currentEntry = requestCounts[host] ?? (count: 0, resetTime: now.addingTimeInterval(windowDuration))
        
        guard currentEntry.count < maxRequestsPerMinute else {
            SecureLogger.shared.logSecurityEvent("Rate limit exceeded for host: \(host)", severity: .medium)
            throw SubsonicError.rateLimited
        }
        
        // Zähler erhöhen
        requestCounts[host] = (count: currentEntry.count + 1, resetTime: currentEntry.resetTime)
    }
}
