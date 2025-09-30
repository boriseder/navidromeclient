//
//  NavidromeClientApp.swift - FIXED: Service Initialization Issues
//  NavidromeClient
//
//   FIXED: Incorrect argument labels and type conversions
//   CLEAN: Proper UnifiedSubsonicService initialization pattern
//   SAFE: Handles missing credentials gracefully
//
// Service initialization dependency graph:
//
// UnifiedSubsonicService (created in ServiceContainer)
//   ↓
// ├─→ CoverArtManager.configure(service)
// ├─→ SongManager.configure(service)
// ├─→ DownloadManager.configure(service)
// │   └─→ DownloadManager.configure(coverArtManager)
// ├─→ FavoritesManager.configure(service)
// ├─→ ExploreManager.configure(service)
// └─→ MusicLibraryManager.configure(service)
//
// NavidromeViewModel.updateService(service)


import SwiftUI

@main
struct NavidromeClientApp: App {
    // Safe initialization without early service creation
    @StateObject private var serviceContainer = ServiceContainer()
    @StateObject private var navidromeVM = NavidromeViewModel()

    // SongManager
    @StateObject private var songManager = SongManager(downloadManager: .shared)
    
    // Inject songManager into PlayerViewModel
    @StateObject private var playerVM: PlayerViewModel
    
    // Core Services (Singletons)
    @StateObject private var appConfig = AppConfig.shared
    @StateObject private var downloadManager = DownloadManager.shared
    @StateObject private var audioSessionManager = AudioSessionManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var offlineManager = OfflineManager.shared
    @StateObject private var coverArtManager = CoverArtManager.shared
    @StateObject private var exploreManager = ExploreManager.shared
    @StateObject private var favoritesManager = FavoritesManager.shared
    
