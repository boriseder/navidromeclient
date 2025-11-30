import SwiftUI
import BackgroundTasks

@main
struct NavidromeClientApp: App {
    // MARK: - State Objects
    @StateObject private var appInitializer = AppInitializer()
    @StateObject private var appConfig = AppConfig.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    @StateObject private var musicLibraryManager = MusicLibraryManager()
    @StateObject private var navidromeVM: NavidromeViewModel
    @StateObject private var playerVM: PlayerViewModel
    @StateObject private var coverArtManager = CoverArtManager()
    @StateObject private var songManager = SongManager()
    @StateObject private var exploreManager = ExploreManager()
    @StateObject private var favoritesManager = FavoritesManager()
    @StateObject private var downloadManager = DownloadManager.shared
    @StateObject private var audioSessionManager = AudioSessionManager.shared
    @StateObject private var offlineManager = OfflineManager.shared
    @StateObject private var theme = ThemeManager()
    
    // MARK: - Local State
    @State private var hasPerformedInitialConfiguration = false  // ✅ Use @State
    @State private var hasConfiguredManagers = false  // ✅ Use @State
    
    // MARK: - Scene Phase
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // Initialize dependencies
        let musicLib = MusicLibraryManager()
        let navidromeViewModel = NavidromeViewModel(musicLibraryManager: musicLib)
        let coverArt = CoverArtManager()
        let player = PlayerViewModel(coverArtManager: coverArt)
        
        _musicLibraryManager = StateObject(wrappedValue: musicLib)
        _navidromeVM = StateObject(wrappedValue: navidromeViewModel)
        _coverArtManager = StateObject(wrappedValue: coverArt)
        _playerVM = StateObject(wrappedValue: player)
        
