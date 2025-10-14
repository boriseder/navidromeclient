import Foundation
import CryptoKit

@MainActor
final class AppConfig: ObservableObject {
    static let shared = AppConfig()
    
    @Published var isConfigured = false
    @Published var isInitializingServices = false
    
    private var hasInitializedServices = false

    var areServicesReady: Bool {
        return isConfigured && !isInitializingServices && hasInitializedServices
    }

    func setInitializingServices(_ isInitializing: Bool) {
        isInitializingServices = isInitializing
        if !isInitializing {
            hasInitializedServices = true
        }
    }

    @Published var userBackgroundStyle: UserBackgroundStyle {
        didSet {
            UserDefaults.standard.set(userBackgroundStyle.rawValue, forKey: "userBackgroundStyle")
        }
    }

    @Published var userAccentColor: UserAccentColor = .blue {
        didSet {
            UserDefaults.standard.set(userAccentColor.rawValue, forKey: "userAccentColor")
        }
    }
    
    private var credentials: ServerCredentials?

    // MARK: Initialization
    
    private init() {
        // Stored property initialisieren
        let raw = UserDefaults.standard.string(forKey: "userBackgroundStyle") ?? UserBackgroundStyle.dynamic.rawValue
        self.userBackgroundStyle = UserBackgroundStyle(rawValue: raw) ?? .dynamic
        if let saved = UserDefaults.standard.string(forKey: "userAccentColor"),
           let color = UserAccentColor(rawValue: saved) {
        self.userAccentColor = color
        }
        
        loadCredentials()
    }
        
    // MARK: - Configuration
    
    func configure(baseURL: URL, username: String, password: String) {
        guard validateCredentials(baseURL: baseURL, username: username, password: password) else {
            print("❌ Invalid credentials provided")
            return
        }
        
        // Store BaseURL + Username
        let credsWithoutPassword = ServerCredentials(baseURL: baseURL, username: username, password: "")
        if let data = try? JSONEncoder().encode(credsWithoutPassword) {
            _ = KeychainHelper.shared.save(data, forKey: "navidrome_credentials")
        }
        
        // Store password hash
        let hashedPassword = hashPassword(password)
        if let passwordData = hashedPassword.data(using: .utf8) {
            _ = KeychainHelper.shared.save(passwordData, forKey: "navidrome_password_hash")
        }
        
        // Store password for session
        _ = KeychainHelper.shared.save(password.data(using: .utf8)!, forKey: "navidrome_password_session")
        
        // Set credentials for current session
        let fullCredentials = ServerCredentials(baseURL: baseURL, username: username, password: password)
        self.credentials = fullCredentials
        isConfigured = true
        
        NetworkMonitor.shared.updateConfiguration(isConfigured: true)

        // Trigger service initialization via notification
        NotificationCenter.default.post(name: .servicesNeedInitialization, object: fullCredentials)
    }
    
    // MARK: -  Factory Reset (Complete App Reset)

    func performFactoryReset() async {
        print("Starting factory reset")
        
        // 1. Clear all keychain data
        _ = KeychainHelper.shared.delete(forKey: "navidrome_credentials")
        _ = KeychainHelper.shared.delete(forKey: "navidrome_password_hash")
        _ = KeychainHelper.shared.delete(forKey: "navidrome_password_session")
        
        // 2. Reset local state
        credentials = nil
        isConfigured = false
                
        // 3. Reset all managers and clear data
        await resetAllManagers()
        
        // 4. Clear all caches
        clearAllCaches()
        
        // 5. Force UI updates
        objectWillChange.send()
        
        print("Factory reset completed")
    }
        
    // MARK: - Private Reset Methods
    
    private func resetAllManagers() async {
        // Notify all managers to reset themselves
        // This decouples AppConfig from manager instances
        NotificationCenter.default.post(name: .factoryResetRequested, object: nil)
        
        // Give managers time to process reset
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        print("Factory reset notification posted to all managers")
    }
    
    private func clearAllCaches() {
        // Clear persistent image cache
        PersistentImageCache.shared.clearCache()
        
        // Clear album metadata cache
        AlbumMetadataCache.shared.clearCache()
        
        print("Persistent caches cleared")
    }
    
    // MARK: - Credentials
    
    func getCredentials() -> ServerCredentials? {
        return credentials
    }

    private func loadCredentials() {
        // Load BaseURL + Username
        guard let data = KeychainHelper.shared.load(forKey: "navidrome_credentials"),
              let creds = try? JSONDecoder().decode(ServerCredentials.self, from: data) else {
            isConfigured = false
            
            // Notify NetworkMonitor of "not configured" state
            Task { @MainActor in
                NetworkMonitor.shared.updateConfiguration(isConfigured: false)
            }
            return
        }

        
        // Load session password
        var sessionPassword = ""
        if let pwdData = KeychainHelper.shared.load(forKey: "navidrome_password_session"),
           let pwd = String(data: pwdData, encoding: .utf8) {
            sessionPassword = pwd
        }
        
        // Set credentials for app session
        self.credentials = ServerCredentials(
            baseURL: creds.baseURL,
            username: creds.username,
            password: sessionPassword
        )
        
        isConfigured = true
        
        // Add this at the very end:
        Task { @MainActor in
            NetworkMonitor.shared.updateConfiguration(isConfigured: true)
        }
    }
    
    func needsPassword() -> Bool {
        return isConfigured && (credentials?.password.isEmpty ?? true)
    }
    
    func restorePassword(_ password: String) -> Bool {
        guard let creds = credentials else { return false }
        
        // Verify password hash
        if let hashData = KeychainHelper.shared.load(forKey: "navidrome_password_hash"),
           let storedHash = String(data: hashData, encoding: .utf8) {
            
            let inputHash = hashPassword(password)
            guard inputHash == storedHash else {
                print("❌ Password verification failed")
                return false
            }
            
            // Set password for session
            self.credentials = ServerCredentials(
                baseURL: creds.baseURL,
                username: creds.username,
                password: password
            )
            
            // Store password in keychain for session
            _ = KeychainHelper.shared.save(password.data(using: .utf8)!, forKey: "navidrome_password_session")
            
            return true
        }
        
        return false
    }
    
    // MARK: - Private Helper Methods
    
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
