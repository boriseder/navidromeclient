//
//  NavidromeClientApp.swift - FIXED: ViewModel init
//  NavidromeClient
//
//  ✅ FIXED: ViewModels use singletons internally, no arguments needed
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
    
    // ✅ REMOVED: No longer needed as EnvironmentObject since it's a singleton
    // @StateObject private var musicLibraryManager = MusicLibraryManager.shared

    // ✅ FIXED: App-wide ViewModels with proper initialization
    @StateObject private var navidromeVM: NavidromeViewModel
    @StateObject private var playerVM: PlayerViewModel
    
    init() {
        // ✅ FIXED: Create ViewModels with proper dependencies
        let service: SubsonicService?
        if let creds = AppConfig.shared.getCredentials() {
            service = SubsonicService(baseURL: creds.baseURL,
                                      username: creds.username,
                                      password: creds.password)
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
                // ✅ REMOVED: musicLibraryManager (not needed as EnvironmentObject)
                .task {
                    await setupInitialDataLoading()
                }
                .onChange(of: networkMonitor.isConnected) { _, isConnected in
                    Task {
                        await navidromeVM.handleNetworkChange(isOnline: isConnected)
                        await homeScreenManager.handleNetworkChange(isOnline: isConnected)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    handleAppBecameActive()
                }
        }
    }
    
    private func setupInitialDataLoading() async {
        guard appConfig.isConfigured else {
            print("⚠️ App not configured - skipping data loading")
            return
        }
        
        setupServices()
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
            homeScreenManager.configure(service: service)
            playerVM.updateCoverArtService(coverArtManager)

            print("✅ All services configured with credentials")
        }
    }
    
    private func handleAppBecameActive() {
        if !navidromeVM.isDataFresh {
            Task {
                await navidromeVM.handleNetworkChange(isOnline: networkMonitor.isConnected)
            }
        }
        
        Task {
            await homeScreenManager.refreshIfNeeded()
        }
    }
}
