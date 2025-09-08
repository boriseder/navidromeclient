import Foundation

final class AppConfig: ObservableObject {
    static let shared = AppConfig()
    
    @Published var isConfigured = false
    private var credentials: ServerCredentials?
    
    private init() {
        loadCredentials()
    }
    
    func configure(baseURL: URL, username: String, password: String) {
        // 1. BaseURL + Username speichern
        let credsWithoutPassword = ServerCredentials(
            baseURL: baseURL,
            username: username,
            password: "" // Passwort kommt separat
        )
        
        if let data = try? JSONEncoder().encode(credsWithoutPassword) {
            _ = KeychainHelper.shared.save(data, forKey: "navidrome_credentials")
        }
        
        // 2. Passwort separat speichern
        if let passwordData = password.data(using: .utf8) {
            _ = KeychainHelper.shared.save(passwordData, forKey: "navidrome_password")
        }
        
        // 3. Im Speicher zusammensetzen
        self.credentials = ServerCredentials(baseURL: baseURL, username: username, password: password)
        isConfigured = true
    }
    
    func getCredentials() -> ServerCredentials? {
        return credentials
    }
    
    private func loadCredentials() {
        // BaseURL + Username laden
        guard let data = KeychainHelper.shared.load(forKey: "navidrome_credentials"),
              var creds = try? JSONDecoder().decode(ServerCredentials.self, from: data) else {
            isConfigured = false
            return
        }
        
        // Passwort separat laden
        if let pwdData = KeychainHelper.shared.load(forKey: "navidrome_password"),
           let password = String(data: pwdData, encoding: .utf8) {
            creds = ServerCredentials(baseURL: creds.baseURL, username: creds.username, password: password)
        } else {
            isConfigured = false
            return
        }
        
        self.credentials = creds
        isConfigured = true
    }
    
    func logout() {
        _ = KeychainHelper.shared.delete(forKey: "navidrome_credentials")
        _ = KeychainHelper.shared.delete(forKey: "navidrome_password")
        credentials = nil
        isConfigured = false
    }
}
