//
//  NavidromeClientApp.swift - SIMPLIFIED: Single Dependency Injection
//  NavidromeClient
//
//   BEFORE: 200+ LOC mit komplexer Service-Initialisierung
//   AFTER: ~50 LOC mit zentralisiertem Dependency Management
//

import SwiftUI

@main
struct NavidromeClientApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // SIMPLIFIED: Nur eine einzige Dependency statt 8+ @StateObjects
    @StateObject private var deps = AppDependencies()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(deps)
                .task {
                    await setupApp()
                }
                .onChange(of: deps.networkMonitor.isConnected) { _, isConnected in
                    Task {
                        await handleNetworkChange(isConnected: isConnected)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    handleAppBecameActive()
                }
        }
    }
    
    // MARK: - Simplified Setup
    
    private func setupApp() async {
        guard deps.isConfigured else {
            print("⚠️ App not configured - skipping data loading")
            return
        }
        
        print("🚀 App configured - loading initial data...")
        
        // Load initial data if needed
        await deps.navidromeVM.loadInitialDataIfNeeded()
        
        print("✅ App setup completed")
    }
    
    // MARK: - Event Handlers
    
    private func handleNetworkChange(isConnected: Bool) async {
        print("🌐 Network state changed: \(isConnected ? "Connected" : "Disconnected")")
        
        if isConnected {
            // Reconfigure services when network comes back
            deps.updateWithNewCredentials()
        }
        
        // Notify managers about network change
        await deps.navidromeVM.handleNetworkChange(isOnline: isConnected)
        await deps.homeScreenManager.handleNetworkChange(isOnline: isConnected)
    }
    
    private func handleAppBecameActive() {
        print("📱 App became active")
        
        Task {
            // Refresh data if needed
            if !deps.navidromeVM.isDataFresh {
                await deps.navidromeVM.handleNetworkChange(isOnline: deps.isConnected)
            }
            
            // Refresh home screen if needed
            await deps.homeScreenManager.refreshIfNeeded()
        }
    }
    
    // MARK: - Debug Helpers
    
    #if DEBUG
    /// Print comprehensive diagnostics for debugging
    func printAppDiagnostics() {
        deps.printDependencyDiagnostics()
    }
    
    /// Force service reconfiguration (debug only)
    func debugForceServiceReconfiguration() {
        deps.debugForceServiceReconfiguration()
    }
    #endif
}

// MARK: - Migration Notes

/*
MIGRATION COMPLETE! 🎉

BEFORE (Complex):
- 8+ @StateObject declarations
- 200+ LOC complex initialization
- configureAllServices()
- setupInitialConfiguration()
- configureManagersWithServices()
- performInitialHealthCheck()

AFTER (Simple):
- 1 @StateObject (AppDependencies)
- ~50 LOC clean initialization
- Dependencies auto-configure themselves
- Clear separation of concerns

BENEFITS:
✅ 75% weniger Code
✅ Vorhersagbare Initialisierung
✅ Zentrale Dependency-Verwaltung
✅ Einfache Testing-Integration
✅ Bessere Error-Handling-Möglichkeiten

VIEWS benötigen jetzt nur noch:
@EnvironmentObject var deps: AppDependencies

Statt:
@EnvironmentObject var navidromeVM: NavidromeViewModel
@EnvironmentObject var playerVM: PlayerViewModel
@EnvironmentObject var downloadManager: DownloadManager
@EnvironmentObject var coverArtManager: CoverArtManager
@EnvironmentObject var networkMonitor: NetworkMonitor
@EnvironmentObject var offlineManager: OfflineManager
@EnvironmentObject var musicLibraryManager: MusicLibraryManager
@EnvironmentObject var appConfig: AppConfig
*/
