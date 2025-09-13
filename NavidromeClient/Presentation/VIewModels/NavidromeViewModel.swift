//
//  NavidromeViewModel.swift - FIXED VERSION
//  NavidromeClient
//
//  ✅ FIXES:
//  - Removed loadCoverArt method (was causing cache bypass)
//  - All cover art loading now goes through ReactiveCoverArtService
//  - Cleaner separation of concerns
//

import Foundation
import SwiftUI

@MainActor
class NavidromeViewModel: ObservableObject {
    // MARK: - Daten
    @Published var artists: [Artist] = []
    @Published var albums: [Album] = []
    @Published var songs: [Song] = []
    @Published var genres: [Genre] = []
    @Published var albumSongs: [String: [Song]] = [:]

    @Published var isLoading = false
    @Published var connectionStatus = false
    @Published var errorMessage: String?

    @Published var serverType: String?
    @Published var serverVersion: String?
    @Published var subsonicVersion: String?
    @Published var openSubsonic: Bool?

    
    // MARK: - Credentials / UI Bindings
    @Published var scheme: String = "http"
    @Published var host: String = ""
    @Published var port: String = ""
    @Published var username: String = ""
    @Published var password: String = ""

    // MARK: - Dependencies
    private var service: SubsonicService?
    private let downloadManager: DownloadManager

    // MARK: - Init with Dependency Injection
    init(downloadManager: DownloadManager? = nil) {
        // Verwende provided DownloadManager oder shared instance
        self.downloadManager = downloadManager ?? DownloadManager.shared
        loadSavedCredentials()
    }

    // MARK: - Service Management
    func updateService(_ newService: SubsonicService) {
        self.service = newService
    }
    
    func getService() -> SubsonicService? {
        return service
    }

    // MARK: - Credentials Management
    private func loadSavedCredentials() {
        if let creds = AppConfig.shared.getCredentials() {
            self.scheme = creds.baseURL.scheme ?? "http"
            self.host = creds.baseURL.host ?? ""
            self.port = creds.baseURL.port.map { String($0) } ?? ""
            self.username = creds.username
            self.password = creds.password
            
            self.service = SubsonicService(
                baseURL: creds.baseURL,
                username: creds.username,
                password: creds.password
            )
        }
    }

    // MARK: - Enhanced Connection Test using Service
    func testConnection() async {
        guard let url = buildCurrentURL() else {
            connectionStatus = false
            errorMessage = "Ungültige Server-URL"
            return
        }

        isLoading = true
        defer { isLoading = false }

        let tempService = SubsonicService(baseURL: url, username: username, password: password)
        let result = await tempService.testConnection()
        
        switch result {
        case .success(let connectionInfo):
            connectionStatus = true
            errorMessage = nil
            
            // Store server info
            subsonicVersion = connectionInfo.version
            serverType = connectionInfo.type
            serverVersion = connectionInfo.serverVersion
            openSubsonic = connectionInfo.openSubsonic
            
            print("✅ Connection test successful")
            
        case .failure(let connectionError):
            connectionStatus = false
            errorMessage = connectionError.userMessage
            
            print("❌ Connection test failed: \(connectionError)")
        }
    }

    // MARK: - Enhanced Save Credentials using Service
    func saveCredentials() async -> Bool {
        guard let url = buildCurrentURL() else {
            errorMessage = "Ungültige URL"
            return false
        }

        let tempService = SubsonicService(baseURL: url, username: username, password: password)
        
        isLoading = true
        defer { isLoading = false }
        
        let result = await tempService.testConnection()
        
        switch result {
        case .success(let connectionInfo):
            connectionStatus = true
            errorMessage = nil
            
            // Store server info
            subsonicVersion = connectionInfo.version
            serverType = connectionInfo.type
            serverVersion = connectionInfo.serverVersion
            openSubsonic = connectionInfo.openSubsonic
            
            // Save credentials with AppConfig
            AppConfig.shared.configure(baseURL: url, username: username, password: password)

            // Service aktualisieren mit dem getesteten Service
            self.service = tempService

            print("✅ Credentials saved successfully")
            return true
            
        case .failure(let connectionError):
            connectionStatus = false
            errorMessage = connectionError.userMessage
            
            print("❌ Save credentials failed: \(connectionError)")
            return false
        }
    }
    
