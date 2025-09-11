import Foundation

enum SubsonicError: Error, LocalizedError {
    case badURL
    case network(underlying: Error)
    case server(statusCode: Int)
    case decoding(underlying: Error)
    case unauthorized
    case unknown
    case emptyResponse(endpoint: String)
    case rateLimited
    case invalidInput(parameter: String)

    var errorDescription: String? {
        switch self {
        case .badURL:
            return "Ungültige URL."
        case .network(let err):
            return "Netzwerkfehler: \(err.localizedDescription)"
        case .server(let code):
            return "Server antwortete mit Status \(code)."
        case .decoding(let err):
            return "Fehler beim Verarbeiten der Daten: \(err.localizedDescription)"
        case .unauthorized:
            return "Benutzername oder Passwort ist falsch."
        case .emptyResponse(let endpoint):
            return "Keine Daten für \(endpoint) verfügbar."
        case .rateLimited:
            return "Zu viele Anfragen. Bitte warten Sie einen Moment."
        case .invalidInput(let parameter):
            return "Ungültige Eingabe für Parameter: \(parameter)"
        case .unknown:
            return "Unbekannter Fehler."
        }
    }
    
    /// Prüft ob es sich um einen "leeren Response" Fehler handelt
    var isEmptyResponse: Bool {
        switch self {
        case .emptyResponse:
            return true
        case .decoding(let underlying):
            // Prüfe ob es ein keyNotFound für wichtige Keys ist
            if case DecodingError.keyNotFound(let key, _) = underlying {
                return ["album", "artist", "song", "genre"].contains(key.stringValue)
            }
            return false
        default:
            return false
        }
    }
    
    /// Prüft ob der Fehler als "harmlos" betrachtet werden kann (für UI)
    var isRecoverable: Bool {
        switch self {
        case .emptyResponse, .decoding:
            return true
        case .network:
            return true // Netzwerkfehler sind oft temporär
        case .rateLimited:
            return true // Rate limiting ist temporär
        default:
            return false
        }
    }
}
