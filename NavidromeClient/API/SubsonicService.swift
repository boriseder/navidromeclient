//
//  SubsonicError.swift
//  NavidromeClient
//
//  Created by Boris Eder on 04.09.25.
//


import Foundation
import UIKit

@MainActor
enum SubsonicError: Error, LocalizedError {
    case badURL
    case network(underlying: Error)
    case server(statusCode: Int)
    case decoding(underlying: Error)
    case unauthorized
    case unknown

    var errorDescription: String? {
        switch self {
        case .badURL: return "Ungültige URL."
        case .network(let err): return "Netzwerkfehler: \(err.localizedDescription)"
        case .server(let code): return "Server antwortete mit Status \(code)."
        case .decoding(let err): return "Fehler beim Verarbeiten der Daten: \(err.localizedDescription)"
        case .unauthorized: return "Benutzername oder Passwort ist falsch."
        case .unknown: return "Unbekannter Fehler."
        }
    }
}

@MainActor
class SubsonicService: ObservableObject {
    private let baseURL: URL
    private let username: String
    private let password: String
    private let session: URLSession
    private let imageCache = NSCache<NSString, UIImage>()
    
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
    
    // MARK: - Generic Fetch
    func fetchData<T: Decodable>(endpoint: String, params: [String: String] = [:], type: T.Type) async throws -> T {
        guard let url = buildURL(endpoint: endpoint, params: params) else {
            throw SubsonicError.badURL
        }
        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else { throw SubsonicError.unknown }

            switch httpResponse.statusCode {
            case 200:
                do {
                    return try JSONDecoder().decode(T.self, from: data)
                } catch {
                    throw SubsonicError.decoding(underlying: error)
                }
            case 401:
                throw SubsonicError.unauthorized
            default:
                throw SubsonicError.server(statusCode: httpResponse.statusCode)
            }
        } catch {
            throw SubsonicError.network(underlying: error)
        }
    }
    // MARK: StreamURL
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
            
    /// Ping mit allen Serverinfos
    func pingWithInfo() async throws -> PingInfo {
        guard let url = URL(string: "\(baseURL)/rest/ping.view?u=\(username)&p=\(password)&f=json") else {
            throw URLError(.badURL)
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(SubsonicResponse<PingInfo>.self, from: data)
        return decoded.subsonicResponse
    }
    
    // MARK: - CoverArt Cache Helper
    func cacheImage(_ image: UIImage, key: String) {
        imageCache.setObject(image, forKey: key as NSString)
    }
    
    func cachedImage(for key: String) -> UIImage? {
        imageCache.object(forKey: key as NSString)
    }
}
