//
//  AppInitializer.swift
//  NavidromeClient
//
//  Centralized initialization orchestrator with guaranteed order.
//  Eliminates race conditions and provides clear initialization state to UI.
//
 
import Foundation

@MainActor
final class AppInitializer: ObservableObject {
    
    // MARK: - Initialization State
    
    enum InitializationState: Equatable {
        case notStarted
        case inProgress
        case completed
        case failed(String)
        
        var isFailed: Bool {
            if case .failed = self { return true }
            return false
        }
    }
    
    @Published private(set) var state: InitializationState = .notStarted
    
    // MARK: - Dependencies
    
    private let credentialStore = CredentialStore()
    private var credentials: ServerCredentials?
    
    // MARK: - Service Container
    
    private(set) var unifiedService: UnifiedSubsonicService?
    
    // MARK: - Initialization
    
    func initialize() async throws {
        guard state == .notStarted || state.isFailed else {
            AppLogger.general.info("[AppInitializer] Already initialized or in progress")
            return
        }
        
        state = .inProgress
        AppLogger.general.info("[AppInitializer] === Starting initialization ===")
        
        do {
            // Phase 1: Load credentials
            try await loadCredentials()
            
            // Phase 2: Initialize NetworkMonitor
            initializeNetworkMonitor()
            
            // Phase 3: Create UnifiedSubsonicService if configured
            if let creds = credentials {
                try createUnifiedService(with: creds)
            } else {
                AppLogger.general.info("[AppInitializer] No credentials - skipping service creation")
            }
            
            state = .completed
            AppLogger.general.info("[AppInitializer] === Initialization completed ===")
            
        } catch {
            let errorMessage = error.localizedDescription
            state = .failed(errorMessage)
            AppLogger.general.error("[AppInitializer] Initialization failed: \(errorMessage)")
            throw error
        }
    }
    
    // MARK: - Configuration of Managers
    
    func configureManagers(
        coverArtManager: CoverArtManager,
        songManager: SongManager,
        downloadManager: DownloadManager,
        favoritesManager: FavoritesManager,
        exploreManager: ExploreManager,
        musicLibraryManager: MusicLibraryManager,
        navidromeVM: NavidromeViewModel,
        playerVM: PlayerViewModel
    ) {
        guard state == .completed else {
            AppLogger.general.error("[AppInitializer] Cannot configure managers - initialization not complete")
            return
        }
        
        guard let service = unifiedService else {
            AppLogger.general.info("[AppInitializer] No service available - skipping manager configuration")
            return
        }
        
        AppLogger.general.info("[AppInitializer] Configuring managers...")
        
        // Phase 1: Independent services
        coverArtManager.configure(service: service)
        songManager.configure(service: service)
        
        // Phase 2: Services with dependencies
        downloadManager.configure(service: service)
        downloadManager.configure(coverArtManager: coverArtManager)
        favoritesManager.configure(service: service)
        exploreManager.configure(service: service)
        musicLibraryManager.configure(service: service)
        
        // Phase 3: ViewModels
        navidromeVM.updateService(service)
        playerVM.configure(service: service)
        
        AppLogger.general.info("[AppInitializer] Managers configured successfully")
        
        // Ini complete
        AppConfig.shared.setInitializingServices(false)

    }
    
    // MARK: - Initial Data Loading
    
    func loadInitialData(
        exploreManager: ExploreManager,
        favoritesManager: FavoritesManager,
        musicLibraryManager: MusicLibraryManager
    ) async {
        guard state == .completed else {
            AppLogger.general.error("[AppInitializer] Cannot load data - initialization not complete")
            return
        }
        
        guard unifiedService != nil else {
            AppLogger.general.info("[AppInitializer] No service available - skipping data load")
            return
        }
        
        AppLogger.general.info("[AppInitializer] Loading initial data...")
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await exploreManager.loadExploreData()
            }
            
            group.addTask {
                await favoritesManager.loadFavoriteSongs()
            }
            
            group.addTask {
                await musicLibraryManager.loadInitialDataIfNeeded()
            }
        }
        
        AppLogger.general.info("[AppInitializer] Initial data loaded")
    }
    
    // MARK: - Reset
    
    func reset() {
        AppLogger.general.info("[AppInitializer] Resetting...")
        
        credentials = nil
        unifiedService = nil
        state = .notStarted
        
        // Clear NetworkMonitor service reference
        NetworkMonitor.shared.configureService(nil)

        AppLogger.general.info("[AppInitializer] Reset complete")
    }
    
    // MARK: - Re-initialization after configuration
    
    func reinitializeAfterConfiguration() async throws {
        AppLogger.general.info("[AppInitializer] Re-initializing after configuration...")
        
        state = .notStarted
        try await initialize()
    }
    
    // MARK: - Private Helpers
    
    private func loadCredentials() async throws {
        AppLogger.general.info("[AppInitializer] Phase 1: Loading credentials...")
        
        credentials = credentialStore.loadCredentials()
        
        if let creds = credentials {
            AppLogger.general.info("[AppInitializer] Credentials loaded for: \(creds.username)")
        } else {
            AppLogger.general.info("[AppInitializer] No stored credentials")
        }
    }
    
    private func initializeNetworkMonitor() {
        AppLogger.general.info("[AppInitializer] Phase 2: Initializing NetworkMonitor...")
        
        let isConfigured = credentials != nil
        NetworkMonitor.shared.initialize(isConfigured: isConfigured)
        
        AppLogger.general.info("[AppInitializer] NetworkMonitor initialized (configured: \(isConfigured))")
    }
    
    private func createUnifiedService(with credentials: ServerCredentials) throws {
        AppLogger.general.info("[AppInitializer] Phase 3: Creating UnifiedSubsonicService...")
        
        unifiedService = UnifiedSubsonicService(
            baseURL: credentials.baseURL,
            username: credentials.username,
            password: credentials.password
        )
        
        // Configure NetworkMonitor with service reference
        NetworkMonitor.shared.configureService(unifiedService)
        
        AppLogger.general.info("[AppInitializer] UnifiedSubsonicService created successfully")
    }
    
    // MARK: - Query Methods
    
    func hasCredentials() -> Bool {
        return credentials != nil
    }
    
    func getCredentials() -> ServerCredentials? {
        return credentials
    }
}
