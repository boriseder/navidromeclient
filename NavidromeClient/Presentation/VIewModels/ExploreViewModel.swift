//
//  ExploreViewModel.swift - FIXED VERSION
//  NavidromeClient
//
//  ✅ FIXES:
//  - Removed bypass call to navidromeVM.loadCoverArt()
//  - Now uses ReactiveCoverArtService.loadImage() async method
//  - Maintains consistency with unified caching architecture
//

import Foundation
import SwiftUI

@MainActor
class ExploreViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var recentAlbums: [Album] = []
    @Published var newestAlbums: [Album] = []
    @Published var frequentAlbums: [Album] = []
    @Published var randomAlbums: [Album] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies (will be set from the view)
    private weak var navidromeVM: NavidromeViewModel?
    private weak var coverArtService: ReactiveCoverArtService?
    
    init() {
        // Empty init - dependencies will be injected
    }
    
    // MARK: - ✅ FIX: Enhanced Dependency Injection
    func configure(with navidromeVM: NavidromeViewModel, coverArtService: ReactiveCoverArtService) {
        self.navidromeVM = navidromeVM
        self.coverArtService = coverArtService
    }
    
    // MARK: - Public Methods
    func loadHomeScreenData() async {
        guard let navidromeVM = navidromeVM,
              let service = navidromeVM.getService() else {
            print("Service nicht verfügbar")
            return
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        // Führe Tasks parallel aus
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadRecentAlbums(service: service) }
            group.addTask { await self.loadNewestAlbums(service: service) }
            group.addTask { await self.loadFrequentAlbums(service: service) }
            group.addTask { await self.loadRandomAlbums(service: service) }
        }
    }
    
    func refreshRandomAlbums() async {
        guard let navidromeVM = navidromeVM,
              let service = navidromeVM.getService() else { return }
        await loadRandomAlbums(service: service)
    }
    
    // ✅ FIX: Updated loadCoverArt method to use ReactiveCoverArtService
    func loadCoverArt(for albumId: String, size: Int = 200) async -> UIImage? {
        // OLD BYPASS CODE (removed):
        // guard let navidromeVM = navidromeVM else { return nil }
        // return await navidromeVM.loadCoverArt(for: albumId, size: size)
        
        // ✅ NEW: Use ReactiveCoverArtService async API
        guard let coverArtService = coverArtService else { return nil }
        return await coverArtService.loadImage(for: albumId, size: size)
    }
    
    // MARK: - Private Album Loading Methods (unchanged)
    
    private func loadRecentAlbums(service: SubsonicService) async {
        do {
            recentAlbums = try await service.getRecentAlbums(size: 10)
            print("✅ Loaded \(recentAlbums.count) recent albums")
        } catch {
            print("⚠️ Failed to load recent albums: \(error)")
            recentAlbums = [] // Fallback zu leerem Array
            // Nur bei kritischen Fehlern Error Message setzen
            if case SubsonicError.unauthorized = error {
                errorMessage = "Anmeldung fehlgeschlagen"
            }
        }
    }

    private func loadNewestAlbums(service: SubsonicService) async {
        do {
            newestAlbums = try await service.getNewestAlbums(size: 10)
            print("✅ Loaded \(newestAlbums.count) newest albums")
        } catch {
            print("⚠️ Failed to load newest albums: \(error)")
            newestAlbums = []
            if case SubsonicError.unauthorized = error {
                errorMessage = "Anmeldung fehlgeschlagen"
            }
        }
    }

    private func loadFrequentAlbums(service: SubsonicService) async {
        do {
            frequentAlbums = try await service.getFrequentAlbums(size: 10)
            print("✅ Loaded \(frequentAlbums.count) frequent albums")
        } catch {
            print("⚠️ Failed to load frequent albums: \(error)")
            frequentAlbums = []
            if case SubsonicError.unauthorized = error {
                errorMessage = "Anmeldung fehlgeschlagen"
            }
        }
    }

    private func loadRandomAlbums(service: SubsonicService) async {
        do {
            randomAlbums = try await service.getRandomAlbums(size: 10)
            print("✅ Loaded \(randomAlbums.count) random albums")
        } catch {
            print("⚠️ Failed to load random albums: \(error)")
            randomAlbums = []
            if case SubsonicError.unauthorized = error {
                errorMessage = "Anmeldung fehlgeschlagen"
            }
        }
    }
}
