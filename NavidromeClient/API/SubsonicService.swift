import Foundation
import UIKit

@MainActor
class SubsonicService: ObservableObject {
    private let baseURL: URL
    private let username: String
    private let password: String
    private let session: URLSession
    
    init(baseURL: URL, username: String, password: String) {
        self.baseURL = baseURL
        self.username = username
        self.password = password
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - URL Builder mit MD5 Token
    func buildURL(endpoint: String, params: [String: String] = [:]) -> URL? {
        guard var components = URLComponents(string: baseURL.absoluteString) else { return nil }
        components.path = "/rest/\(endpoint).view"
        
        let salt = String(Int(Date().timeIntervalSince1970))
        let token = (password + salt).md5()
        
        var queryItems = [
            URLQueryItem(name: "u", value: username),
            URLQueryItem(name: "t", value: token),
            URLQueryItem(name: "s", value: salt),
            URLQueryItem(name: "f", value: "json"),
            URLQueryItem(name: "v", value: "1.16.1"),
            URLQueryItem(name: "c", value: "NavidromeClient")
        ]
        for (key, value) in params {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        components.queryItems = queryItems
        return components.url
    }
    
    // MARK: - Generic Fetch mit intelligenter Fehlerbehandlung
    func fetchData<T: Decodable>(endpoint: String, params: [String: String] = [:], type: T.Type) async throws -> T {
        guard let url = buildURL(endpoint: endpoint, params: params) else {
            throw SubsonicError.badURL
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SubsonicError.unknown
            }

            switch httpResponse.statusCode {
            case 200:
                do {
                    return try JSONDecoder().decode(T.self, from: data)
                } catch let decodingError {
                    throw handleDecodingError(decodingError, endpoint: endpoint)
                }
            case 401:
                throw SubsonicError.unauthorized
            default:
                throw SubsonicError.server(statusCode: httpResponse.statusCode)
            }
        } catch {
            if error is SubsonicError {
                throw error
            } else {
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
            if let subsonicError = error as? SubsonicError, subsonicError.isEmptyResponse {
                print("🔄 Using fallback for empty response: \(endpoint)")
                return fallback
            }
            throw error
        }
    }
    
    // MARK: - StreamURL
    func streamURL(for songId: String) -> URL? {
        buildURL(endpoint: "stream", params: ["id": songId])
    }
    
    // MARK: - Ping
    func ping() async -> Bool {
        do {
            _ = try await fetchData(endpoint: "ping", type: SubsonicResponse<EmptyResponse>.self)
            return true
        } catch {
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
    
    // MARK: - Private Helper
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
}
