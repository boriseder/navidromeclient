//
//  NavidromeClientApp.swift - UPDATED for ConnectionService Integration
//  NavidromeClient
//
//  ✅ UPDATED: Complete ConnectionService integration
//  ✅ ENHANCED: Better service configuration with focused services
//  ✅ BACKWARDS COMPATIBLE: All existing functionality preserved
//

import SwiftUI

@main
struct NavidromeClientApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Core Services (Singletons) - unchanged
    @StateObject private var appConfig = AppConfig.shared
    @StateObject private var downloadManager = DownloadManager.shared
    @StateObject private var audioSessionManager = AudioSessionManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var offlineManager = OfflineManager.shared
    @StateObject private var coverArtManager = CoverArtManager.shared
    @StateObject private var homeScreenManager = HomeScreenManager.shared
    
    // ✅ UPDATED: ViewModels with ConnectionService integration
    @StateObject private var navidromeVM: NavidromeViewModel
    @StateObject private var playerVM: PlayerViewModel
    
    init() {
        // ✅ UPDATED: Create ViewModels with enhanced service architecture
        let service: UnifiedSubsonicService?
        if let creds = AppConfig.shared.getCredentials() {
            service = UnifiedSubsonicService(
                baseURL: creds.baseURL,
                username: creds.username,
                password: creds.password
            )
        } else {
            service = nil
        }

        _navidromeVM = StateObject(wrappedValue: NavidromeViewModel())
        _playerVM = StateObject(wrappedValue: PlayerViewModel(service: service, downloadManager: DownloadManager.shared))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appConfig)
                .environmentObject(navidromeVM)
                .environmentObject(playerVM)
                .environmentObject(downloadManager)
                .environmentObject(audioSessionManager)
                .environmentObject(networkMonitor)
                .environmentObject(offlineManager)
                .environmentObject(coverArtManager)
                .environmentObject(homeScreenManager)
                .task {
                    await setupInitialConfiguration()
                }
                .onChange(of: networkMonitor.isConnected) { _, isConnected in
                    Task {
                        await handleNetworkChange(isConnected: isConnected)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    handleAppBecameActive()
                }
        }
    }
    
    // MARK: - ✅ UPDATED: Enhanced Service Configuration with ConnectionService
    
    private func setupInitialConfiguration() async {
        guard appConfig.isConfigured else {
            print("⚠️ App not configured - skipping data loading")
            return
        }
        
        // ✅ UPDATED: Configure all services with ConnectionService integration
        await configureAllServicesWithConnectionService()
        
        // Load initial data
        await navidromeVM.loadInitialDataIfNeeded()
        
        // ✅ NEW: Perform initial health check via ConnectionService
        await performInitialHealthCheck()
    }
    
    /// ✅ NEW: Enhanced service configuration with ConnectionService
    private func configureAllServicesWithConnectionService() async {
        guard let creds = appConfig.getCredentials() else {
            print("❌ No credentials available for service configuration")
            return
        }
        
        // ✅ UPDATED: Create UnifiedSubsonicService (includes ConnectionService internally)
        let unifiedService = UnifiedSubsonicService(
            baseURL: creds.baseURL,
            username: creds.username,
            password: creds.password
        )
        
        // ✅ UPDATED: Configure all managers with focused services
        await configureManagersWithFocusedServices(unifiedService: unifiedService)
        
        print("✅ All services configured with ConnectionService integration")
    }
    
    /// ✅ UPDATED: Configure managers with focused services from UnifiedSubsonicService
    private func configureManagersWithFocusedServices(unifiedService: UnifiedSubsonicService) async {
        await MainActor.run {
            // ✅ UPDATED: NavidromeViewModel now handles ConnectionManager internally
            navidromeVM.updateService(unifiedService)
            
            // ✅ UPDATED: PlayerViewModel uses MediaService from UnifiedSubsonicService
            playerVM.updateService(unifiedService)
            
            // ✅ ENHANCED: Configure managers with focused services
            let mediaService = unifiedService.getMediaService()
            coverArtManager.configure(mediaService: mediaService)
            
            let discoveryService = unifiedService.getDiscoveryService()
            homeScreenManager.configure(discoveryService: discoveryService)
            
            // ✅ NOTE: NetworkMonitor is now configured by NavidromeViewModel
            // This ensures proper ConnectionManager integration
            
            print("✅ All managers configured with focused services from UnifiedSubsonicService")
        }
        
        // ✅ ENHANCED: Update PlayerViewModel with focused CoverArtManager
        playerVM.updateCoverArtService(coverArtManager)
    }
    
    /// ✅ NEW: Initial health check via ConnectionService
    private func performInitialHealthCheck() async {
        print("🏥 Performing initial ConnectionService health check...")
        
        await navidromeVM.performConnectionHealthCheck()
        
        let health = navidromeVM.getConnectionHealth()
        let diagnostics = navidromeVM.getConnectionDiagnostics()
        
        print("""
        📊 INITIAL HEALTH CHECK RESULTS:
        - Status: \(health.statusDescription)
        - Health Score: \(String(format: "%.1f", health.healthScore * 100))%
        - Architecture: \(diagnostics.summary)
        """)
    }
    
    // MARK: - ✅ ENHANCED: Network State Management with ConnectionService
    
    private func handleNetworkChange(isConnected: Bool) async {
        print("🌐 Network state changed: \(isConnected ? "Connected" : "Disconnected")")
        
        if isConnected {
            // ✅ UPDATED: Reconfigure services and perform health check
            await configureAllServicesWithConnectionService()
            await navidromeVM.performConnectionHealthCheck()
        }
        
        // ✅ ENHANCED: Notify managers about network change
        await navidromeVM.handleNetworkChange(isOnline: isConnected)
        await homeScreenManager.handleNetworkChange(isOnline: isConnected)
        
        // ✅ NEW: Update NetworkMonitor diagnostics
        let networkDiag = networkMonitor.getNetworkDiagnostics()
        print("📊 Network diagnostics: \(networkDiag.summary)")
    }
    
    private func handleAppBecameActive() {
        print("📱 App became active - checking services...")
        
        Task {
            // ✅ ENHANCED: Comprehensive health check on app activation
            await performAppActivationHealthCheck()
            
            // Refresh data if needed
            if !navidromeVM.isDataFresh {
                await navidromeVM.handleNetworkChange(isOnline: networkMonitor.isConnected)
            }
            
            // Refresh home screen if needed
            await homeScreenManager.refreshIfNeeded()
        }
    }
    
    /// ✅ NEW: Comprehensive health check when app becomes active
    private func performAppActivationHealthCheck() async {
        print("🔄 App activation health check...")
        
        // Force NetworkMonitor server health check
        await networkMonitor.forceServerHealthCheck()
        
        // NavidromeViewModel connection health check
        await navidromeVM.performConnectionHealthCheck()
        
        // Get comprehensive diagnostics
        let serviceDiag = navidromeVM.getServiceArchitectureDiagnostics()
        print("📋 App activation diagnostics: \(serviceDiag.overallHealth)")
        
        #if DEBUG
        // Print full diagnostics in debug builds
        navidromeVM.printServiceDiagnostics()
        #endif
    }
    
    // MARK: - ✅ NEW: Advanced Service Features
    
    /// Get comprehensive service health for troubleshooting
    func getComprehensiveServiceHealth() async -> ComprehensiveServiceHealth {
        let connectionHealth = navidromeVM.getConnectionHealth()
        let networkDiag = networkMonitor.getNetworkDiagnostics()
        let serviceDiag = navidromeVM.getServiceArchitectureDiagnostics()
        
        return ComprehensiveServiceHealth(
            connectionHealth: connectionHealth,
            networkDiagnostics: networkDiag,
            serviceArchitectureDiagnostics: serviceDiag
        )
    }
    
    struct ComprehensiveServiceHealth {
        let connectionHealth: ConnectionManager.ConnectionHealth
        let networkDiagnostics: NetworkMonitor.NetworkDiagnostics
        let serviceArchitectureDiagnostics: NavidromeViewModel.ServiceArchitectureDiagnostics
        
        var overallHealthScore: Double {
            let connectionScore = connectionHealth.healthScore
            let networkScore = networkDiagnostics.canLoadContent ? 1.0 : 0.0
            
            return (connectionScore + networkScore) / 2.0
        }
        
        var healthSummary: String {
            let score = overallHealthScore * 100
            
            if score >= 80 {
                return "✅ Excellent (\(String(format: "%.0f", score))%)"
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
            - Connection: \(connectionHealth.statusDescription)
            - Network: \(networkDiagnostics.summary)
            """
        }
    }
    
    // MARK: - ✅ DEBUG HELPERS
    
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
            await configureAllServicesWithConnectionService()
            await performInitialHealthCheck()
        }
    }
    #endif
}

// MARK: - ✅ MIGRATION NOTES & DOCUMENTATION

/*
CONNECTIONSERVICE INTEGRATION COMPLETE! 🎉

✅ MIGRATION SUMMARY:
1. ConnectionManager now uses ConnectionService internally
2. NavidromeViewModel updated to use enhanced ConnectionManager
3. NetworkMonitor migrated to use ConnectionManager instead of direct service calls
4. App-level integration updated with comprehensive health monitoring
5. All existing APIs preserved for backwards compatibility

✅ NEW CAPABILITIES:
- Advanced connection health monitoring via ConnectionService
- Enhanced service diagnostics and troubleshooting
- Better separation of concerns: UI binding vs connection logic
- Comprehensive health checks and performance monitoring
- Enhanced error handling and recovery

✅ ARCHITECTURE:
App -> NavidromeViewModel -> ConnectionManager -> ConnectionService
                          -> NetworkMonitor --^
                          -> Managers -> Focused Services

✅ PERFORMANCE IMPROVEMENTS:
- More accurate connection quality assessment
- Better error handling with specific error types
- Enhanced monitoring and diagnostics
- Cleaner service coordination and configuration

The migration maintains full backwards compatibility while providing
enhanced connection management via the focused ConnectionService architecture!
*/
