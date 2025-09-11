//
//  HomeScreenViewModel.swift
//  NavidromeClient
//
//  Created by Boris Eder on 04.09.25.
//

import Foundation
import SwiftUI

@MainActor
class HomeScreenViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var recentAlbums: [Album] = []
    @Published var newestAlbums: [Album] = []
    @Published var frequentAlbums: [Album] = []
    @Published var randomAlbums: [Album] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies (will be set from the view)
    private weak var navidromeVM: NavidromeViewModel?
    
    init() {
        // Empty init - dependencies will be injected
    }
    
    // MARK: - Dependency Injection
    func configure(with navidromeVM: NavidromeViewModel) {
        self.navidromeVM = navidromeVM
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
        
        async let recentTask = loadRecentAlbums(service: service)
        async let newestTask = loadNewestAlbums(service: service)
        async let frequentTask = loadFrequentAlbums(service: service)
        async let randomTask = loadRandomAlbums(service: service)
        
        _ = await (recentTask, newestTask, frequentTask, randomTask)
    }
    
    func refreshRandomAlbums() async {
        guard let navidromeVM = navidromeVM,
              let service = navidromeVM.getService() else { return }
        await loadRandomAlbums(service: service)
    }
    
    func loadCoverArt(for albumId: String, size: Int = 200) async -> UIImage? {
        guard let navidromeVM = navidromeVM else { return nil }
        return await navidromeVM.loadCoverArt(for: albumId, size: size)
    }
    
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
