import Foundation
import CryptoKit

@MainActor
final class AppConfig: ObservableObject {
    static let shared = AppConfig()
    
    @Published var isConfigured = false
    private var credentials: ServerCredentials?
    
    private init() {
        loadCredentials()
    }
    
    // MARK: - FIX: Enhanced configure method with NetworkMonitor integration
    func configure(baseURL: URL, username: String, password: String) {
        guard validateCredentials(baseURL: baseURL, username: username, password: password) else {
            print("❌ Invalid credentials provided")
            return
        }
        
        // Speichere BaseURL + Username
        let credsWithoutPassword = ServerCredentials(baseURL: baseURL, username: username, password: "")
        if let data = try? JSONEncoder().encode(credsWithoutPassword) {
            _ = KeychainHelper.shared.save(data, forKey: "navidrome_credentials")
        }
        
        // Passwort-Hash speichern
        let hashedPassword = hashPassword(password)
        if let passwordData = hashedPassword.data(using: .utf8) {
            _ = KeychainHelper.shared.save(passwordData, forKey: "navidrome_password_hash")
        }
        
        // Passwort zusätzlich sicher für die Session speichern
        _ = KeychainHelper.shared.save(password.data(using: .utf8)!, forKey: "navidrome_password_session")
        
        // Credentials für die aktuelle Session
        self.credentials = ServerCredentials(baseURL: baseURL, username: username, password: password)
        isConfigured = true
        
        // FIX: Create service and set it in NetworkMonitor (now MainActor-isolated)
        let service = SubsonicService(baseURL: baseURL, username: username, password: password)
        NetworkMonitor.shared.setService(service)
        print("✅ Credentials configured and NetworkMonitor updated")
    }
    
    func getCredentials() -> ServerCredentials? {
        return credentials
    }
    
    // MARK: - Credentials laden
    private func loadCredentials() {
        // BaseURL + Username laden
        guard let data = KeychainHelper.shared.load(forKey: "navidrome_credentials"),
              let creds = try? JSONDecoder().decode(ServerCredentials.self, from: data) else {
            isConfigured = false
            return
        }
        
        // Session-Passwort laden
        var sessionPassword = ""
        if let pwdData = KeychainHelper.shared.load(forKey: "navidrome_password_session"),
           let pwd = String(data: pwdData, encoding: .utf8) {
            sessionPassword = pwd
        }
        
        // Credentials für die App-Session setzen
        self.credentials = ServerCredentials(
            baseURL: creds.baseURL,
            username: creds.username,
            password: sessionPassword
        )
        
        // FIX: Set service in NetworkMonitor when loading existing credentials (now MainActor-isolated)
        if !sessionPassword.isEmpty {
            let service = SubsonicService(
                baseURL: creds.baseURL,
                username: creds.username,
                password: sessionPassword
            )
            NetworkMonitor.shared.setService(service)
            print("✅ NetworkMonitor updated with loaded credentials")
        }
        
        isConfigured = true
    }
    
    // MARK: - Prüfen ob Passwort benötigt wird
    func needsPassword() -> Bool {
        // Passwort wird nur dann gebraucht, wenn leer
        return isConfigured && (credentials?.password.isEmpty ?? true)
    }
    
    // MARK: - Passwort verifizieren
    func restorePassword(_ password: String) -> Bool {
        guard let creds = credentials else { return false }
        
        // Verifiziere Passwort-Hash
        if let hashData = KeychainHelper.shared.load(forKey: "navidrome_password_hash"),
           let storedHash = String(data: hashData, encoding: .utf8) {
            
            let inputHash = hashPassword(password)
            guard inputHash == storedHash else {
                print("❌ Password verification failed")
                return false
            }
            
            // Passwort für die Session setzen
            self.credentials = ServerCredentials(
                baseURL: creds.baseURL,
                username: creds.username,
                password: password
            )
            
            // Passwort zusätzlich in Keychain für Session speichern
            _ = KeychainHelper.shared.save(password.data(using: .utf8)!, forKey: "navidrome_password_session")
            
            // FIX: Update NetworkMonitor with restored password (now MainActor-isolated)
            let service = SubsonicService(
                baseURL: creds.baseURL,
                username: creds.username,
                password: password
            )
            NetworkMonitor.shared.setService(service)
            print("✅ NetworkMonitor updated with restored password")
            
            return true
        }
        
        return false
    }
    
    // MARK: - Logout
    func logout() {
        _ = KeychainHelper.shared.delete(forKey: "navidrome_credentials")
        _ = KeychainHelper.shared.delete(forKey: "navidrome_password_hash")
        _ = KeychainHelper.shared.delete(forKey: "navidrome_password_session")
        
        credentials = nil
        isConfigured = false
        
        // FIX: Clear service from NetworkMonitor on logout (now MainActor-isolated)
        NetworkMonitor.shared.setService(nil)
        print("✅ NetworkMonitor cleared on logout")
    }
    
    // MARK: - Private Hilfsmethoden
    private func hashPassword(_ password: String) -> String {
        let inputData = Data(password.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func validateCredentials(baseURL: URL, username: String, password: String) -> Bool {
        guard let scheme = baseURL.scheme, ["http", "https"].contains(scheme),
              let host = baseURL.host, !host.isEmpty else {
            print("❌ Invalid server URL")
            return false
        }
        guard !username.trimmingCharacters(in: .whitespaces).isEmpty,
              username.count >= 2, username.count <= 50 else {
            print("❌ Invalid username")
            return false
        }
        guard !password.isEmpty, password.count >= 4, password.count <= 100 else {
            print("❌ Invalid password")
            return false
        }
        return true
    }
}
