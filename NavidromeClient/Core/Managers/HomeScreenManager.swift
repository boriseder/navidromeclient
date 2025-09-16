import Foundation

// MARK: - ✅ UPDATED: HomeScreenManager with DiscoveryService

@MainActor
class HomeScreenManager: ObservableObject {
    static let shared = HomeScreenManager()
    
    // MARK: - Home Screen Data (unchanged)
    @Published private(set) var recentAlbums: [Album] = []
    @Published private(set) var newestAlbums: [Album] = []
    @Published private(set) var frequentAlbums: [Album] = []
    @Published private(set) var randomAlbums: [Album] = []
    
    // MARK: - State Management (unchanged)
    @Published private(set) var isLoadingHomeData = false
    @Published private(set) var homeDataError: String?
    @Published private(set) var lastHomeRefresh: Date?
    
    // ✅ NEW: Focused service dependency
    private weak var discoveryService: DiscoveryService?
    
    // ✅ BACKWARDS COMPATIBLE: Keep old service reference
    private weak var legacyService: UnifiedSubsonicService?
    
    // Configuration
    private let homeDataBatchSize = 10
    private let refreshInterval: TimeInterval = 5 * 60 // 5 minutes
    
    private init() {}
    
    // MARK: - ✅ ENHANCED: Dual Configuration Support
    
    /// NEW: Configure with focused DiscoveryService (preferred)
    func configure(discoveryService: DiscoveryService) {
        self.discoveryService = discoveryService
        print("✅ HomeScreenManager configured with focused DiscoveryService")
    }
    
    /// LEGACY: Configure with UnifiedSubsonicService (backwards compatible)
    func configure(service: UnifiedSubsonicService) {
        self.legacyService = service
        // Extract focused service if available
        self.discoveryService = service.getDiscoveryService()
        print("✅ HomeScreenManager configured with legacy service (extracted DiscoveryService)")
    }
    
    // MARK: - ✅ ENHANCED: Smart Service Resolution
    
    private var activeDiscoveryService: DiscoveryService? {
        return discoveryService ?? legacyService?.getDiscoveryService()
    }
    
    // MARK: - ✅ UPGRADED: Home Screen Data Loading
    
    func loadHomeScreenData() async {
        guard let service = activeDiscoveryService else {
            homeDataError = "Discovery service not available"
            return
        }
        
        isLoadingHomeData = true
        homeDataError = nil
        defer { isLoadingHomeData = false }
        
        do {
            // ✅ NEW: Use DiscoveryMix for optimized parallel loading
            let discoveryMix = try await service.getDiscoveryMix(size: homeDataBatchSize * 4)
            
            recentAlbums = Array(discoveryMix.recent.prefix(homeDataBatchSize))
            newestAlbums = Array(discoveryMix.newest.prefix(homeDataBatchSize))
            frequentAlbums = Array(discoveryMix.frequent.prefix(homeDataBatchSize))
            randomAlbums = Array(discoveryMix.random.prefix(homeDataBatchSize))
            
            lastHomeRefresh = Date()
            print("✅ Home screen data loaded via DiscoveryMix: \(discoveryMix.totalCount) total albums")
            
        } catch {
            print("❌ Failed to load discovery mix, falling back to individual calls")
            // Fallback to individual calls
            await loadHomeScreenDataFallback(service: service)
        }
    }
    
    /// ✅ NEW: Advanced recommendations
    func loadRecommendationsFor(album: Album) async -> [Album] {
        guard let service = activeDiscoveryService else { return [] }
        
        do {
            return try await service.getRecommendationsFor(album: album, limit: 10)
        } catch {
            print("❌ Failed to load recommendations for \(album.name): \(error)")
            return []
        }
    }
    
    /// Refresh only random albums (for pull-to-refresh) - now optimized
    func refreshRandomAlbums() async {
        guard let service = activeDiscoveryService else { return }
        
        do {
            randomAlbums = try await service.getRandomAlbums(size: homeDataBatchSize)
            print("✅ Refreshed random albums: \(randomAlbums.count)")
        } catch {
            print("❌ Failed to refresh random albums: \(error)")
        }
    }
    
    // MARK: - ✅ PRIVATE: Fallback Implementation
    
    private func loadHomeScreenDataFallback(service: DiscoveryService) async {
        // Load all sections in parallel (fallback method)
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadRecentAlbums(service: service) }
            group.addTask { await self.loadNewestAlbums(service: service) }
            group.addTask { await self.loadFrequentAlbums(service: service) }
            group.addTask { await self.loadRandomAlbums(service: service) }
        }
        
        lastHomeRefresh = Date()
        print("✅ Home screen data loaded via fallback method")
    }
    
    private func loadRecentAlbums(service: DiscoveryService) async {
        do {
            recentAlbums = try await service.getRecentAlbums(size: homeDataBatchSize)
        } catch {
            print("⚠️ Failed to load recent albums: \(error)")
            handleHomeDataError(error, for: "recent albums")
        }
    }
    
    private func loadNewestAlbums(service: DiscoveryService) async {
        do {
            newestAlbums = try await service.getNewestAlbums(size: homeDataBatchSize)
        } catch {
            print("⚠️ Failed to load newest albums: \(error)")
            handleHomeDataError(error, for: "newest albums")
        }
    }
    
    private func loadFrequentAlbums(service: DiscoveryService) async {
        do {
            frequentAlbums = try await service.getFrequentAlbums(size: homeDataBatchSize)
        } catch {
            print("⚠️ Failed to load frequent albums: \(error)")
            handleHomeDataError(error, for: "frequent albums")
        }
    }
    
    private func loadRandomAlbums(service: DiscoveryService) async {
        do {
            randomAlbums = try await service.getRandomAlbums(size: homeDataBatchSize)
        } catch {
            print("⚠️ Failed to load random albums: \(error)")
            handleHomeDataError(error, for: "random albums")
        }
    }
    
    // MARK: - Rest of implementation unchanged...
    
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
        guard isOnline, activeDiscoveryService != nil else { return }
        
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
        
        print("✅ HomeScreenManager reset completed")
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
