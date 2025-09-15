import Foundation

// MARK: - Generic Subsonic Response Wrapper
struct SubsonicResponse<T: Codable>: Codable {
    let subsonicResponse: T
    
    private enum CodingKeys: String, CodingKey {
        case subsonicResponse = "subsonic-response"
    }
}

struct PingInfo: Codable {
    let status: String
    let version: String
    let type: String
    let serverVersion: String
    let openSubsonic: Bool
}

// MARK: - Empty Response DTO (für Ping)
struct EmptyResponse: Codable {}
