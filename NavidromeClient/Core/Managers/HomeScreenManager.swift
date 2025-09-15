//
//  HomeScreenManager.swift
//  NavidromeClient
//
//  Created by Boris Eder on 16.09.25.
//


//
//  HomeScreenManager.swift - Home Screen Data Specialist
//  NavidromeClient
//
//  ✅ CLEAN: Single Responsibility - Home Screen Content
//  ✅ EXTRACTS: All ExploreViewModel logic into dedicated manager
//

import Foundation
import SwiftUI

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
    
    // Dependencies
    private weak var service: SubsonicService?
    
    // Configuration
    private let homeDataBatchSize = 10
    private let refreshInterval: TimeInterval = 5 * 60 // 5 minutes
    
    private init() {}
    
    // MARK: - Configuration
    
    func configure(service: SubsonicService) {
        self.service = service
    }
    
    // MARK: - ✅ HOME SCREEN DATA LOADING
    
    /// Load all home screen data in parallel
    func loadHomeScreenData() async {
        guard let service = service else {
            homeDataError = "Service not available"
            return
        }
        
        isLoadingHomeData = true
        homeDataError = nil
        defer { isLoadingHomeData = false }
        
        // Load all sections in parallel for optimal performance
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadRecentAlbums(service: service) }
            group.addTask { await self.loadNewestAlbums(service: service) }
            group.addTask { await self.loadFrequentAlbums(service: service) }
            group.addTask { await self.loadRandomAlbums(service: service) }
        }
        
        lastHomeRefresh = Date()
        print("✅ Home screen data loaded")
    }
    
    /// Refresh only random albums (for pull-to-refresh)
    func refreshRandomAlbums() async {
        guard let service = service else { return }
        await loadRandomAlbums(service: service)
    }
    
    /// Refresh all home data if stale
    func refreshIfNeeded() async {
        guard shouldRefreshHomeData else { return }
        await loadHomeScreenData()
    }
    
    // MARK: - ✅ DATA FRESHNESS
    
    private var shouldRefreshHomeData: Bool {
        guard let lastRefresh = lastHomeRefresh else { return true }
        return Date().timeIntervalSince(lastRefresh) > refreshInterval
    }
    
    var isHomeDataFresh: Bool {
        guard let lastRefresh = lastHomeRefresh else { return false }
        return Date().timeIntervalSince(lastRefresh) < refreshInterval
    }
    
    // MARK: - ✅ PRIVATE LOADING METHODS
    
    private func loadRecentAlbums(service: SubsonicService) async {
        do {
            recentAlbums = try await service.getRecentAlbums(size: homeDataBatchSize)
            print("✅ Loaded \(recentAlbums.count) recent albums")
        } catch {
            print("⚠️ Failed to load recent albums: \(error)")
            handleHomeDataError(error, for: "recent albums")
        }
    }
    
    private func loadNewestAlbums(service: SubsonicService) async {
        do {
            newestAlbums = try await service.getNewestAlbums(size: homeDataBatchSize)
            print("✅ Loaded \(newestAlbums.count) newest albums")
        } catch {
            print("⚠️ Failed to load newest albums: \(error)")
            handleHomeDataError(error, for: "newest albums")
        }
    }
    
    private func loadFrequentAlbums(service: SubsonicService) async {
        do {
            frequentAlbums = try await service.getFrequentAlbums(size: homeDataBatchSize)
            print("✅ Loaded \(frequentAlbums.count) frequent albums")
        } catch {
            print("⚠️ Failed to load frequent albums: \(error)")
            handleHomeDataError(error, for: "frequent albums")
        }
    }
    
    private func loadRandomAlbums(service: SubsonicService) async {
        do {
            randomAlbums = try await service.getRandomAlbums(size: homeDataBatchSize)
            print("✅ Loaded \(randomAlbums.count) random albums")
        } catch {
            print("⚠️ Failed to load random albums: \(error)")
            handleHomeDataError(error, for: "random albums")
        }
    }
    
    // MARK: - ✅ ERROR HANDLING
    
    private func handleHomeDataError(_ error: Error, for section: String) {
        // Only set error for critical failures, not empty results
        if case SubsonicError.unauthorized = error {
            homeDataError = "Authentication failed"
        } else if case SubsonicError.network = error {
            // Network errors are recoverable, don't show to user
            print("🌐 Network error loading \(section): \(error)")
        }
    }
    
    // MARK: - ✅ STATISTICS & STATUS
    
    /// Get home screen content statistics
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
    
    /// Check if any home screen data is available
    var hasHomeScreenData: Bool {
        return !recentAlbums.isEmpty ||
               !newestAlbums.isEmpty ||
               !frequentAlbums.isEmpty ||
               !randomAlbums.isEmpty
    }
    
    // MARK: - ✅ NETWORK HANDLING
    
    func handleNetworkChange(isOnline: Bool) async {
        guard isOnline, let service = service else { return }
        
        // Refresh if data is stale when network comes back
        if !isHomeDataFresh {
            await loadHomeScreenData()
        }
    }
    
    // MARK: - ✅ RESET (for logout/factory reset)
    
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
}

// MARK: - ✅ SUPPORTING TYPES

struct HomeScreenStats {
    let recentCount: Int
    let newestCount: Int
    let frequentCount: Int
    let randomCount: Int
    let isLoading: Bool
    let lastRefresh: Date?
    let hasError: Bool
    
    var totalAlbums: Int {
        return recentCount + newestCount + frequentCount + randomCount
    }
    
    var isEmpty: Bool {
        return totalAlbums == 0
    }
    
    var summary: String {
        if isEmpty {
            return "No home screen content"
        }
        
        var parts: [String] = []
        if recentCount > 0 { parts.append("\(recentCount) recent") }
        if newestCount > 0 { parts.append("\(newestCount) newest") }
        if frequentCount > 0 { parts.append("\(frequentCount) frequent") }
        if randomCount > 0 { parts.append("\(randomCount) random") }
        
        return parts.joined(separator: ", ")
    }
}