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
                .task {
                    await setupInitialDataLoading()
                }
                .onChange(of: networkMonitor.isConnected) { _, isConnected in
                    Task {
                        await navidromeVM.handleNetworkChange(isOnline: isConnected)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    handleAppBecameActive()
                }
        }
    }
    
    // ✅ NEW: Centralized Initial Data Loading
    private func setupInitialDataLoading() async {
        guard appConfig.isConfigured else {
            print("⚠️ App not configured - skipping data loading")
            return
        }
        
        setupServices()
        
        // Load initial data in background
        await navidromeVM.loadInitialDataIfNeeded()
    }
    
    private func setupServices() {
        if let creds = appConfig.getCredentials() {
            let service = SubsonicService(
                baseURL: creds.baseURL,
                username: creds.username,
                password: creds.password
            )
            
            navidromeVM.updateService(service)
            playerVM.updateService(service)
            networkMonitor.setService(service)
            coverArtService.configure(service: service)
            playerVM.updateCoverArtService(coverArtService)
            
            print("✅ All services configured with credentials")
        }
    }
    
    private func handleAppBecameActive() {
        // Only refresh if data is very stale (1+ hours)
        if !navidromeVM.isDataFresh {
            Task {
                await navidromeVM.handleNetworkChange(isOnline: networkMonitor.isConnected)
            }
        }
    }
}

