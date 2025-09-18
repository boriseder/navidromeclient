//
//  HomeScreenManager.swift - SIMPLIFIED: Direct UnifiedSubsonicService
//  NavidromeClient
//
//   REMOVED: Legacy service support, dual configuration
//   SIMPLIFIED: Single service dependency via UnifiedSubsonicService
//   CLEAN: Direct access to service.discoveryService
//

import Foundation

@MainActor
class HomeScreenManager: ObservableObject {
    static let shared = HomeScreenManager()
    
    // MARK: - Home Screen Data
    @Published private(set) var recentAlbums: [Album] = []
    @Published private(set) var newestAlbums: [Album] = []
    @Published private(set) var frequentAlbums: [Album] = []
    @Published private(set) var randomAlbums: [Album] = []
    
    // MARK: - State Management
    @Published private(set) var isLoadingHomeData = false
    @Published private(set) var homeDataError: String?
    @Published private(set) var lastHomeRefresh: Date?
    
    //  SINGLE SERVICE DEPENDENCY
    private weak var service: UnifiedSubsonicService?
    
    // Configuration
    private let homeDataBatchSize = 10
    private let refreshInterval: TimeInterval = 5 * 60 // 5 minutes
    
    private init() {}
    
    // MARK: -  SIMPLIFIED: Single Configuration Method
    
    func configure(service: UnifiedSubsonicService) {
        self.service = service
        print(" HomeScreenManager configured with UnifiedSubsonicService")
    }
    
    // MARK: -  HOME SCREEN DATA LOADING
    
    func loadHomeScreenData() async {
        guard let service = service else {
            homeDataError = "Service not available"
            return
        }
        
        isLoadingHomeData = true
        homeDataError = nil
        defer { isLoadingHomeData = false }
        
        do {
            //  DIRECT ACCESS: service.discoveryService
            let discoveryMix = try await service.discoveryService.getDiscoveryMix(size: homeDataBatchSize * 4)
            
            recentAlbums = Array(discoveryMix.recent.prefix(homeDataBatchSize))
            newestAlbums = Array(discoveryMix.newest.prefix(homeDataBatchSize))
            frequentAlbums = Array(discoveryMix.frequent.prefix(homeDataBatchSize))
            randomAlbums = Array(discoveryMix.random.prefix(homeDataBatchSize))
            
            lastHomeRefresh = Date()
            print(" Home screen data loaded: \(discoveryMix.totalCount) total albums")
            
        } catch {
            print("❌ Failed to load discovery mix, falling back to individual calls")
            await loadHomeScreenDataFallback()
        }
    }
    
    func loadRecommendationsFor(album: Album) async -> [Album] {
        guard let service = service else { return [] }
        
        do {
            return try await service.discoveryService.getRecommendationsFor(album: album, limit: 10)
        } catch {
            print("❌ Failed to load recommendations for \(album.name): \(error)")
            return []
        }
    }
    
    func refreshRandomAlbums() async {
        guard let service = service else { return }
        
        do {
            randomAlbums = try await service.discoveryService.getRandomAlbums(size: homeDataBatchSize)
            print(" Refreshed random albums: \(randomAlbums.count)")
        } catch {
            print("❌ Failed to refresh random albums: \(error)")
        }
    }
    
    // MARK: -  SIMPLIFIED: Fallback Implementation
    
    private func loadHomeScreenDataFallback() async {
        guard let service = service else { return }
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadRecentAlbums() }
            group.addTask { await self.loadNewestAlbums() }
            group.addTask { await self.loadFrequentAlbums() }
            group.addTask { await self.loadRandomAlbums() }
        }
        
        lastHomeRefresh = Date()
        print(" Home screen data loaded via fallback method")
    }
    
    private func loadRecentAlbums() async {
        guard let service = service else { return }
        
        do {
            recentAlbums = try await service.discoveryService.getRecentAlbums(size: homeDataBatchSize)
        } catch {
            print("⚠️ Failed to load recent albums: \(error)")
            handleHomeDataError(error, for: "recent albums")
        }
    }
    
    private func loadNewestAlbums() async {
        guard let service = service else { return }
        
        do {
            newestAlbums = try await service.discoveryService.getNewestAlbums(size: homeDataBatchSize)
        } catch {
            print("⚠️ Failed to load newest albums: \(error)")
            handleHomeDataError(error, for: "newest albums")
        }
    }
    
    private func loadFrequentAlbums() async {
        guard let service = service else { return }
        
        do {
            frequentAlbums = try await service.discoveryService.getFrequentAlbums(size: homeDataBatchSize)
        } catch {
            print("⚠️ Failed to load frequent albums: \(error)")
            handleHomeDataError(error, for: "frequent albums")
        }
    }
    
    private func loadRandomAlbums() async {
        guard let service = service else { return }
        
        do {
            randomAlbums = try await service.discoveryService.getRandomAlbums(size: homeDataBatchSize)
        } catch {
            print("⚠️ Failed to load random albums: \(error)")
            handleHomeDataError(error, for: "random albums")
        }
    }
    
    // MARK: -  UTILITY METHODS
    
    func refreshIfNeeded() async {
        guard shouldRefreshHomeData else { return }
        await loadHomeScreenData()
    }
    
    private var shouldRefreshHomeData: Bool {
        guard let lastRefresh = lastHomeRefresh else { return true }
        return Date().timeIntervalSince(lastRefresh) > refreshInterval
    }
    
    var isHomeDataFresh: Bool {
        guard let lastRefresh = lastHomeRefresh else { return false }
        return Date().timeIntervalSince(lastRefresh) < refreshInterval
    }
    
    var hasHomeScreenData: Bool {
        return !recentAlbums.isEmpty ||
               !newestAlbums.isEmpty ||
               !frequentAlbums.isEmpty ||
               !randomAlbums.isEmpty
    }
    
    func handleNetworkChange(isOnline: Bool) async {
        guard isOnline, service != nil else { return }
        
        if !isHomeDataFresh {
            await loadHomeScreenData()
        }
    }
    
    func reset() {
        recentAlbums = []
        newestAlbums = []
        frequentAlbums = []
        randomAlbums = []
        
        isLoadingHomeData = false
        homeDataError = nil
        lastHomeRefresh = nil
        
        print(" HomeScreenManager reset completed")
    }
    
    private func handleHomeDataError(_ error: Error, for section: String) {
        if case SubsonicError.unauthorized = error {
            homeDataError = "Authentication failed"
        } else if case SubsonicError.network = error {
            print("🌐 Network error loading \(section): \(error)")
        }
    }
    
    func getHomeScreenStats() -> HomeScreenStats {
        return HomeScreenStats(
            recentCount: recentAlbums.count,
            newestCount: newestAlbums.count,
            frequentCount: frequentAlbums.count,
            randomCount: randomAlbums.count,
            isLoading: isLoadingHomeData,
            lastRefresh: lastHomeRefresh,
            hasError: homeDataError != nil
        )
    }
}

// MARK: - Supporting Types (unchanged)

struct HomeScreenStats {
    let recentCount: Int
    let newestCount: Int
    let frequentCount: Int
    let randomCount: Int
    let isLoading: Bool
    let lastRefresh: Date?
    let hasError: Bool
    
    var totalCount: Int {
        return recentCount + newestCount + frequentCount + randomCount
    }
    
    var isEmpty: Bool {
        return totalCount == 0
    }
    
    var summary: String {
        if isEmpty {
            return "No home screen content loaded"
        }
        return "Recent: \(recentCount), Newest: \(newestCount), Frequent: \(frequentCount), Random: \(randomCount)"
    }
}