    // MARK: - Helper
    private func buildCurrentURL() -> URL? {
        let portString = port.isEmpty ? "" : ":\(port)"
        return URL(string: "\(scheme)://\(host)\(portString)")
    }
    
    // MARK: - Service-Aufrufe
    func loadArtists() async {
        guard let service else {
            print("❌ Service nicht verfügbar")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            artists = try await service.getArtists()
        } catch {
            errorMessage = "Failed to load artists: \(error.localizedDescription)"
            print("Failed to load artists: \(error)")
        }
    }

    func loadAlbums(context: ArtistDetailContext) async throws -> [Album] {
        guard let service else { throw URLError(.networkConnectionLost) }
        
        switch context {
        case .artist(let artist):
            return try await service.getAlbumsByArtist(artistId: artist.id)
        case .genre(let genre):
            return try await service.getAlbumsByGenre(genre: genre.value)
        }
    }

    func loadSongs(for albumId: String) async -> [Song] {
        guard let service else { return [] }

        if let cached = albumSongs[albumId], !cached.isEmpty {
            return cached
        }

        do {
            let songs = try await service.getSongs(for: albumId)
            albumSongs[albumId] = songs
            return songs
        } catch {
            errorMessage = "Failed to load songs: \(error.localizedDescription)"
            print("Failed to load songs: \(error)")
            return []
        }
    }

    // ✅ FIX: REMOVED loadCoverArt method
    // This method was causing cache bypass - all cover art loading
    // should go through ReactiveCoverArtService
    
    // OLD CODE (removed):
    // func loadCoverArt(for albumId: String, size: Int = 300) async -> UIImage? {
    //     guard let service else { return nil }
    //     return await service.getCoverArt(for: albumId, size: size)
    // }

    func loadGenres() async {
        guard let service else { return }
        do {
            genres = try await service.getGenres()
        } catch {
            errorMessage = "Failed to load genres: \(error.localizedDescription)"
            print("Failed to load genres: \(error)")
        }
    }

    func search(query: String) async {
        guard let service else { return }

        if query.isEmpty {
            artists = []
            albums = []
            songs = []
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await service.search(query: query)
            artists = result.artists
            albums = result.albums
            songs = result.songs
        } catch {
            artists = []
            albums = []
            songs = []
            errorMessage = "Fehler bei der Suche: \(error.localizedDescription)"
        }
    }

    // MARK: - Reset
    func reset() {
        service = nil
        artists = []
        albums = []
        songs = []
        genres = []
        albumSongs = [:]
        scheme = "http"
        host = ""
        port = ""
        username = ""
        password = ""
        connectionStatus = false
        errorMessage = nil
    }
    
    // MARK: - Enhanced Album-specific methods with Auto-Fallback
    func loadAllAlbums(sortBy: SubsonicService.AlbumSortType = .alphabetical) async {
        guard let service else {
            print("❌ Service nicht verfügbar")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            albums = try await service.getAllAlbums(sortBy: sortBy)
            
            // Cache Album-Metadaten für Offline-Verfügbarkeit
            AlbumMetadataCache.shared.cacheAlbums(albums)
            
        } catch {
            // Enhanced: Handle timeouts immediately
            if let subsonicError = error as? SubsonicError {
                switch subsonicError {
                case .timeout(let endpoint):
                    print("🕐 Timeout detected for \(endpoint) - switching to offline immediately")
                    await handleImmediateOfflineSwitch()
                    await loadOfflineAlbums()
                    return
                case .network(let underlying):
                    if let urlError = underlying as? URLError, urlError.code == .timedOut {
                        print("🕐 Network timeout - switching to offline immediately")
                        await handleImmediateOfflineSwitch()
                        await loadOfflineAlbums()
                        return
                    }
                    fallthrough
                default:
                    if subsonicError.isOfflineError {
                        print("🔄 Server unreachable - switching to offline mode")
                        await handleOfflineFallback()
                        await loadOfflineAlbums()
                        return
                    }
                }
            }
            
            // Check NetworkMonitor state for additional context
            if NetworkMonitor.shared.shouldForceOfflineMode {
                print("🔄 Network issues detected - switching to offline mode")
                await handleOfflineFallback()
                await loadOfflineAlbums()
                return
            }
            
            errorMessage = "Failed to load albums: \(error.localizedDescription)"
            print("Failed to load albums: \(error)")
        }
    }
    
