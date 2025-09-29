//
//  ExploreManager.swift - FIXED: Pure Facade Pattern
//  NavidromeClient
//
//
//  ExploreManager.swift
//  Manages home screen discovery content
//  Responsibilities: Load and cache recent/newest/frequent/random albums
//  Provides business logic layer between views and service


import Foundation

@MainActor
class ExploreManager: ObservableObject {
    static let shared = ExploreManager()
    
    // MARK: - Home Screen Data
    @Published private(set) var recentAlbums: [Album] = []
    @Published private(set) var newestAlbums: [Album] = []
    @Published private(set) var frequentAlbums: [Album] = []
    @Published private(set) var randomAlbums: [Album] = []
    
    // MARK: - State Management
    @Published private(set) var isLoadingExploreData = false
    @Published private(set) var exploreError: String?
    @Published private(set) var lastHomeRefresh: Date?
    
    private weak var service: UnifiedSubsonicService?
    
    // Configuration
    private let exploreDataBatchSize = 10
    private let refreshInterval: TimeInterval = 5 * 60 // 5 minutes
    
    private init() {}
    
    // MARK: - Configuration
    
    func configure(service: UnifiedSubsonicService) {
        self.service = service
        print("ExploreManager configured with UnifiedSubsonicService facade")
    }
    
    // MARK: - HOME SCREEN DATA LOADING
    
    func loadExploreData() async {
        guard let service = service else {
            exploreError = "Service not available"
            return
        }
        
        isLoadingExploreData = true
        exploreError = nil
        defer { isLoadingExploreData = false }
        
        do {
            let discoveryMix = try await service.getDiscoveryMix(size: exploreDataBatchSize * 4)
            
            recentAlbums = Array(discoveryMix.recent.prefix(exploreDataBatchSize))
            newestAlbums = Array(discoveryMix.newest.prefix(exploreDataBatchSize))
            frequentAlbums = Array(discoveryMix.frequent.prefix(exploreDataBatchSize))
            randomAlbums = Array(discoveryMix.random.prefix(exploreDataBatchSize))
            
            lastHomeRefresh = Date()
            print("Home screen data loaded: \(discoveryMix.totalCount) total albums")
            
        } catch {
            print("Failed to load discovery mix, falling back to individual calls")
            await loadExploreDataFallback()
        }
    }
    
    func loadRecommendationsFor(album: Album) async -> [Album] {
        guard let service = service else { return [] }
        
        do {
            return try await service.getRecommendationsFor(album: album, limit: 10)
        } catch {
            print("Failed to load recommendations for \(album.name): \(error)")
            return []
        }
    }
    
    func refreshRandomAlbums() async {
        guard let service = service else { return }
        
        do {
            randomAlbums = try await service.getRandomAlbums(size: exploreDataBatchSize)
            print("Refreshed random albums: \(randomAlbums.count)")
        } catch {
            print("Failed to refresh random albums: \(error)")
        }
    }
    
    // MARK: - FALLBACK IMPLEMENTATION
    
    private func loadExploreDataFallback() async {
        guard let service = service else { return }
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadRecentAlbums() }
            group.addTask { await self.loadNewestAlbums() }
            group.addTask { await self.loadFrequentAlbums() }
            group.addTask { await self.loadRandomAlbums() }
        }
        
        lastHomeRefresh = Date()
        print("Home screen data loaded via fallback method")
    }
    
    private func loadRecentAlbums() async {
        guard let service = service else { return }
        
        do {
            recentAlbums = try await service.getRecentAlbums(size: exploreDataBatchSize)
        } catch {
            print("Failed to load recent albums: \(error)")
            handleExploreDataError(error, for: "recent albums")
        }
    }
    
    private func loadNewestAlbums() async {
        guard let service = service else { return }
        
        do {
            newestAlbums = try await service.getNewestAlbums(size: exploreDataBatchSize)
        } catch {
            print("Failed to load newest albums: \(error)")
            handleExploreDataError(error, for: "newest albums")
        }
    }
    
    private func loadFrequentAlbums() async {
        guard let service = service else { return }
        
        do {
            frequentAlbums = try await service.getFrequentAlbums(size: exploreDataBatchSize)
        } catch {
            print("Failed to load frequent albums: \(error)")
            handleExploreDataError(error, for: "frequent albums")
        }
    }
    
    private func loadRandomAlbums() async {
        guard let service = service else { return }
        
        do {
            randomAlbums = try await service.getRandomAlbums(size: exploreDataBatchSize)
        } catch {
            print("Failed to load random albums: \(error)")
            handleExploreDataError(error, for: "random albums")
        }
    }
    
    // MARK: - UTILITY METHODS
    
    func refreshIfNeeded() async {
        guard shouldRefreshHomeData else { return }
        await loadExploreData()
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
            await loadExploreData()
        }
    }
    
    func reset() {
        recentAlbums = []
        newestAlbums = []
        frequentAlbums = []
        randomAlbums = []
        
        isLoadingExploreData = false
        exploreError = nil
        lastHomeRefresh = nil
        
        print("ExploreManager reset completed")
    }
    
    private func handleExploreDataError(_ error: Error, for section: String) {
        if case SubsonicError.unauthorized = error {
            exploreError = "Authentication failed"
        } else if case SubsonicError.network = error {
            print("Network error loading \(section): \(error)")
        }
    }
    
    func getExploreStats() -> ExploreStats {
        return ExploreStats(
            recentCount: recentAlbums.count,
            newestCount: newestAlbums.count,
            frequentCount: frequentAlbums.count,
            randomCount: randomAlbums.count,
            isLoading: isLoadingExploreData,
            lastRefresh: lastHomeRefresh,
            hasError: exploreError != nil
        )
    }
}

// MARK: - Supporting Types

struct ExploreStats {
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
