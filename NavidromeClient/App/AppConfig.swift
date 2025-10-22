//
//  AppConfig.swift
//  NavidromeClient
//
//  REFACTORED: Uses CredentialStore for all credential operations
//  CLEAN: Single responsibility - app configuration state only
//

import Foundation

@MainActor
final class AppConfig: ObservableObject {
    static let shared = AppConfig()
    
    @Published var isConfigured = false
    @Published var isInitializingServices = false
    
    private var hasInitializedServices = false
    private let credentialStore = CredentialStore()

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

    // MARK: - Initialization
    
    private init() {
        AppLogger.general.info("[AppConfig] Initializing...")
        
        let raw = UserDefaults.standard.string(forKey: "userBackgroundStyle") ?? UserBackgroundStyle.dynamic.rawValue
        self.userBackgroundStyle = UserBackgroundStyle(rawValue: raw) ?? .dynamic
        
        if let saved = UserDefaults.standard.string(forKey: "userAccentColor"),
           let color = UserAccentColor(rawValue: saved) {
            self.userAccentColor = color
        }
        
        loadCredentials()
        
        AppLogger.general.info("[AppConfig] Initialization complete, isConfigured: \(isConfigured)")
    }
        
    // MARK: - Configuration
    
    func configure(baseURL: URL, username: String, password: String) {
        AppLogger.general.info("[AppConfig] Configure called for user: \(username)")
        
        let newCredentials = ServerCredentials(
            baseURL: baseURL,
            username: username,
            password: password
        )
        
        do {
            try credentialStore.saveCredentials(newCredentials)
            AppLogger.general.info("[AppConfig] Credentials saved successfully")
        } catch {
            AppLogger.general.error("[AppConfig] Failed to save credentials: \(error)")
            return
        }
        
        self.credentials = newCredentials
        isConfigured = true
        
        AppLogger.general.info("[AppConfig] Setting isConfigured = true")
        NetworkMonitor.shared.updateConfiguration(isConfigured: true)

        AppLogger.general.info("[AppConfig] Posting servicesNeedInitialization notification")
        NotificationCenter.default.post(name: .servicesNeedInitialization, object: newCredentials)
    }
    
    // MARK: - Factory Reset (Complete App Reset)

    func performFactoryReset() async {
        AppLogger.general.info("[AppConfig] Starting factory reset")
        
        credentialStore.clearCredentials()
        
        credentials = nil
        isConfigured = false
        hasInitializedServices = false
        
        NetworkMonitor.shared.updateConfiguration(isConfigured: false)
        NetworkMonitor.shared.reset()
                
        await resetAllManagers()
        
        clearAllCaches()
        
        objectWillChange.send()
        
        AppLogger.general.info("[AppConfig] Factory reset completed")
    }
        
    // MARK: - Private Reset Methods
    
    private func resetAllManagers() async {
        NotificationCenter.default.post(name: .factoryResetRequested, object: nil)
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        AppLogger.general.info("[AppConfig] Factory reset notification posted to all managers")
    }
    
    private func clearAllCaches() {
        PersistentImageCache.shared.clearCache()
        AlbumMetadataCache.shared.clearCache()
        
        AppLogger.general.info("[AppConfig] Persistent caches cleared")
    }
    
    // MARK: - Credentials
    
    func getCredentials() -> ServerCredentials? {
        if let creds = credentials {
            AppLogger.general.info("[AppConfig] Returning credentials: \(creds.username), password length: \(creds.password.count)")
        } else {
            AppLogger.general.info("[AppConfig] No credentials available")
        }
        return credentials
    }

    private func loadCredentials() {
        AppLogger.general.info("[AppConfig] Loading credentials from CredentialStore...")
        
        guard let creds = credentialStore.loadCredentials() else {
            AppLogger.general.info("[AppConfig] No credentials found, setting isConfigured = false")
            isConfigured = false
            NetworkMonitor.shared.updateConfiguration(isConfigured: false)
            return
        }
        
        AppLogger.general.info("[AppConfig] Credentials loaded: \(creds.username), password length: \(creds.password.count)")
        
        self.credentials = creds
        isConfigured = true
        
        AppLogger.general.info("[AppConfig] Setting isConfigured = true")
        NetworkMonitor.shared.updateConfiguration(isConfigured: true)
    }
    
    func needsPassword() -> Bool {
        let needs = isConfigured && (credentials?.password.isEmpty ?? true)
        AppLogger.general.info("[AppConfig] needsPassword: \(needs)")
        return needs
    }
    
    func restorePassword(_ password: String) -> Bool {
        AppLogger.general.info("[AppConfig] Attempting to restore password...")
        
        guard let creds = credentials else {
            AppLogger.general.error("[AppConfig] Cannot restore password - no credentials")
            return false
        }
        
        guard credentialStore.verifyPassword(password) else {
            AppLogger.general.error("[AppConfig] Password verification failed")
            return false
        }
        
        self.credentials = ServerCredentials(
            baseURL: creds.baseURL,
            username: creds.username,
            password: password
        )
        
        if let sessionData = password.data(using: .utf8) {
            _ = KeychainHelper.shared.save(sessionData, forKey: "navidrome_password_session")
        }
        
        AppLogger.general.info("[AppConfig] Password restored successfully")
        return true
    }
}