    init() {
        // Initialize PlayerViewModel with SongManager
        let songMgr = SongManager(downloadManager: .shared)
        let playerViewModel = PlayerViewModel(songManager: songMgr)
        
        _songManager = StateObject(wrappedValue: songMgr)
        _playerVM = StateObject(wrappedValue: playerViewModel)
        
        // UI configuration
        let appearance = UINavigationBarAppearance()
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        let searchBarAppearance = UISearchBar.appearance()
        searchBarAppearance.barTintColor = .red
        searchBarAppearance.searchTextField.backgroundColor = .yellow
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
                .task {
                    await setupServicesAfterAppLaunch()
                }
                .onAppear {
                    configureInitialDependencies()
                }
                .onChange(of: networkMonitor.isConnected) { _, isConnected in
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
                            await initializeServicesAfterLogin(credentials: credentials)
                        }
                    }
                }
        }
    }
    
    private func setupServicesAfterAppLaunch() async {
        guard appConfig.isConfigured else {
            print("⚠️ App not configured - services will be initialized after login")
            return
        }
        
        print("🚀 Starting service initialization...")
        print("  Configuration status: \(appConfig.isConfigured)")
        print("  Credentials available: \(appConfig.getCredentials() != nil)")
        
        await serviceContainer.initializeServices(with: appConfig.getCredentials())
        await configureViewModelsWithServices()
        
        print("✅ Service initialization complete")
        print("  Services ready: \(appConfig.areServicesReady)")
    }
    
    private func configureInitialDependencies() {
        // Safe initial configuration without services
        audioSessionManager.playerViewModel = playerVM
    }
    
    private func configureViewModelsWithServices() async {
        guard let service = serviceContainer.unifiedService else {
            print("❌ Cannot configure: No service available")
            return
        }
        
        print("🔧 Starting service configuration in dependency order...")
        
        await MainActor.run {
            // Phase 1: Independent services (no dependencies)
            coverArtManager.configure(service: service)
            print("  ✓ CoverArtManager configured")
            
            // Phase 2: Services that depend on Phase 1
            songManager.configure(service: service)
            print("  ✓ SongManager configured")
            
            // Phase 3: Services with multiple dependencies
            downloadManager.configure(service: service)
            downloadManager.configure(coverArtManager: coverArtManager)
            print("  ✓ DownloadManager configured")
            
            favoritesManager.configure(service: service)
            print("  ✓ FavoritesManager configured")
            
            exploreManager.configure(service: service)
            print("  ✓ ExploreManager configured")
            
            MusicLibraryManager.shared.configure(service: service)
            print("  ✓ MusicLibraryManager configured")
            
            // Phase 4: ViewModels last
            navidromeVM.updateService(service)
            print("  ✓ NavidromeViewModel configured")
            
            print("✅ All services configured successfully")
        }
    }
    
    private func initializeServicesAfterLogin(credentials: ServerCredentials) async {
        
        await MainActor.run {
            appConfig.setInitializingServices(true)
        }
        
        // Create unified service with new credentials
        let unifiedService = UnifiedSubsonicService(
            baseURL: credentials.baseURL,
            username: credentials.username,
            password: credentials.password
        )
        
        // Configure all managers with the new service
        await configureManagersWithServices(unifiedService: unifiedService)
        
        // Load initial data for all views in parallel
        await loadInitialDataForAllViews()
        
        await MainActor.run {
            appConfig.setInitializingServices(false)
        }
        
    }

    private func handleNetworkChange(isConnected: Bool) async {
        print("🌐 Network state changed: \(isConnected ? "Connected" : "Disconnected")")
        
        if isConnected {
            //  FIXED: Reconfigure services when network comes back
            await setupSimplifiedServices()
        }
        
        //  Notify managers about network change
        await navidromeVM.handleNetworkChange(isOnline: isConnected)
        await exploreManager.handleNetworkChange(isOnline: isConnected)
        
        //  Update NetworkMonitor diagnostics
        let networkDiag = networkMonitor.getNetworkDiagnostics()
        print("📊 Network diagnostics: \(networkDiag.summary)")
    }

    private func setupSimplifiedServices() async {
        guard let creds = appConfig.getCredentials() else { return }
        
        let unifiedService = UnifiedSubsonicService(
            baseURL: creds.baseURL,
            username: creds.username,
            password: creds.password
        )
        
        await MainActor.run {
            navidromeVM.updateService(unifiedService)
            
            songManager.configure(service: unifiedService)
        }
    }

    private func loadInitialDataForAllViews() async {
        print("📚 Loading initial data for all views...")
        
        await withTaskGroup(of: Void.self) { group in
            // ExploreView data
            group.addTask {
                await self.exploreManager.loadExploreData()
            }
            
            // Library data
            group.addTask {
                await MusicLibraryManager.shared.loadInitialDataIfNeeded()
            }
            
            // Favorites data
            group.addTask {
                await self.favoritesManager.loadFavoriteSongs()
            }
        }
        
    }

    private func handleAppBecameActive() {
        print("App became active - checking services...")
        
        Task {
            //  FIXED: Comprehensive health check on app activation
            await performAppActivationHealthCheck()
            
            // Refresh data if needed
            if !navidromeVM.isDataFresh {
                await navidromeVM.handleNetworkChange(isOnline: networkMonitor.isConnected)
            }
            
            // Refresh home screen if needed
            await exploreManager.refreshIfNeeded()
        }
    }

    private func configureManagersWithServices(unifiedService: UnifiedSubsonicService) async {
        await MainActor.run {
            //  Configure NavidromeViewModel
            navidromeVM.updateService(unifiedService)
                   
            songManager.configure(service: unifiedService)

            downloadManager.configure(service: unifiedService)
            downloadManager.configure(coverArtManager: coverArtManager)
            favoritesManager.configure(service: unifiedService)

            coverArtManager.configure(service: unifiedService)

            //  Configure HomeScreenManager
            exploreManager.configure(service: unifiedService)
            
            //  Configure MusicLibraryManager
            MusicLibraryManager.shared.configure(service: unifiedService)
            
            
            print(" All managers configured with focused services")
        }
    }

    private func performAppActivationHealthCheck() async {
        print("🔄 App activation health check...")
        
        
        // NavidromeViewModel connection health check
        await navidromeVM.performConnectionHealthCheck()
        
        // Get comprehensive diagnostics
        let serviceDiag = await navidromeVM.getServiceArchitectureDiagnostics()
        print("📋 App activation diagnostics: \(serviceDiag.overallHealth)")
        
        #if DEBUG
        // Print full diagnostics in debug builds
        navidromeVM.printServiceDiagnostics()
        #endif
    }

}

