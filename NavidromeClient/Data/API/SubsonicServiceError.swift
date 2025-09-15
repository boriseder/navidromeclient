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
    case timeout(endpoint: String)  // Enhanced for timeout detection

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
        case .timeout(let endpoint):
            return "Verbindung zu Server unterbrochen."
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
                return ["album", "artist", "song", "genre", "albumList2", "artists", "genres", "searchResult2"].contains(key.stringValue)
            }
            return false
        default:
            return false
        }
    }
    
    /// Enhanced: Prüft ob es ein Offline-Error ist (inkl. Timeouts)
    var isOfflineError: Bool {
        switch self {
        case .network(let error):
            if let urlError = error as? URLError {
                return urlError.code == .notConnectedToInternet ||
                       urlError.code == .timedOut ||                    // Enhanced
                       urlError.code == .cannotConnectToHost ||
                       urlError.code == .networkConnectionLost ||      // Enhanced
                       urlError.code == .cannotFindHost                // Enhanced
            }
            return false
        case .timeout:
            return true // Enhanced: Timeout is always offline error
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
        case .timeout:
            return true // Enhanced: Timeout = Server unreachable but recoverable
        default:
            return false
        }
    }
}