    // Enhanced Artists loading mit Offline-Support
    func loadArtistsWithOfflineSupport() async {
        guard NetworkMonitor.shared.canLoadOnlineContent else {
            print("🔄 Loading artists from offline cache")
            await loadOfflineArtists()
            return
        }
        
        do {
            await loadArtists()
        } catch {
            if let subsonicError = error as? SubsonicError,
               subsonicError.isOfflineError || subsonicError.isRecoverable {
                print("🔄 Artists loading failed - switching to offline")
                await handleImmediateOfflineSwitch()
                await loadOfflineArtists()
            } else {
                errorMessage = "Failed to load artists: \(error.localizedDescription)"
            }
        }
    }
    
    // Enhanced Genres loading mit Offline-Support
    func loadGenresWithOfflineSupport() async {
        guard NetworkMonitor.shared.canLoadOnlineContent else {
            print("🔄 Loading genres from offline cache")
            await loadOfflineGenres()
            return
        }
        
        do {
            await loadGenres()
        } catch {
            if let subsonicError = error as? SubsonicError,
               subsonicError.isOfflineError || subsonicError.isRecoverable {
                print("🔄 Genres loading failed - switching to offline")
                await handleImmediateOfflineSwitch()
                await loadOfflineGenres()
            } else {
                errorMessage = "Failed to load genres: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Offline Fallback Helpers
    
    // NEW: Immediate offline switch for timeouts (no waiting)
    private func handleImmediateOfflineSwitch() async {
        OfflineManager.shared.switchToOfflineMode()
        
        // Immediately update NetworkMonitor to reflect server unreachability
        await NetworkMonitor.shared.checkServerConnection()
        
        // Clear error message since we're handling it gracefully
        errorMessage = nil
        
        print("⚡ Immediate offline switch completed")
    }
    
    // EXISTING: handleOfflineFallback for gradual switches
    private func handleOfflineFallback() async {
        OfflineManager.shared.switchToOfflineMode()
        errorMessage = nil
    }
    
    func loadOfflineAlbums() async {
        // Bei Offline-Fehler: Versuche gecachte Alben zu laden
        let offlineAlbums = OfflineManager.shared.offlineAlbums
        if !offlineAlbums.isEmpty {
            albums = offlineAlbums
            print("📦 Loaded \(albums.count) albums from offline cache")
        } else {
            errorMessage = "No albums available offline"
        }
    }
    
    private func loadOfflineArtists() async {
        // Offline: Zeige nur Artists von heruntergeladenen Alben
        let downloadedAlbums = downloadManager.downloadedAlbums
        let albumIds = Set(downloadedAlbums.map { $0.albumId })
        let cachedAlbums = AlbumMetadataCache.shared.getAlbums(ids: albumIds)
        
        // Extrahiere unique Artists
        let uniqueArtists = Set(cachedAlbums.map { $0.artist })
        let offlineArtists = uniqueArtists.compactMap { artistName in
            Artist(
                id: artistName.replacingOccurrences(of: " ", with: "_"),
                name: artistName,
                coverArt: nil,
                albumCount: cachedAlbums.filter { $0.artist == artistName }.count,
                artistImageUrl: nil
            )
        }
        
        artists = offlineArtists.sorted { $0.name < $1.name }
        print("📦 Loaded \(artists.count) artists from offline cache")
    }
    
    private func loadOfflineGenres() async {
        // Offline: Extrahiere Genres von heruntergeladenen Alben
        let downloadedAlbums = downloadManager.downloadedAlbums
        let albumIds = Set(downloadedAlbums.map { $0.albumId })
        let cachedAlbums = AlbumMetadataCache.shared.getAlbums(ids: albumIds)
        
        let genreGroups = Dictionary(grouping: cachedAlbums) { $0.genre ?? "Unknown" }
        let offlineGenres = genreGroups.map { genreName, albums in
            Genre(
                value: genreName,
                songCount: albums.reduce(0) { $0 + ($1.songCount ?? 0) },
                albumCount: albums.count
            )
        }
        
        genres = offlineGenres.sorted { $0.value < $1.value }
        print("📦 Loaded \(genres.count) genres from offline cache")
    }
}
