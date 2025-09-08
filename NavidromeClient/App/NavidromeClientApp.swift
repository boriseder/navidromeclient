import SwiftUI

@main
struct NavidromeClientApp: App {
    @StateObject private var appConfig = AppConfig.shared
    @StateObject private var navidromeVM = NavidromeViewModel()
    @StateObject private var downloadManager = DownloadManager.shared // Use shared instance
    @StateObject private var playerVM: PlayerViewModel
   
    init() {
        // Use the shared DownloadManager instance consistently
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
                .onAppear {
                    setupServices()
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
}