// New ServiceContainer class
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
        print("ServiceContainer: Services cleared")
    }
}

 /*
    // MARK: -  FIXED: Enhanced Service Configuration
    
    
    private func setupInitialConfiguration() async {
        guard appConfig.isConfigured else {
            print("⚠️ App not configured - skipping data loading")
            return
        }
        
        //  FIXED: Configure all services properly
        await configureAllServices()
        
        // Load initial data
        await navidromeVM.loadInitialDataIfNeeded()
        
        //  FIXED: Perform initial health check
        await performInitialHealthCheck()
    }
    
    private func configureAllServices() async {
        guard let creds = appConfig.getCredentials() else {
            print("❌ No credentials available for service configuration")
            return
        }
        
        //  FIXED: Create UnifiedSubsonicService
        let unifiedService = UnifiedSubsonicService(
            baseURL: creds.baseURL,
            username: creds.username,
            password: creds.password
        )
        
        //  FIXED: Configure all managers with proper service types
        await configureManagersWithServices(unifiedService: unifiedService)
        
        print(" All services configured successfully")
    }
    
    
    fileprivate func performInitialHealthCheck() async {
        print("🏥 Performing initial health check...")
        
        await navidromeVM.performConnectionHealthCheck()
        
        let health = await navidromeVM.getConnectionHealth()
        let diagnostics = await navidromeVM.getConnectionDiagnostics()
        
        print("""
        📊 INITIAL HEALTH CHECK RESULTS:
        - Status: \(health?.statusDescription ?? "Unknown")
        - Health Score: \(String(format: "%.1f", (health?.healthScore ?? 0.0) * 100))%
        - Architecture: \(diagnostics.summary)
        """)
    }
            
    /// Get comprehensive service health for troubleshooting
    func getComprehensiveServiceHealth() async -> ComprehensiveServiceHealth {
        let connectionHealth = await navidromeVM.getConnectionHealth()
        let networkDiag = networkMonitor.getNetworkDiagnostics()
        let serviceDiag = await navidromeVM.getServiceArchitectureDiagnostics()
        
        return ComprehensiveServiceHealth(
            connectionHealth: connectionHealth,
            networkDiagnostics: networkDiag,
            serviceArchitectureDiagnostics: serviceDiag
        )
    }
    
    struct ComprehensiveServiceHealth {
        let connectionHealth: ConnectionHealth?
        let networkDiagnostics: NetworkMonitor.NetworkDiagnostics
        let serviceArchitectureDiagnostics: NavidromeViewModel.ServiceArchitectureDiagnostics
        
        var overallHealthScore: Double {
            let connectionScore = connectionHealth?.healthScore ?? 0.0
            let networkScore = networkDiagnostics.canLoadContent ? 1.0 : 0.0
            
            return (connectionScore + networkScore) / 2.0
        }
        
        var healthSummary: String {
            let score = overallHealthScore * 100
            
            if score >= 80 {
                return " Excellent (\(String(format: "%.0f", score))%)"
            } else if score >= 60 {
                return "⚠️ Good (\(String(format: "%.0f", score))%)"
            } else if score >= 40 {
                return "⚠️ Poor (\(String(format: "%.0f", score))%)"
            } else {
                return "❌ Critical (\(String(format: "%.0f", score))%)"
            }
        }
        
        var detailedReport: String {
            return """
            🏥 COMPREHENSIVE SERVICE HEALTH REPORT
            Overall: \(healthSummary)
            
            \(serviceArchitectureDiagnostics.architectureSummary)
            
            Performance Metrics:
            - Connection: \(connectionHealth?.statusDescription ?? "Unknown")
            - Network: \(networkDiagnostics.summary)
            """
        }
    }
    
    // MARK: -  DEBUG HELPERS
    
    #if DEBUG
    /// Print comprehensive service diagnostics for debugging
    func printComprehensiveServiceDiagnostics() {
        Task {
            let health = await getComprehensiveServiceHealth()
            print(health.detailedReport)
        }
    }
    
    /// Force service reconfiguration (debug only)
    func debugForceServiceReconfiguration() {
        Task {
            print("🔄 DEBUG: Forcing service reconfiguration...")
            await configureAllServices()
            await performInitialHealthCheck()
        }
    }
    #endif

*/
