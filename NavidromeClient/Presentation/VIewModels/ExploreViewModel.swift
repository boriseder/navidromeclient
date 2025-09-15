//
//  ExploreViewModel.swift - FIXED for New Image API
//  NavidromeClient
//
//  ✅ FIXED: Updated to use new convenience methods instead of direct ImageType
//

import Foundation
import SwiftUI

@MainActor
class ExploreViewModel: ObservableObject {
    // MARK: - Published Properties (unchanged)
    @Published var recentAlbums: [Album] = []
    @Published var newestAlbums: [Album] = []
    @Published var frequentAlbums: [Album] = []
    @Published var randomAlbums: [Album] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies (unchanged)
    private weak var navidromeVM: NavidromeViewModel?
    private weak var coverArtService: CoverArtManager?
    
    init() {
        // Empty init - dependencies will be injected
    }
    
    // MARK: - ✅ FIX: Enhanced Dependency Injection (unchanged)
    func configure(with navidromeVM: NavidromeViewModel, coverArtService: CoverArtManager) {
        self.navidromeVM = navidromeVM
        self.coverArtService = coverArtService
    }
    
    // MARK: - Public Methods (unchanged)
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
    
    // ✅ FIXED: Updated loadCoverArt method to use convenience API
    func loadCoverArt(for albumId: String, size: Int = 200) async -> UIImage? {
        guard let coverArtService = coverArtService else { return nil }
        
        // ✅ FIXED: Use convenience method with Album object if possible
        if let albumMetadata = AlbumMetadataCache.shared.getAlbum(id: albumId) {
            return await coverArtService.loadAlbumImage(album: albumMetadata, size: size)
        } else {
            // ✅ GRACEFUL DEGRADATION: Return nil instead of creating fallback Album
            // This encourages proper data flow through AlbumMetadataCache
            print("⚠️ Album metadata not found for ID: \(albumId)")
            return nil
        }
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
