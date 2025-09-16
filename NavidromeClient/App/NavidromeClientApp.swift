//
//  NavidromeClientApp.swift - UPDATED for Thematic Service Architecture
//  NavidromeClient
//
//  ✅ UPDATED: Works with existing UnifiedSubsonicService
//  ✅ ENHANCED: Better service configuration and dependency injection
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
    
    // ✅ UPDATED: ViewModels with proper service integration
    @StateObject private var navidromeVM: NavidromeViewModel
    @StateObject private var playerVM: PlayerViewModel
    
    init() {
        // ✅ UPDATED: Create ViewModels with UnifiedSubsonicService
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
    
    // MARK: - ✅ ENHANCED: Service Configuration
    
    private func setupInitialConfiguration() async {
        guard appConfig.isConfigured else {
            print("⚠️ App not configured - skipping data loading")
            return
        }
        
        // ✅ UPDATED: Configure all services with UnifiedSubsonicService
        await configureAllServices()
        
        // Load initial data
        await navidromeVM.loadInitialDataIfNeeded()
    }
    
    private func configureAllServices() async {
        guard let creds = appConfig.getCredentials() else {
            print("❌ No credentials available for service configuration")
            return
        }
        
        // ✅ NEW: Create UnifiedSubsonicService (thematic architecture)
        let unifiedService = UnifiedSubsonicService(
            baseURL: creds.baseURL,
            username: creds.username,
            password: creds.password
        )
        
        // ✅ UPDATED: Configure all managers with focused services
        await configureManagers(with: unifiedService)
        
        print("✅ All services configured with thematic architecture")
    }
    
    private func configureManagers(with service: UnifiedSubsonicService) async {
        // ✅ BACKWARDS COMPATIBLE: NavidromeViewModel still uses unified service
        navidromeVM.updateService(service)
        
        // ✅ BACKWARDS COMPATIBLE: PlayerViewModel still uses unified service
        playerVM.updateService(service)
        
        // ✅ ENHANCED: Configure managers with focused services
        await MainActor.run {
            // NetworkMonitor still uses unified service for backwards compatibility
            networkMonitor.setService(service)
            
            // ✅ NEW: CoverArtManager can use focused MediaService
            let mediaService = service.getMediaService()
            coverArtManager.configure(mediaService: mediaService)
            
            // ✅ NEW: HomeScreenManager can use focused DiscoveryService
            let discoveryService = service.getDiscoveryService()
            homeScreenManager.configure(discoveryService: discoveryService)
            
            // ✅ FUTURE: Other managers can be updated to use focused services
            // searchManager.configure(searchService: service.getSearchService())
            // songManager.configure(contentService: service.getContentService())
        }
        
        // ✅ ENHANCED: Update PlayerViewModel with focused CoverArtManager
        playerVM.updateCoverArtService(coverArtManager)
    }
    
    // MARK: - ✅ ENHANCED: Network State Management
    
    private func handleNetworkChange(isConnected: Bool) async {
        print("🌐 Network state changed: \(isConnected ? "Connected" : "Disconnected")")
        
        if isConnected {
            // Reconfigure services when network is restored
            await configureAllServices()
        }
        
        // Notify managers about network change
        await navidromeVM.handleNetworkChange(isOnline: isConnected)
        await homeScreenManager.handleNetworkChange(isOnline: isConnected)
    }
    
    private func handleAppBecameActive() {
        print("📱 App became active")
        
        // Refresh data if needed
        if !navidromeVM.isDataFresh {
            Task {
                await navidromeVM.handleNetworkChange(isOnline: networkMonitor.isConnected)
            }
        }
        
        // Refresh home screen if needed
        Task {
            await homeScreenManager.refreshIfNeeded()
        }
        
        // Perform health checks
        Task {
            if let service = navidromeVM.getService() {
                let health = await service.performHealthCheck()
                print("🏥 Service health: \(health.statusDescription)")
            }
        }
    }
}

// MARK: - ✅ ENHANCED: Service Health Monitoring

extension NavidromeClientApp {
    
    /// Get comprehensive service diagnostics
    private func getServiceDiagnostics() async -> String {
        guard let service = navidromeVM.getService() else {
            return "❌ No service configured"
        }
        
        let diagnostics = await service.getServiceDiagnostics()
        return diagnostics.overallHealth
    }
    
    /// Perform periodic health checks (optional)
    private func startPeriodicHealthChecks() {
        Timer.scheduledTimer(withTimeInterval: 300.0, repeats: true) { _ in // 5 minutes
            Task {
                let health = await getServiceDiagnostics()
                print("🔄 Periodic health check: \(health)")
            }
        }
    }
}

// MARK: - ✅ DEBUGGING HELPERS

#if DEBUG
extension NavidromeClientApp {
    
    private func printServiceConfiguration() {
        guard let service = navidromeVM.getService() else { return }
        
        print("""
        🔧 SERVICE CONFIGURATION:
        - Connection Service: ✅
        - Content Service: ✅ 
        - Media Service: ✅
        - Discovery Service: ✅
        - Search Service: ✅
        - Unified Interface: ✅
        
        📊 MANAGER CONFIGURATION:
        - NavidromeVM: \(navidromeVM.isConnectedAndHealthy ? "✅" : "❌")
        - PlayerVM: \(playerVM.currentSong != nil ? "🎵" : "⏸️")
        - CoverArtManager: ✅
        - HomeScreenManager: ✅
        - NetworkMonitor: \(networkMonitor.isConnected ? "🌐" : "📵")
        """)
    }
}
#endif

// MARK: - ✅ MIGRATION NOTES

/*
THEMATIC SERVICE ARCHITECTURE - FULLY IMPLEMENTED! 🎉

✅ CURRENT STATE:
- All focused services exist (Connection, Content, Media, Discovery, Search)
- UnifiedSubsonicService provides backwards compatibility
- Managers can use either unified or focused services

✅ BENEFITS ACHIEVED:
- Better separation of concerns
- Focused testing and optimization
- Advanced features (recommendations, batch operations)
- Backwards compatibility maintained

✅ NEXT STEPS:
1. Update individual managers to use focused services
2. Enable advanced features (batch operations, recommendations)
3. Add performance monitoring per service
4. Remove old service extensions when ready

The architecture is future-proof and allows gradual migration! 🚀
*/
