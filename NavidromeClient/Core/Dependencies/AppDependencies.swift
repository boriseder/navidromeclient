//
//  AppDependencies.swift
//  NavidromeClient
//
//  Zentralisiert alle App-Dependencies in einem einzigen ObservableObject
//  Eliminiert EnvironmentObject-Explosion und vereinfacht Dependency-Management
//

import Foundation
import SwiftUI

@MainActor
class AppDependencies: ObservableObject {
    
    // MARK: - Core Dependencies
    let appConfig: AppConfig
    let navidromeVM: NavidromeViewModel
    let playerVM: PlayerViewModel
    
    // MARK: - Managers (Singletons bleiben Singletons)
    let downloadManager: DownloadManager
    let audioSessionManager: AudioSessionManager
    let networkMonitor: NetworkMonitor
    let offlineManager: OfflineManager
    let coverArtManager: CoverArtManager
    let homeScreenManager: HomeScreenManager
    let musicLibraryManager: MusicLibraryManager
    
    // MARK: - Initialization
    
    init() {
        // 1. Core App Configuration
        self.appConfig = AppConfig.shared
        
        // 2. Initialize Singletons
        self.downloadManager = DownloadManager.shared
        self.audioSessionManager = AudioSessionManager.shared
        self.networkMonitor = NetworkMonitor.shared
        self.offlineManager = OfflineManager.shared
        self.coverArtManager = CoverArtManager.shared
        self.homeScreenManager = HomeScreenManager.shared
        self.musicLibraryManager = MusicLibraryManager.shared
        
        // 3. Create ViewModels
        let initialService = Self.createInitialService()
        self.navidromeVM = NavidromeViewModel()
        self.playerVM = PlayerViewModel(
            service: initialService,
            downloadManager: downloadManager
        )
        
        // 4. Configure all dependencies
        configureAllDependencies()
        
        print("✅ AppDependencies: All dependencies initialized and configured")
    }
    
    // MARK: - Configuration
    
    private func configureAllDependencies() {
        // Configure services if app is already configured
        if let creds = appConfig.getCredentials() {
            let unifiedService = UnifiedSubsonicService(
                baseURL: creds.baseURL,
                username: creds.username,
                password: creds.password
            )
            
            configureWithService(unifiedService)
        }
        
        // Setup cross-manager dependencies
        configureCrossManagerDependencies()
    }
    
    private func configureWithService(_ service: UnifiedSubsonicService) {
        // Configure ViewModels
        navidromeVM.updateService(service)
        playerVM.updateService(service)
        
        // Configure Managers
        let mediaService = service.getMediaService()
        coverArtManager.configure(mediaService: mediaService)
        downloadManager.configure(service: service)
        downloadManager.configure(coverArtManager: coverArtManager)
        homeScreenManager.configure(service: service)
        musicLibraryManager.configure(service: service)
        
        print("✅ AppDependencies: All dependencies configured with UnifiedSubsonicService")
    }
    
    private func configureCrossManagerDependencies() {
        // NetworkMonitor configuration
        // Note: ConnectionManager is internal to NavidromeViewModel, so we skip this for now
        
        // DownloadManager ↔ CoverArtManager integration already handled above
        
        print("✅ AppDependencies: Cross-manager dependencies configured")
    }
    
    // MARK: - Service Management
    
    func updateWithNewCredentials() {
        if let creds = appConfig.getCredentials() {
            let unifiedService = UnifiedSubsonicService(
                baseURL: creds.baseURL,
                username: creds.username,
                password: creds.password
            )
            
            configureWithService(unifiedService)
        }
    }
    
    func performFactoryReset() async {
        await appConfig.performFactoryReset()
        
        // Reset all managers
        coverArtManager.clearMemoryCache()
        downloadManager.deleteAllDownloads()
        offlineManager.performCompleteReset()
        
        // Reset ViewModels
        navidromeVM.reset()
        
        print("✅ AppDependencies: Factory reset completed")
    }
    
    // MARK: - Convenience Access (Optional - macht Views noch einfacher)
    
    // Most used properties
    var isConfigured: Bool { appConfig.isConfigured }
    var isConnected: Bool { networkMonitor.isConnected }
    var isOfflineMode: Bool { offlineManager.isOfflineMode }
    var currentSong: Song? { playerVM.currentSong }
    var isPlaying: Bool { playerVM.isPlaying }
    
    // Most used collections
    var albums: [Album] { musicLibraryManager.albums }
    var artists: [Artist] { musicLibraryManager.artists }
    var genres: [Genre] { musicLibraryManager.genres }
    var downloadedAlbums: [DownloadedAlbum] { downloadManager.downloadedAlbums }
    
    // MARK: - Helper Methods
    
    private static func createInitialService() -> UnifiedSubsonicService? {
        guard let creds = AppConfig.shared.getCredentials() else { return nil }
        
        return UnifiedSubsonicService(
            baseURL: creds.baseURL,
            username: creds.username,
            password: creds.password
        )
    }
}

// MARK: - Debugging & Diagnostics

extension AppDependencies {
    
    func printDependencyDiagnostics() {
        print("""
        📊 APP DEPENDENCIES DIAGNOSTICS:
        
        Configuration:
        - App Configured: \(appConfig.isConfigured)
        - Network Connected: \(networkMonitor.isConnected)
        - Offline Mode: \(offlineManager.isOfflineMode)
        
        Library:
        - Albums: \(musicLibraryManager.albums.count)
        - Artists: \(musicLibraryManager.artists.count)
        - Genres: \(musicLibraryManager.genres.count)
        
        Downloads:
        - Downloaded Albums: \(downloadManager.downloadedAlbums.count)
        - Active Downloads: \(downloadManager.isDownloading.count)
        
        Player:
        - Current Song: \(playerVM.currentSong?.title ?? "None")
        - Is Playing: \(playerVM.isPlaying)
        
        Cache:
        - Cover Art Cache: \(coverArtManager.getCacheStats().memoryCount) images
        """)
    }
    
    #if DEBUG
    func debugForceServiceReconfiguration() {
        Task {
            print("🔄 DEBUG: Forcing service reconfiguration...")
            configureAllDependencies()
        }
    }
    #endif
}
