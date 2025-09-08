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
    
    // MARK: - Private Methods
    private func loadRecentAlbums(service: SubsonicService) async {
        do {
            recentAlbums = try await service.getRecentAlbums(size: 10)
        } catch {
            print("Failed to load recent albums: \(error)")
            errorMessage = "Fehler beim Laden der kürzlich gespielten Alben"
        }
    }
    
    private func loadNewestAlbums(service: SubsonicService) async {
        do {
            newestAlbums = try await service.getNewestAlbums(size: 10)
        } catch {
            print("Failed to load newest albums: \(error)")
            errorMessage = "Fehler beim Laden der neuen Alben"
        }
    }
    
    private func loadFrequentAlbums(service: SubsonicService) async {
        do {
            frequentAlbums = try await service.getFrequentAlbums(size: 10)
        } catch {
            print("Failed to load frequent albums: \(error)")
            errorMessage = "Fehler beim Laden der oft gespielten Alben"
        }
    }
    
    private func loadRandomAlbums(service: SubsonicService) async {
        do {
            randomAlbums = try await service.getRandomAlbums(size: 10)
        } catch {
            print("Failed to load random albums: \(error)")
            errorMessage = "Fehler beim Laden der zufälligen Alben"
        }
    }
}
