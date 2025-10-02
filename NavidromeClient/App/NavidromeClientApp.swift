//
//  NavidromeClientApp.swift - UNIFIED: Single Initialization Path
//  NavidromeClient
//

import SwiftUI

@main
struct NavidromeClientApp: App {
    @StateObject private var serviceContainer = ServiceContainer()
    @StateObject private var navidromeVM = NavidromeViewModel()
    @StateObject private var songManager = SongManager(downloadManager: .shared)
    @StateObject private var playerVM: PlayerViewModel
    
    @StateObject private var appConfig = AppConfig.shared
    @StateObject private var downloadManager = DownloadManager.shared
    @StateObject private var audioSessionManager = AudioSessionManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var offlineManager = OfflineManager.shared
    @StateObject private var coverArtManager = CoverArtManager.shared
    @StateObject private var exploreManager = ExploreManager.shared
    @StateObject private var favoritesManager = FavoritesManager.shared
    
    init() {
        let songMgr = SongManager(downloadManager: .shared)
        let playerViewModel = PlayerViewModel(songManager: songMgr)
        
        _songManager = StateObject(wrappedValue: songMgr)
        _playerVM = StateObject(wrappedValue: playerViewModel)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(serviceContainer)
                .environmentObject(appConfig)
                .environmentObject(navidromeVM)
                .environmentObject(playerVM)
                .environmentObject(songManager)
                .environmentObject(downloadManager)
                .environmentObject(audioSessionManager)
                .environmentObject(networkMonitor)
                .environmentObject(offlineManager)
                .environmentObject(coverArtManager)
                .environmentObject(exploreManager)
                .environmentObject(MusicLibraryManager.shared)
                .environmentObject(FavoritesManager.shared)
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
        
        // Create unified service
        let unifiedService = UnifiedSubsonicService(
            baseURL: credentials.baseURL,
            username: credentials.username,
            password: credentials.password
        )
        
        // Store in container
        await serviceContainer.initializeServices(with: credentials)
        
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
            MusicLibraryManager.shared.configure(service: unifiedService)
            
            // Phase 3: ViewModels
            navidromeVM.updateService(unifiedService)
            
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
                await MusicLibraryManager.shared.loadInitialDataIfNeeded()
            }
            
            group.addTask {
                await self.favoritesManager.loadFavoriteSongs()
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
        print("Network state changed: \(isConnected ? "Connected" : "Disconnected")")
        
        await navidromeVM.handleNetworkChange(isOnline: isConnected)
        await exploreManager.handleNetworkChange(isOnline: isConnected)
    }
    
    private func handleAppBecameActive() {
        print("App became active")
        
        Task {
            if !navidromeVM.isDataFresh {
                await navidromeVM.handleNetworkChange(isOnline: networkMonitor.canLoadOnlineContent)
            }
            
            await exploreManager.refreshIfNeeded()
        }
    }
}

// MARK: - Service Container

@MainActor
class ServiceContainer: ObservableObject {
    @Published private(set) var unifiedService: UnifiedSubsonicService?
    @Published private(set) var isInitialized = false
    
    func initializeServices(with credentials: ServerCredentials?) async {
        guard let credentials = credentials else {
            unifiedService = nil
            isInitialized = false
            return
        }
        
        unifiedService = UnifiedSubsonicService(
            baseURL: credentials.baseURL,
            username: credentials.username,
            password: credentials.password
        )
        isInitialized = true
    }
    
    func clearServices() {
        unifiedService = nil
        isInitialized = false
    }
}
