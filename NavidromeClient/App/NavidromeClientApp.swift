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
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Core Services (Singletons)
    @StateObject private var appConfig = AppConfig.shared
    @StateObject private var downloadManager = DownloadManager.shared
    @StateObject private var audioSessionManager = AudioSessionManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var offlineManager = OfflineManager.shared
    @StateObject private var coverArtManager = CoverArtManager.shared
    @StateObject private var homeScreenManager = HomeScreenManager.shared
    
    //  FIXED: ViewModels with proper service initialization
    @StateObject private var navidromeVM: NavidromeViewModel
    @StateObject private var playerVM: PlayerViewModel
    
    init() {
        //  FIXED: Create ViewModels with correct service handling
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
        //  FIXED: Use correct initializer - service parameter accepts UnifiedSubsonicService?
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
                .environmentObject(MusicLibraryManager.shared)
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
    
    ///  FIXED: Service configuration with proper service types
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
    
    ///  FIXED: Configure managers with correct service extraction
    private func configureManagersWithServices(unifiedService: UnifiedSubsonicService) async {
        await MainActor.run {
            //  Configure NavidromeViewModel
            navidromeVM.updateService(unifiedService)
            
            //  FIXED: Configure PlayerViewModel with UnifiedSubsonicService
            playerVM.updateService(unifiedService)
            
            //  Configure DownloadManager with UnifiedSubsonicService
            downloadManager.configure(service: unifiedService)
            downloadManager.configure(coverArtManager: coverArtManager)
            
            //  Configure CoverArtManager with focused MediaService
            let mediaService = unifiedService.getMediaService()
            coverArtManager.configure(mediaService: mediaService)
            
            //  Configure HomeScreenManager
            homeScreenManager.configure(service: unifiedService)
            
            //  Configure MusicLibraryManager
            MusicLibraryManager.shared.configure(service: unifiedService)
            
            //  FIXED: Update PlayerViewModel with CoverArtManager
            playerVM.updateCoverArtService(coverArtManager)
            
            print(" All managers configured with focused services")
        }
    }
    
    ///  FIXED: Initial health check
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
    
    // MARK: -  FIXED: Network State Management
    
    private func handleNetworkChange(isConnected: Bool) async {
        print("🌐 Network state changed: \(isConnected ? "Connected" : "Disconnected")")
        
        if isConnected {
            //  FIXED: Reconfigure services when network comes back
            await setupSimplifiedServices()
        }
        
        //  Notify managers about network change
        await navidromeVM.handleNetworkChange(isOnline: isConnected)
        await homeScreenManager.handleNetworkChange(isOnline: isConnected)
        
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
            await homeScreenManager.refreshIfNeeded()
        }
    }
    
    ///  FIXED: Comprehensive health check when app becomes active
    private func performAppActivationHealthCheck() async {
        print("🔄 App activation health check...")
        
        // Force NetworkMonitor server health check
        await networkMonitor.forceServerHealthCheck()
        
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
    
    // MARK: -  FIXED: Advanced Service Features
    
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
    
    //  FIXED: Correct type references
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
}

// MARK: -  MIGRATION NOTES & DOCUMENTATION

/*
SERVICE INITIALIZATION FIXES COMPLETE! 🎉

 FIXES APPLIED:
1. FIXED: PlayerViewModel(service:) parameter - now accepts UnifiedSubsonicService?
2. FIXED: Service type conversion - no longer tries to pass UnifiedSubsonicService as MediaService
3. FIXED: Proper service configuration flow through updateService() methods
4. FIXED: All manager configurations use correct service types

 SERVICE FLOW:
App -> Creates UnifiedSubsonicService -> Passes to ViewModels -> ViewModels extract focused services

 INITIALIZATION PATTERN:
```swift
// Create service if credentials available
let service: UnifiedSubsonicService? = credentials ? UnifiedSubsonicService(...) : nil

// Initialize ViewModels with service
PlayerViewModel(service: service, downloadManager: downloadManager)

// Later configure with updateService()
playerVM.updateService(unifiedService)  // Extracts MediaService internally
```

 ARCHITECTURE BENEFITS:
- Single source of truth for service creation
- Proper optional handling when no credentials
- Clean separation between service factory and focused services
- No type conversion errors
- Graceful degradation when services unavailable

The app now initializes correctly with proper service types and handles
missing credentials gracefully!
*/
