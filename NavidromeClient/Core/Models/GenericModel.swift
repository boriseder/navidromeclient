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

// Füge am Ende von GenericModel.swift hinzu:

// MARK: - Error Response
struct SubsonicErrorDetail: Codable {
    let code: Int
    let message: String
}

// MARK: - Response Content mit Error Support
struct SubsonicResponseContent: Codable {
    let status: String
    let version: String?
    let error: SubsonicErrorDetail?
}

// MARK: - Empty Response DTO (für Ping)
struct EmptyResponse: Codable {}
