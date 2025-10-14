import SwiftUI

@main
struct NavidromeClientApp: App {
    @StateObject private var serviceContainer = ServiceContainer()
    @StateObject private var musicLibraryManager: MusicLibraryManager
    @StateObject private var navidromeVM: NavidromeViewModel
    @StateObject private var songManager = SongManager()
    @StateObject private var coverArtManager: CoverArtManager
    @StateObject private var playerVM: PlayerViewModel
    @StateObject private var exploreManager = ExploreManager()
    @StateObject private var favoritesManager = FavoritesManager()
    
    // Singletons that MUST remain singletons
    @StateObject private var appConfig = AppConfig.shared
    @StateObject private var downloadManager = DownloadManager.shared
    @StateObject private var audioSessionManager = AudioSessionManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var offlineManager = OfflineManager.shared
    
    init() {
        let musicLib = MusicLibraryManager()
        let navidromeViewModel = NavidromeViewModel(musicLibraryManager: musicLib)
        let coverArt = CoverArtManager()
        let player = PlayerViewModel(coverArtManager: coverArt)
        
        _musicLibraryManager = StateObject(wrappedValue: musicLib)
        _navidromeVM = StateObject(wrappedValue: navidromeViewModel)
        _coverArtManager = StateObject(wrappedValue: coverArt)
        _playerVM = StateObject(wrappedValue: player)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(serviceContainer)
                .environmentObject(appConfig)
                .environmentObject(navidromeVM)
                .environmentObject(songManager)
                .environmentObject(playerVM)
                .environmentObject(downloadManager)
                .environmentObject(audioSessionManager)
                .environmentObject(networkMonitor)
                .environmentObject(offlineManager)
                .environmentObject(coverArtManager)
                .environmentObject(exploreManager)
                .environmentObject(musicLibraryManager)
                .environmentObject(favoritesManager)
                .tint(appConfig.userAccentColor.color)
                .task {
                    await setupServicesAfterAppLaunch()
                }
                .onAppear {
                    configureInitialDependencies()
                }
                .onChange(of: networkMonitor.canLoadOnlineContent) { _, isConnected in
                    Task {
                        await handleNetworkChange(isConnected: isConnected)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    handleAppBecameActive()
                }
                .onReceive(NotificationCenter.default.publisher(for: .servicesNeedInitialization)) { notification in
                    if let credentials = notification.object as? ServerCredentials {
                        Task {
                            await initializeServices(with: credentials)
                        }
                    }
                }
        }
    }
    
    // MARK: - UNIFIED Service Initialization
    
    private func setupServicesAfterAppLaunch() async {
        // Access the wrapped value directly
        guard AppConfig.shared.isConfigured else {
            print("App not configured - waiting for login")
            return
        }
        
        guard let credentials = AppConfig.shared.getCredentials() else {
            print("No credentials available")
            return
        }
        
        print("App launch: Initializing services with saved credentials")
        await initializeServices(with: credentials)
    }
    private func initializeServices(with credentials: ServerCredentials) async {
        print("=== Starting Service Initialization ===")
        
        await MainActor.run {
            appConfig.setInitializingServices(true)
        }
        
        // Create unified service ONCE and store in container
        await serviceContainer.initializeServices(with: credentials)
        
        // Get the service from container
        guard let unifiedService = serviceContainer.unifiedService else {
            let errorMsg = serviceContainer.initializationError ?? "Unknown initialization error"
            print("❌ Failed to create UnifiedSubsonicService: \(errorMsg)")
            await MainActor.run {
                appConfig.setInitializingServices(false)
            }
            return
        }
        
        print("✅ UnifiedSubsonicService created successfully")
        
        // Configure all managers in dependency order
        await MainActor.run {
            print("Configuring services...")
            
            // Phase 1: Independent services
            coverArtManager.configure(service: unifiedService)
            songManager.configure(service: unifiedService)
            
            // Phase 2: Services with dependencies
            downloadManager.configure(service: unifiedService)
            downloadManager.configure(coverArtManager: coverArtManager)
            favoritesManager.configure(service: unifiedService)
            exploreManager.configure(service: unifiedService)
            musicLibraryManager.configure(service: unifiedService)
            
            // Phase 3: ViewModels
            navidromeVM.updateService(unifiedService)
            playerVM.configure(service: unifiedService)
            
            print("Services configured")
        }
        
        // Load initial data for all views
        await loadInitialDataForAllViews()
        
        // Mark initialization complete
        await MainActor.run {
            appConfig.setInitializingServices(false)
            print("=== Service Initialization Complete ===")
        }
    }
    
    private func loadInitialDataForAllViews() async {
        print("Loading initial data...")
        
        await withTaskGroup(of: Void.self) { group in

            group.addTask {
                await self.exploreManager.loadExploreData()
            }
            
            group.addTask {
                await self.favoritesManager.loadFavoriteSongs()
            }

            group.addTask {
                await self.musicLibraryManager.loadInitialDataIfNeeded()
            }
        }
        
        print("Initial data loaded")
    }
    
    // MARK: - Initial Configuration
    
    private func configureInitialDependencies() {
        audioSessionManager.playerViewModel = playerVM
    }
    
    // MARK: - Network Handling
    
    private func handleNetworkChange(isConnected: Bool) async {
        // Guard: Don't handle network changes until services are initialized
        guard serviceContainer.isInitialized else {
            print("⏸️ Network change ignored - services not initialized")
            return
        }
        
        await navidromeVM.handleNetworkChange(isOnline: isConnected)
        print("Network state changed: \(isConnected ? "Connected" : "Disconnected")")
    }
    
    private func handleAppBecameActive() {
        // Guard: Don't handle app activation until services are initialized
        guard serviceContainer.isInitialized else {
            print("⏸️ App activation ignored - services not initialized")
            return
        }
        
        Task {
            if !navidromeVM.isDataFresh {
                await navidromeVM.handleNetworkChange(isOnline: networkMonitor.canLoadOnlineContent)
            }
        }
        print("App became active")
    }
}

// MARK: - Service Container

@MainActor
class ServiceContainer: ObservableObject {
    @Published private(set) var unifiedService: UnifiedSubsonicService?
    @Published private(set) var isInitialized = false
    @Published private(set) var initializationError: String?
    
    init() {
        setupFactoryResetObserver()
    }
    
    private func setupFactoryResetObserver() {
        NotificationCenter.default.addObserver(
            forName: .factoryResetRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearServices()
            print("ServiceContainer: Cleared services on factory reset")
        }
    }
    
    func initializeServices(with credentials: ServerCredentials?) async {
        guard let credentials = credentials else {
            unifiedService = nil
            isInitialized = false
            initializationError = "No credentials provided"
            return
        }
        
        do {
            unifiedService = UnifiedSubsonicService(
                baseURL: credentials.baseURL,
                username: credentials.username,
                password: credentials.password
            )
            isInitialized = true
            initializationError = nil
        } catch {
            unifiedService = nil
            isInitialized = false
            initializationError = "Failed to initialize service: \(error.localizedDescription)"
        }
    }
    
    func clearServices() {
        unifiedService = nil
        isInitialized = false
        initializationError = nil
    }
}
