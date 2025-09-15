//
//  NavidromeViewModel.swift - Enhanced with Background Sequential Loading
//  NavidromeClient
//
//  ✅ ENHANCED: Centralized data loading with background sequential loading
//

import Foundation
import SwiftUI

@MainActor
class NavidromeViewModel: ObservableObject {
    // MARK: - Existing Properties
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

    // MARK: - NEW: Data Loading State Management
    @Published var hasLoadedInitialData = false
    @Published var lastRefreshDate: Date?
    @Published var isLoadingInBackground = false
    @Published var backgroundLoadingProgress: String = ""
    
    // Track what has been loaded
    private var loadedDataTypes: Set<DataType> = []
    
    enum DataType {
        case albums, artists, genres
        
        var displayName: String {
            switch self {
            case .albums: return "Albums"
            case .artists: return "Artists"
            case .genres: return "Genres"
            }
        }
    }
    
    // MARK: - Credentials / UI Bindings (unchanged)
    @Published var scheme: String = "http"
    @Published var host: String = ""
    @Published var port: String = ""
    @Published var username: String = ""
    @Published var password: String = ""

    // MARK: - Dependencies (unchanged)
    private var service: SubsonicService?
    private let downloadManager: DownloadManager

    // MARK: - Init (unchanged)
    init(downloadManager: DownloadManager? = nil) {
        self.downloadManager = downloadManager ?? DownloadManager.shared
        loadSavedCredentials()
    }

    // MARK: - ✅ NEW: Central Data Loading Methods

    /// Loads initial data if not already loaded - called once per app session
    func loadInitialDataIfNeeded() async {
        guard !hasLoadedInitialData,
              let service = service,
              NetworkMonitor.shared.canLoadOnlineContent else {
            print("⚠️ Skipping initial data load - already loaded or no service/network")
            return
        }
        
        print("🚀 Starting initial data load...")
        await loadDataSequentially(isInitial: true)
    }
    
    /// Force refresh all data - called by pull-to-refresh
    func refreshAllData() async {
        guard let service = service else {
            print("❌ No service available for refresh")
            return
        }
        
        print("🔄 Starting data refresh...")
        await loadDataSequentially(isInitial: false)
    }
    
    /// ✅ NEW: Sequential Background Loading
    private func loadDataSequentially(isInitial: Bool) async {
        let canLoadOnline = NetworkMonitor.shared.canLoadOnlineContent
        let isOffline = OfflineManager.shared.isOfflineMode
        
        // If offline, load from cache immediately
        guard canLoadOnline && !isOffline else {
            await loadOfflineDataSequentially()
            return
        }
        
        isLoadingInBackground = true
        if isInitial { isLoading = true }
        defer {
            isLoadingInBackground = false
            if isInitial { isLoading = false }
        }
        
        let dataTypes: [DataType] = [.albums, .artists, .genres]
        
        for (index, dataType) in dataTypes.enumerated() {
            // Update progress
            backgroundLoadingProgress = "Loading \(dataType.displayName)... (\(index + 1)/\(dataTypes.count))"
            
            do {
                switch dataType {
                case .albums:
                    await loadAllAlbums(sortBy: .alphabetical)
                    loadedDataTypes.insert(.albums)
                    
                case .artists:
                    await loadArtistsWithOfflineSupport()
                    loadedDataTypes.insert(.artists)
                    
                case .genres:
                    await loadGenresWithOfflineSupport()
                    loadedDataTypes.insert(.genres)
                }
                
                // Small delay between requests to be server-friendly
                if index < dataTypes.count - 1 {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                }
                
            } catch {
                print("❌ Failed to load \(dataType.displayName): \(error)")
                // Continue with next data type even if one fails
            }
        }
        
        // Mark as completed
        hasLoadedInitialData = true
        lastRefreshDate = Date()
        backgroundLoadingProgress = ""
        
        print("✅ Sequential data loading completed. Loaded: \(loadedDataTypes.map { $0.displayName }.joined(separator: ", "))")
    }
    
    /// Load offline data sequentially (faster, no server requests)
    private func loadOfflineDataSequentially() async {
        print("📦 Loading offline data sequentially...")
        
        isLoadingInBackground = true
        defer { isLoadingInBackground = false }
        
        backgroundLoadingProgress = "Loading offline Albums..."
        await loadOfflineAlbums()
        loadedDataTypes.insert(.albums)
        
        backgroundLoadingProgress = "Loading offline Artists..."
        await loadOfflineArtists()
        loadedDataTypes.insert(.artists)
        
        backgroundLoadingProgress = "Loading offline Genres..."
        await loadOfflineGenres()
        loadedDataTypes.insert(.genres)
        
        hasLoadedInitialData = true
        lastRefreshDate = Date()
        backgroundLoadingProgress = ""
        
        print("✅ Offline data loading completed")
    }

