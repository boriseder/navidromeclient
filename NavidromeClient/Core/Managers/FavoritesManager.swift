//
//  FavoritesManager.swift - Lieblingssongs State Management
//  NavidromeClient
//
//  FOCUSED: Verwaltet Lieblingssongs State und koordiniert Service-Aufrufe
//

import Foundation
import SwiftUI

@MainActor
class FavoritesManager: ObservableObject {
    static let shared = FavoritesManager()
    
    // MARK: - Published State
    @Published private(set) var favoriteSongs: [Song] = []
    @Published private(set) var favoriteSongIds: Set<String> = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastRefresh: Date?
    @Published private(set) var errorMessage: String?
    
    // MARK: - Service Dependencies
    private weak var service: UnifiedSubsonicService?
    
    // MARK: - Configuration
    private let refreshInterval: TimeInterval = 5 * 60 // 5 Minuten
    
    private init() {}
    
    // MARK: - Service Configuration
    
    func configure(service: UnifiedSubsonicService) {
        self.service = service
        print("✅ FavoritesManager configured with UnifiedSubsonicService")
    }
    
    // MARK: - Public API
    
    /// Prüft ob ein Song favorisiert ist
    func isFavorite(_ songId: String) -> Bool {
        return favoriteSongIds.contains(songId)
    }
    
    /// Toggle Favorit-Status eines Songs
    func toggleFavorite(_ song: Song) async {
        guard let service = service else {
            errorMessage = "Service not available"
            print("❌ UnifiedSubsonicService not configured")
            return
        }
        
        let songId = song.id
        let wasFavorite = isFavorite(songId)
        
        // Optimistic UI Update
        updateUIOptimistically(song: song, isFavorite: !wasFavorite)
        
        do {
            // ROUTE: Through UnifiedSubsonicService like other managers
            let favoritesService = service.getFavoritesService()
            
            if wasFavorite {
                try await favoritesService.unstarSong(songId)
            } else {
                try await favoritesService.starSong(songId)
            }
            
            // Success - UI ist bereits aktualisiert
            print("✅ Successfully \(wasFavorite ? "unstarred" : "starred") song: \(song.title)")
            errorMessage = nil
            
        } catch {
            // Fehler - Optimistic Update rückgängig machen
            print("❌ Failed to \(wasFavorite ? "unstar" : "star") song: \(error)")
            updateUIOptimistically(song: song, isFavorite: wasFavorite)
            errorMessage = error.localizedDescription
        }
    }
    
    /// Lädt alle Lieblingssongs vom Server
    func loadFavoriteSongs(forceRefresh: Bool = false) async {
        guard let service = service else {
            errorMessage = "Service not available"
            return
        }
        
        guard shouldRefresh || forceRefresh else {
            print("🔄 Favorites are fresh, skipping refresh")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // ROUTE: Through UnifiedSubsonicService like other managers
            let favoritesService = service.getFavoritesService()
            let songs = try await favoritesService.getStarredSongs()
            
            favoriteSongs = songs
            favoriteSongIds = Set(songs.map { $0.id })
            lastRefresh = Date()
            
            print("✅ Loaded \(songs.count) favorite songs")
            
        } catch {
            print("❌ Failed to load favorite songs: \(error)")
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Entfernt alle Favoriten (mit Bestätigung)
    func clearAllFavorites() async {
        guard let service = service else {
            errorMessage = "Service not available"
            return
        }
        
        let songIds = Array(favoriteSongIds)
        guard !songIds.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // ROUTE: Through UnifiedSubsonicService like other managers
            let favoritesService = service.getFavoritesService()
            try await favoritesService.unstarSongs(songIds)
            
            favoriteSongs.removeAll()
            favoriteSongIds.removeAll()
            
            print("✅ Cleared all \(songIds.count) favorites")
            
        } catch {
            print("❌ Failed to clear favorites: \(error)")
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Network State Handling
    
    func handleNetworkChange(isOnline: Bool) async {
        guard isOnline, !isDataFresh else { return }
        
        print("🌐 Network restored - refreshing favorites")
        await loadFavoriteSongs(forceRefresh: true)
    }
    
    // MARK: - Stats & Info
    
    var favoriteCount: Int {
        return favoriteSongs.count
    }
    
    var isDataFresh: Bool {
        guard let lastRefresh = lastRefresh else { return false }
        return Date().timeIntervalSince(lastRefresh) < refreshInterval
    }
    
    private var shouldRefresh: Bool {
        return !isDataFresh
    }
    
    func getFavoriteStats() -> FavoriteStats {
        let totalDuration = favoriteSongs.reduce(0) { $0 + ($1.duration ?? 0) }
        let uniqueArtists = Set(favoriteSongs.compactMap { $0.artist }).count
        let uniqueAlbums = Set(favoriteSongs.compactMap { $0.album }).count
        
        return FavoriteStats(
            songCount: favoriteSongs.count,
            totalDuration: totalDuration,
            uniqueArtists: uniqueArtists,
            uniqueAlbums: uniqueAlbums,
            lastRefresh: lastRefresh
        )
    }
    
    // MARK: - Private Methods
    
    private func updateUIOptimistically(song: Song, isFavorite: Bool) {
        if isFavorite {
            // Add to favorites
            if !favoriteSongIds.contains(song.id) {
                favoriteSongs.append(song)
                favoriteSongIds.insert(song.id)
            }
        } else {
            // Remove from favorites
            favoriteSongs.removeAll { $0.id == song.id }
            favoriteSongIds.remove(song.id)
        }
        
        objectWillChange.send()
    }
    
    // MARK: - Reset
    
    func reset() {
        favoriteSongs.removeAll()
        favoriteSongIds.removeAll()
        isLoading = false
        lastRefresh = nil
        errorMessage = nil
        service = nil
        
        print("✅ FavoritesManager reset completed")
    }
}

// MARK: - Supporting Types

struct FavoriteStats {
    let songCount: Int
    let totalDuration: Int
    let uniqueArtists: Int
    let uniqueAlbums: Int
    let lastRefresh: Date?
    
    var formattedDuration: String {
        let hours = totalDuration / 3600
        let minutes = (totalDuration % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) minutes"
        }
    }
    
    var summary: String {
        return "\(songCount) songs, \(uniqueArtists) artists, \(uniqueAlbums) albums"
    }
}
