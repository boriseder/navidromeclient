//
//  NavidromeClientApp.swift - FIXED: Service Initialization Issues
//  NavidromeClient
//
//   FIXED: Incorrect argument labels and type conversions
//   CLEAN: Proper UnifiedSubsonicService initialization pattern
//   SAFE: Handles missing credentials gracefully
//

import SwiftUI

@main
struct NavidromeClientApp: App {
    // Safe initialization without early service creation
    @StateObject private var serviceContainer = ServiceContainer()
    @StateObject private var navidromeVM = NavidromeViewModel()
    @StateObject private var playerVM = PlayerViewModel()
    
    // Core Services (Singletons)
    @StateObject private var appConfig = AppConfig.shared
    @StateObject private var downloadManager = DownloadManager.shared
    @StateObject private var audioSessionManager = AudioSessionManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var offlineManager = OfflineManager.shared
    @StateObject private var coverArtManager = CoverArtManager.shared
    @StateObject private var exploreManager = ExploreManager.shared
    @StateObject private var favoritesManager = FavoritesManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(serviceContainer)
                .environmentObject(appConfig)
                .environmentObject(navidromeVM)
                .environmentObject(playerVM)
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
        
        await serviceContainer.initializeServices(with: appConfig.getCredentials())
        await configureViewModelsWithServices()
    }
    
    private func configureInitialDependencies() {
        // Safe initial configuration without services
        audioSessionManager.playerViewModel = playerVM
        playerVM.updateCoverArtService(coverArtManager)
    }
    
    private func configureViewModelsWithServices() async {
        guard let service = serviceContainer.unifiedService else { return }
        
        await MainActor.run {
            navidromeVM.updateService(service)
            playerVM.updateService(service)
            
            downloadManager.configure(service: service)
            downloadManager.configure(coverArtManager: coverArtManager)
            favoritesManager.configure(service: service)
            
            let mediaService = service.getMediaService()
            coverArtManager.configure(mediaService: mediaService)
            exploreManager.configure(service: service)
            MusicLibraryManager.shared.configure(service: service)
        }
        
        print("✅ All ViewModels configured with services")
    }
    
    private func initializeServicesAfterLogin(credentials: ServerCredentials) async {
        print("🚀 Starting post-login service initialization...")
        
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
        
        print("✅ Post-login service initialization completed")
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
            playerVM.updateService(unifiedService)
        }
    }

    private func loadInitialDataForAllViews() async {
        print("📚 Loading initial data for all views...")
        
        await withTaskGroup(of: Void.self) { group in
            // ExploreView data
            group.addTask {
                await self.exploreManager.loadExploreData()
                print("✅ ExploreView data loaded")
            }
            
            // Library data
            group.addTask {
                await MusicLibraryManager.shared.loadInitialDataIfNeeded()
                print("✅ Library data loaded")
            }
            
            // Favorites data
            group.addTask {
                await self.favoritesManager.loadFavoriteSongs()
                print("✅ Favorites data loaded")
            }
        }
        
        print("📚 All initial data loading completed")
    }

    private func handleAppBecameActive() {
        print("📱 App became active - checking services...")
        
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
            
            //  FIXED: Configure PlayerViewModel with UnifiedSubsonicService
            playerVM.updateService(unifiedService)
            
            //  Configure DownloadManager with UnifiedSubsonicService
            downloadManager.configure(service: unifiedService)
            downloadManager.configure(coverArtManager: coverArtManager)
            favoritesManager.configure(service: unifiedService)

            //  Configure CoverArtManager with focused MediaService
            let mediaService = unifiedService.getMediaService()
            coverArtManager.configure(mediaService: mediaService)
                        
            //  Configure HomeScreenManager
            exploreManager.configure(service: unifiedService)
            
            //  Configure MusicLibraryManager
            MusicLibraryManager.shared.configure(service: unifiedService)
            
            //  FIXED: Update PlayerViewModel with CoverArtManager
            playerVM.updateCoverArtService(coverArtManager)
            
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
        
        print("✅ ServiceContainer: Services initialized")
    }
    
    func clearServices() {
        unifiedService = nil
        isInitialized = false
        print("🧹 ServiceContainer: Services cleared")
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