    // MARK: - ✅ NEW: Intelligent Network Change Handling
    
    /// Handle network state changes with throttling
    func handleNetworkChange(isOnline: Bool) async {
        guard isOnline,
              !OfflineManager.shared.isOfflineMode,
              let service = service else {
            return
        }
        
        // Only refresh if data is stale (older than 5 minutes)
        let refreshThreshold: TimeInterval = 5 * 60 // 5 minutes
        let shouldRefresh: Bool
        
        if let lastRefresh = lastRefreshDate {
            shouldRefresh = Date().timeIntervalSince(lastRefresh) > refreshThreshold
        } else {
            shouldRefresh = !hasLoadedInitialData
        }
        
        if shouldRefresh {
            print("🌐 Network restored - refreshing stale data")
            await loadDataSequentially(isInitial: false)
        } else {
            print("🌐 Network restored - data is fresh, skipping refresh")
        }
    }
    
    // MARK: - ✅ NEW: Data Freshness Checks
    
    var isDataFresh: Bool {
        guard let lastRefresh = lastRefreshDate else { return false }
        let freshnessDuration: TimeInterval = 10 * 60 // 10 minutes
        return Date().timeIntervalSince(lastRefresh) < freshnessDuration
    }
    
    var shouldShowRefreshHint: Bool {
        guard let lastRefresh = lastRefreshDate else { return true }
        let hintThreshold: TimeInterval = 30 * 60 // 30 minutes
        return Date().timeIntervalSince(lastRefresh) > hintThreshold
    }

    // MARK: - Service Management (unchanged)
    func updateService(_ newService: SubsonicService) {
        self.service = newService
        // Reset loading state when service changes
        hasLoadedInitialData = false
        loadedDataTypes.removeAll()
        lastRefreshDate = nil
    }
    
    func getService() -> SubsonicService? {
        return service
    }

    // MARK: - Credentials Management (unchanged)
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

    // MARK: - Individual Loading Methods (unchanged but enhanced error handling)

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
            
            subsonicVersion = connectionInfo.version
            serverType = connectionInfo.type
            serverVersion = connectionInfo.serverVersion
            openSubsonic = connectionInfo.openSubsonic
            
            AppConfig.shared.configure(baseURL: url, username: username, password: password)
            self.service = tempService
            
            // Reset data loading state for new credentials
            hasLoadedInitialData = false
            loadedDataTypes.removeAll()
            lastRefreshDate = nil

            print("✅ Credentials saved successfully")
            return true
            
        case .failure(let connectionError):
            connectionStatus = false
            errorMessage = connectionError.userMessage
            
            print("❌ Save credentials failed: \(connectionError)")
            return false
        }
    }
    
    private func buildCurrentURL() -> URL? {
        let portString = port.isEmpty ? "" : ":\(port)"
        return URL(string: "\(scheme)://\(host)\(portString)")
    }
    
    // MARK: - Individual Data Loading Methods (unchanged)
    
    func loadArtists() async {
        guard let service else {
            print("❌ Service nicht verfügbar")
            return
        }
        
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
        
        // Reset new properties
        hasLoadedInitialData = false
        loadedDataTypes.removeAll()
        lastRefreshDate = nil
        isLoadingInBackground = false
        backgroundLoadingProgress = ""
    }
    
    // MARK: - Enhanced Album Loading (unchanged but better error handling)
    
    func loadAllAlbums(sortBy: SubsonicService.AlbumSortType = .alphabetical) async {
        guard let service else {
            print("❌ Service nicht verfügbar")
            return
        }
        
        do {
            albums = try await service.getAllAlbums(sortBy: sortBy)
            AlbumMetadataCache.shared.cacheAlbums(albums)
            
        } catch {
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
    
    // MARK: - Offline Fallback Helpers (unchanged)
    
    private func handleImmediateOfflineSwitch() async {
        OfflineManager.shared.switchToOfflineMode()
        await NetworkMonitor.shared.checkServerConnection()
        errorMessage = nil
        print("⚡ Immediate offline switch completed")
    }
    
    private func handleOfflineFallback() async {
        OfflineManager.shared.switchToOfflineMode()
        errorMessage = nil
    }
    
    func loadOfflineAlbums() async {
        albums = OfflineManager.shared.offlineAlbums
        print("📦 Loaded \(albums.count) albums from offline cache")
    }
    
    private func loadOfflineArtists() async {
        artists = OfflineManager.shared.offlineArtists
        print("📦 Loaded \(artists.count) artists from offline cache")
    }
    
    private func loadOfflineGenres() async {
        genres = OfflineManager.shared.offlineGenres
        print("📦 Loaded \(genres.count) genres from offline cache")
    }
}
