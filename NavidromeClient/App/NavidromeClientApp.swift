import SwiftUI

@main
struct NavidromeClientApp: App {
    @StateObject private var appInitializer = AppInitializer()
    @StateObject private var appConfig = AppConfig.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    @StateObject private var musicLibraryManager = MusicLibraryManager()
    @StateObject private var navidromeVM: NavidromeViewModel
    @StateObject private var playerVM: PlayerViewModel
    @StateObject private var coverArtManager = CoverArtManager()
    @StateObject private var cacheWarmer: CoverArtCacheWarmer
    @StateObject private var songManager = SongManager()
    @StateObject private var exploreManager = ExploreManager()
    @StateObject private var favoritesManager = FavoritesManager()
    @StateObject private var downloadManager = DownloadManager.shared
    @StateObject private var audioSessionManager = AudioSessionManager.shared
    @StateObject private var offlineManager = OfflineManager.shared
    @StateObject private var theme = ThemeManager()
    
    init() {
        let musicLib = MusicLibraryManager()
        let navidromeViewModel = NavidromeViewModel(musicLibraryManager: musicLib)
        let coverArt = CoverArtManager()
        let player = PlayerViewModel(coverArtManager: coverArt)
        
        _musicLibraryManager = StateObject(wrappedValue: musicLib)
        _navidromeVM = StateObject(wrappedValue: navidromeViewModel)
        _coverArtManager = StateObject(wrappedValue: coverArt)
        _cacheWarmer = StateObject(wrappedValue: CoverArtCacheWarmer(coverArtManager: coverArt))

        _playerVM = StateObject(wrappedValue: player)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch appInitializer.state {
                case .notStarted, .inProgress:
                    InitializationView(initializer: appInitializer)
                    
                case .completed:
                    ContentView()
                        .environmentObject(appConfig)
                        .environmentObject(navidromeVM)
                        .environmentObject(playerVM)
                        .environmentObject(musicLibraryManager)
                        .environmentObject(coverArtManager)
                        .environmentObject(songManager)
                        .environmentObject(exploreManager)
                        .environmentObject(favoritesManager)
                        .environmentObject(downloadManager)
                        .environmentObject(audioSessionManager)
                        .environmentObject(networkMonitor)
                        .environmentObject(offlineManager)
                        .environmentObject(theme)
                        .preferredColorScheme(theme.colorScheme)
                    
                case .failed(let error):
                    InitializationErrorView(error: error) {
                        Task {
                            try? await appInitializer.initialize()
                        }
                    }
                }
            }
            .task {
                await performInitialization()
            }
            .onAppear {
                configureInitialDependencies()
            }
            .onChange(of: appConfig.isConfigured) { _, isConfigured in
                if isConfigured {
                    Task {
                        try? await appInitializer.reinitializeAfterConfiguration()
                        if appInitializer.state == .completed {
                            configureManagersAndLoadData()
                        }
                    }
                }
            }
            .onChange(of: networkMonitor.canLoadOnlineContent) { _, isConnected in
                Task {
                    await handleNetworkChange(isConnected: isConnected)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                handleAppBecameActive()
            }
            .onReceive(NotificationCenter.default.publisher(for: .factoryResetRequested)) { _ in
                Task {
                    await handleFactoryReset()
                }
            }
        }
    }
    
    // MARK: - Initialization
    
    private func performInitialization() async {
        do {
            try await appInitializer.initialize()
            if appInitializer.state == .completed && appInitializer.hasCredentials() {
                configureManagersAndLoadData()
            }
        } catch {
            AppLogger.general.error("[App] Initialization failed: \(error)")
        }
    }
    
    private func configureManagersAndLoadData() {
        appInitializer.configureManagers(
            coverArtManager: coverArtManager,
            songManager: songManager,
            downloadManager: downloadManager,
            favoritesManager: favoritesManager,
            exploreManager: exploreManager,
            musicLibraryManager: musicLibraryManager,
            navidromeVM: navidromeVM,
            playerVM: playerVM
        )
        
        Task {
            await appInitializer.loadInitialData(
                exploreManager: exploreManager,
                favoritesManager: favoritesManager,
                musicLibraryManager: musicLibraryManager
            )
        }
    }
    
    private func configureInitialDependencies() {
        audioSessionManager.playerViewModel = playerVM
    }
    
    // MARK: - Network Handling
    
    private func handleNetworkChange(isConnected: Bool) async {
        guard appInitializer.state == .completed else {
            AppLogger.general.info("[App] Network change ignored - not initialized")
            return
        }
        
        await navidromeVM.handleNetworkChange(isOnline: isConnected)
        AppLogger.general.info("[App] Network state changed: \(isConnected ? "Connected" : "Disconnected")")
    }
    
    private func handleAppBecameActive() {
        guard appInitializer.state == .completed else {
            AppLogger.general.info("[App] App activation ignored - not initialized")
            return
        }
        
        Task { @MainActor in
            await handleAppActivation()
        }
    }

    private func handleAppActivation() async {
        AppLogger.general.info("[App] App becoming active - starting parallel activation")
        
        let startTime = Date()
        
        // Run all activation tasks in parallel
        await withTaskGroup(of: Void.self) { group in
            // Audio session reactivation
            group.addTask {
                await self.audioSessionManager.handleAppBecameActive()
            }
            
            // Network state recheck
            group.addTask {
                await self.networkMonitor.recheckConnection()
            }
            
            // Connection health check (only if data is not fresh)
            group.addTask {
                if await !self.navidromeVM.isDataFresh {
                    await self.navidromeVM.handleNetworkChange(
                        isOnline: self.networkMonitor.canLoadOnlineContent
                    )
                }
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        AppLogger.general.info("[App] App activation completed in \(String(format: "%.2f", duration))s")
    }
    private func handleFactoryReset() async {
        appInitializer.reset()
        AppLogger.general.info("[App] Reset AppInitializer state")
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
            AppLogger.general.info("ServiceContainer: Cleared services on factory reset")
        }
    }
    
    func initializeServices(with credentials: ServerCredentials?) {
        guard let credentials = credentials else {
            unifiedService = nil
            isInitialized = false
            initializationError = "No credentials provided"
            return
        }
        
        unifiedService = UnifiedSubsonicService(
            baseURL: credentials.baseURL,
            username: credentials.username,
            password: credentials.password
        )
        isInitialized = true
        initializationError = nil
    }
    
    func clearServices() {
        unifiedService = nil
        isInitialized = false
        initializationError = nil
    }
}
