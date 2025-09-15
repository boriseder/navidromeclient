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
    @StateObject private var coverArtManager = CoverArtManager.shared
    
    // ✅ NEW: Home Screen Manager
    @StateObject private var homeScreenManager = HomeScreenManager.shared
    
    // ✅ FIXED: MusicLibraryManager as Dependency Injection
    @StateObject private var musicLibraryManager = MusicLibraryManager()

    // App-wide ViewModels
    @StateObject private var navidromeVM: NavidromeViewModel
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

        let tempMusicLibraryManager = MusicLibraryManager()
        _musicLibraryManager = StateObject(wrappedValue: tempMusicLibraryManager)
        _navidromeVM = StateObject(wrappedValue: NavidromeViewModel(musicLibraryManager: tempMusicLibraryManager))
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
                .environmentObject(homeScreenManager) // ✅ NEW
                .environmentObject(musicLibraryManager) // ✅ FIXED: DI
                .task {
                    await setupInitialDataLoading()
                }
                .onChange(of: networkMonitor.isConnected) { _, isConnected in
                    Task {
                        await navidromeVM.handleNetworkChange(isOnline: isConnected)
                        await homeScreenManager.handleNetworkChange(isOnline: isConnected) // ✅ NEW
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    handleAppBecameActive()
                }
        }
    }
    
    // ✅ UPDATED: Setup with HomeScreenManager
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
            coverArtManager.configure(service: service)
            homeScreenManager.configure(service: service) // ✅ NEW
            playerVM.updateCoverArtService(coverArtManager)

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
        
        // ✅ NEW: Refresh home screen if needed
        Task {
            await homeScreenManager.refreshIfNeeded()
        }
    }
}
