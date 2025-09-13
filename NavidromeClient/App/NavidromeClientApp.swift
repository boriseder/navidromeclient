//
//  NavidromeClientApp.swift - FIXED VERSION
//  NavidromeClient
//
//  ✅ FIXES:
//  - Enhanced setupServices to configure PlayerViewModel with coverArtService
//  - Better dependency injection for all services
//  - Proper service coordination
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
    
    // Cover Art Service
    @StateObject private var coverArtService = ReactiveCoverArtService.shared
    
    // App-wide ViewModels
    @StateObject private var navidromeVM = NavidromeViewModel()
    @StateObject private var playerVM: PlayerViewModel
    
    init() {
        let service: SubsonicService?
        if let creds = AppConfig.shared.getCredentials() {
            service = SubsonicService(baseURL: creds.baseURL,
                                      username: creds.username,
                                      password: creds.password)
        } else {
            service = nil
        }

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
                .environmentObject(coverArtService)
                .onAppear {
                    setupServices()
                    setupNetworkMonitoring()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    handleAppBecameActive()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    handleAppWillResignActive()
                }
        }
    }
    
    // ✅ FIX: Enhanced setupServices with proper dependency injection
    private func setupServices() {
        if let creds = appConfig.getCredentials() {
            let service = SubsonicService(
                baseURL: creds.baseURL,
                username: creds.username,
                password: creds.password
            )
            
            // Configure all services with proper dependencies
            navidromeVM.updateService(service)
            playerVM.updateService(service)
            networkMonitor.setService(service)
            
            // ✅ FIX: Configure Cover Art Service
            coverArtService.configure(service: service)
            
            // ✅ FIX: Give PlayerViewModel reference to coverArtService
            playerVM.updateCoverArtService(coverArtService)
            
            print("✅ All services configured with credentials and dependencies")
        } else {
            print("⚠️ No credentials available - services not configured")
        }
    }
    
    private func setupNetworkMonitoring() {
        print("🌐 Network monitoring active")
        
        if networkMonitor.isConnected {
            Task {
                await networkMonitor.checkServerConnection()
            }
        }
    }
    
    private func handleAppBecameActive() {
        print("📱 App became active - refreshing audio session and network status")
        
        Task {
            await networkMonitor.checkServerConnection()
        }
    }
    
    private func handleAppWillResignActive() {
        print("📱 App will resign active - ensuring background audio")
        if playerVM.isPlaying {
            print("🎵 Music is playing - should continue in background")
        }
    }
}