        AppLogger.general.info("[App] Initialized with SwiftUI lifecycle")
    }

    var body: some Scene {
        WindowGroup {
            contentRoot
                .task {
                    await performInitialization()
                    configureInitialDependencies()
                }
                .onChange(of: appInitializer.isConfigured) { _, isConfigured in
                    handleConfigurationChange(isConfigured)
                }
                .onChange(of: networkMonitor.canLoadOnlineContent) { _, isConnected in
                    Task {
                        await handleNetworkChange(isConnected: isConnected)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .factoryResetRequested)) { _ in
                    Task {
                        await handleFactoryReset()
                    }
                }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
        .backgroundTask(.appRefresh("com.navidrome.client.refresh")) {
            await handleBackgroundRefresh()
        }
    }

    @ViewBuilder
    private var contentRoot: some View {
        switch appInitializer.state {
        
        case .notStarted:
            VStack {
                Text("notStarted...")
                    .font(.largeTitle)
                    .bold()
            }
            .background(.red)
        case .inProgress:
            InitializationView(initializer: appInitializer)
            
        case .completed:
            ContentView()
                .environmentObject(appConfig)
                .environmentObject(appInitializer)
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

    private func handleConfigurationChange(_ isConfigured: Bool) {
        guard isConfigured else { return }

        guard !hasConfiguredManagers else {
            AppLogger.general.info("[App] Managers already configured - skipping")
            return
        }
        
        guard appInitializer.state == .completed else {
            AppLogger.general.info("[App] Waiting for initialization to complete")
            return
        }

        AppLogger.general.info("[App] Configuration changed - reinitializing...")
        
        if !hasPerformedInitialConfiguration {
            // Initial setup nach erstem Login
            hasPerformedInitialConfiguration = true
            AppLogger.general.info("[App] Initial configuration completed - configuring managers")
            configureManagersAndLoadData()
        } else {
            // Reconfiguration (z.B. nach Factory Reset + neuem Login)
            AppLogger.general.info("[App] Reconfiguration detected - reinitializing managers")
            hasConfiguredManagers = false  // Reset flag für Reconfiguration
            configureManagersAndLoadData()
        }
    }

    // MARK: - Initialization
    
    private func performInitialization() async {
        do {
            try await appInitializer.initialize()
            if appInitializer.state == .completed && appInitializer.isConfigured {
                AppLogger.general.info("[App] Initialization completed - configuring managers")
                configureManagersAndLoadData()
            } else {
                AppLogger.general.info("[App] Initialization completed - no configuration available")
            }
        } catch {
            AppLogger.general.error("[App] Initialization failed: \(error)")
        }
    }
    
    private func configureManagersAndLoadData() {
        guard !hasConfiguredManagers else {
            AppLogger.general.info("[App] Managers already configured - skipping")
            return
        }
        
        hasConfiguredManagers = true
        
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
        // Setup audio session
        audioSessionManager.playerViewModel = playerVM
        audioSessionManager.setupRemoteCommandCenter()
        
        // Setup termination handler
        setupTerminationHandler()
        
        AppLogger.general.info("[App] ✅ Initial dependencies configured")
    }
    
    // MARK: - Termination Handler
    
    private func setupTerminationHandler() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak audioSessionManager] _ in
            AppLogger.general.info("[App] Will terminate - performing cleanup")
            audioSessionManager?.handleAppWillTerminate()
        }
        
        signal(SIGTERM) { _ in
            Task { @MainActor in
                AudioSessionManager.shared.handleEmergencyShutdown()
            }
        }
    }
    
    // MARK: - Scene Phase Handling
    
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            handleSceneBecameActive()
        case .inactive:
            handleSceneWillResignActive()
        case .background:
            handleSceneDidEnterBackground()
        @unknown default:
            break
        }
    }
    
    private func handleSceneBecameActive() {
        guard appInitializer.state == .completed else {
            AppLogger.general.info("[App] Scene activation ignored - not initialized")
            return
        }
        
        AppLogger.general.info("[App] Scene became active")
        
        Task { @MainActor in
            await handleAppActivation()
        }
    }
    
    private func handleSceneWillResignActive() {
        AppLogger.general.info("[App] Scene will resign active")
        audioSessionManager.handleAppWillResignActive()
    }
    
    private func handleSceneDidEnterBackground() {
        AppLogger.general.info("[App] Scene entered background - audio should continue")
        audioSessionManager.handleAppEnteredBackground()
        scheduleBackgroundRefresh()
    }
    
    private func handleAppActivation() async {
        AppLogger.general.info("[App] Starting parallel activation")
        
        let startTime = Date()
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.audioSessionManager.handleAppBecameActive()
            }
            
            group.addTask {
                await self.networkMonitor.recheckConnection()
            }
            
            group.addTask {
                if await !self.navidromeVM.isDataFresh {
                    await self.navidromeVM.handleNetworkChange(
                        isOnline: self.networkMonitor.canLoadOnlineContent
                    )
                }
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        AppLogger.general.info("[App] Activation completed in \(String(format: "%.2f", duration))s")
    }
    
    // MARK: - Background Tasks
    
    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.navidrome.client.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            AppLogger.general.info("[App] Background refresh scheduled")
        } catch {
            AppLogger.general.error("[App] Failed to schedule background refresh: \(error)")
        }
    }
    
    private func handleBackgroundRefresh() async {
        AppLogger.general.info("[App] Background refresh triggered")
        
        if networkMonitor.canLoadOnlineContent {
            await favoritesManager.loadFavoriteSongs()
        }
    }
    
    // MARK: - Network Handling
    
    private func handleNetworkChange(isConnected: Bool) async {
        guard appInitializer.state == .completed else {
            AppLogger.general.info("[App] Network change ignored - not initialized")
            return
        }
        
        // ✅ NUR wenn Manager bereits konfiguriert sind
        guard hasConfiguredManagers else {
            AppLogger.general.info("[App] Network change ignored - managers not configured yet")
            return
        }

        
        await navidromeVM.handleNetworkChange(isOnline: isConnected)
        AppLogger.general.info("[App] Network state changed: \(isConnected ? "Connected" : "Disconnected")")
    }
    
    // MARK: - Factory Reset
    
    private func handleFactoryReset() async {
        hasPerformedInitialConfiguration = false
        hasConfiguredManagers = false
        AppLogger.general.info("[App] Factory reset completed - ready for new setup")
    }
}
