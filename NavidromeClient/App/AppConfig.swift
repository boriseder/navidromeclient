//
//  AppConfig.swift - Refactored with Factory Reset
//  NavidromeClient
//

import Foundation
import CryptoKit

@MainActor
final class AppConfig: ObservableObject {
    static let shared = AppConfig()
    
    @Published var isConfigured = false  // ADD THIS LINE
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
            // Speichert die Auswahl direkt in UserDefaults
            UserDefaults.standard.set(userBackgroundStyle.rawValue, forKey: "userBackgroundStyle")
        }
    }
        @Published var userAccentColor: UserAccentColor = .blue {
        didSet {
            UserDefaults.standard.set(userAccentColor.rawValue, forKey: "userAccentColor")
        }
    }
    
    private var credentials: ServerCredentials?

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


    func getCredentials() -> ServerCredentials? {
        return credentials
    }
    
    // MARK: -  NEW: Factory Reset (Complete App Reset)
    func performFactoryReset() async {
        print("🔄 Starting factory reset...")
        
        // 1. Stop any current playback immediately
        if let playerVM = getPlayerViewModel() {
            playerVM.stop()
        }
        
        // 2. Clear all keychain data
        _ = KeychainHelper.shared.delete(forKey: "navidrome_credentials")
        _ = KeychainHelper.shared.delete(forKey: "navidrome_password_hash")
        _ = KeychainHelper.shared.delete(forKey: "navidrome_password_session")
        
        // 3. Reset local state
        credentials = nil
        isConfigured = false
                
        // 5. Reset all managers and clear data
        await resetAllManagers()
        
        // 6. Clear all caches
        clearAllCaches()
        
        // 7. Force UI updates
        objectWillChange.send()
        
        print(" Factory reset completed")
    }
    
    // MARK: -  DEPRECATED: Simple logout (keep for backward compatibility)
    func logout() {
        Task {
            await performFactoryReset()
        }
    }
    
    // MARK: - Private Reset Methods
    
    private func resetAllManagers() async {
        // Reset DownloadManager
        DownloadManager.shared.deleteAllDownloads()
        
        // Reset OfflineManager
        OfflineManager.shared.performCompleteReset()
        
        // Reset ViewModels if accessible
        if let navidromeVM = getNavidromeViewModel() {
            navidromeVM.reset()
        }
        
        // Force manager updates
        DownloadManager.shared.objectWillChange.send()
        OfflineManager.shared.objectWillChange.send()
    }
    
    private func clearAllCaches() {
        // Clear image caches
        PersistentImageCache.shared.clearCache()
        
        // Clear cover art service
        CoverArtManager.shared.clearMemoryCache()
        
        // Clear album metadata cache
        // Note: This would need to be implemented in AlbumMetadataCache
        // AlbumMetadataCache.shared.clearCache()
    }
    
    // MARK: - Helper Methods to Access ViewModels
    
    private func getPlayerViewModel() -> PlayerViewModel? {
        // In a real app, you'd inject these dependencies or use a service locator
        // For now, we'll rely on the managers being singletons
        return nil // PlayerViewModel is not a singleton in current architecture
    }
    
    private func getNavidromeViewModel() -> NavidromeViewModel? {
        // Similar issue - NavidromeViewModel is not globally accessible
        return nil
    }
    
    // MARK: - Existing Methods (unchanged)
    
    private func loadCredentials() {
        // Load BaseURL + Username
        guard let data = KeychainHelper.shared.load(forKey: "navidrome_credentials"),
              let creds = try? JSONDecoder().decode(ServerCredentials.self, from: data) else {
            isConfigured = false
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
        
        // Update NetworkMonitor
        if !sessionPassword.isEmpty {
            let service = SubsonicService(
                baseURL: creds.baseURL,
                username: creds.username,
                password: sessionPassword
            )
        }
        
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
            
            // Update NetworkMonitor
            let service = SubsonicService(
                baseURL: creds.baseURL,
                username: creds.username,
                password: password
            )
            
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
