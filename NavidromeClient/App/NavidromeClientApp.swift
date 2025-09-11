import SwiftUI

@main
struct NavidromeClientApp: App {
    // App Delegate für Background Audio
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var appConfig = AppConfig.shared
    @StateObject private var navidromeVM = NavidromeViewModel()
    @StateObject private var downloadManager = DownloadManager.shared
    @StateObject private var playerVM: PlayerViewModel
    @StateObject private var audioSessionManager = AudioSessionManager.shared
    
    // Network & Offline Management
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var offlineManager = OfflineManager.shared
   
    init() {
        // Initialize PlayerViewModel with dependencies
        let service: SubsonicService?
        if let creds = AppConfig.shared.getCredentials() {
            service = SubsonicService(baseURL: creds.baseURL,
                                      username: creds.username,
                                      password: creds.password)
        } else {
            service = nil
        }

        _downloadManager = StateObject(wrappedValue: DownloadManager.shared)
        _playerVM = StateObject(wrappedValue: PlayerViewModel(service: service, downloadManager: DownloadManager.shared))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(navidromeVM)
                .environmentObject(playerVM)
                .environmentObject(downloadManager)
                .environmentObject(appConfig)
                .environmentObject(audioSessionManager)
                .environmentObject(networkMonitor)  // NEU
                .environmentObject(offlineManager)  // NEU
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
    
    private func setupServices() {
        if let creds = appConfig.getCredentials() {
            let service = SubsonicService(
                baseURL: creds.baseURL,
                username: creds.username,
                password: creds.password
            )
            navidromeVM.updateService(service)
            playerVM.updateService(service)
        }
    }
    
    private func setupNetworkMonitoring() {
        // Network Monitor ist bereits als Singleton aktiv
        print("🌐 Network monitoring active")
    }
    
    private func handleAppBecameActive() {
        print("📱 App became active - refreshing audio session")
        // AudioSessionManager wird automatisch reaktiviert
    }
    
    private func handleAppWillResignActive() {
        print("📱 App will resign active - ensuring background audio")
        // Stelle sicher, dass Audio im Hintergrund läuft
        if playerVM.isPlaying {
            print("🎵 Music is playing - should continue in background")
        }
    }
    

}
