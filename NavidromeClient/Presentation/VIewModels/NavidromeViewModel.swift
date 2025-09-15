//
//  NavidromeViewModel.swift - PROGRESSIVE LOADING ARCHITECTURE
//  NavidromeClient
//
//  ✅ CLEAN: Streaming data loading, progressive UI updates, sustainable architecture
//

import Foundation
import SwiftUI

@MainActor
class NavidromeViewModel: ObservableObject {

    // MARK: - ✅ PROGRESSIVE DATA ARCHITECTURE
    
    // Progressive Albums Loading
    @Published var loadedAlbums: [Album] = []
    @Published var totalAlbumCount: Int = 0
    @Published var albumLoadingState: DataLoadingState = .idle
    
    // Progressive Artists Loading
    @Published var loadedArtists: [Artist] = []
    @Published var totalArtistCount: Int = 0
    @Published var artistLoadingState: DataLoadingState = .idle
    
    // Progressive Genres Loading
    @Published var loadedGenres: [Genre] = []
    @Published var genreLoadingState: DataLoadingState = .idle
    
    // Legacy compatibility (computed properties)
    var albums: [Album] { loadedAlbums }
    var artists: [Artist] { loadedArtists }
    var genres: [Genre] { loadedGenres }
    
    // MARK: - ✅ LOADING STATE MANAGEMENT
    
    enum DataLoadingState: Equatable {
        case idle
        case loading
        case loadingMore
        case completed
        case error(String)
        
        var isLoading: Bool {
            switch self {
            case .loading, .loadingMore: return true
            default: return false
            }
        }
        
        var canLoadMore: Bool {
            switch self {
            case .idle, .completed: return true
            case .loading, .loadingMore, .error: return false
            }
        }
    }
    
    // MARK: - CONFIGURATION
    
    struct LoadingConfig {
        static let albumBatchSize = 20
        static let artistBatchSize = 25
        static let genreBatchSize = 30
        static let initialDelay: UInt64 = 100_000_000 // 100ms
        static let batchDelay: UInt64 = 200_000_000   // 200ms
    }
    
    // MARK: - EXISTING PROPERTIES (unchanged)
    @Published var songs: [Song] = []
    @Published var albumSongs: [String: [Song]] = [:]
    @Published var connectionStatus = false
    @Published var errorMessage: String?
    @Published var serverType: String?
    @Published var serverVersion: String?
    @Published var subsonicVersion: String?
    @Published var openSubsonic: Bool?
    @Published var hasLoadedInitialData = false
    @Published var lastRefreshDate: Date?
    @Published var backgroundLoadingProgress: String = ""
    
    // Global loading state (for compatibility)
    var isLoading: Bool {
        albumLoadingState.isLoading || artistLoadingState.isLoading || genreLoadingState.isLoading
    }
    
    var isLoadingInBackground: Bool {
        isLoading && hasLoadedInitialData
    }
    
    // MARK: - CREDENTIALS / UI BINDINGS
    @Published var scheme: String = "http"
    @Published var host: String = ""
    @Published var port: String = ""
    @Published var username: String = ""
    @Published var password: String = ""
    
    // MARK: - DEPENDENCIES
    private var service: SubsonicService?
    private let downloadManager: DownloadManager
    
    // MARK: - INITIALIZATION
    
    init(downloadManager: DownloadManager? = nil) {
        self.downloadManager = downloadManager ?? DownloadManager.shared
        loadSavedCredentials()
    }
    
    // MARK: - ✅ PROGRESSIVE LOADING - ALBUMS
    
    func loadAlbumsProgressively(
        sortBy: SubsonicService.AlbumSortType = .alphabetical,
        reset: Bool = false
    ) async {
        
        if reset {
            loadedAlbums = []
            totalAlbumCount = 0
            albumLoadingState = .idle
        }
        
        guard albumLoadingState.canLoadMore else { return }
        guard let service = service else {
            albumLoadingState = .error("Service nicht verfügbar")
            return
        }
        
        let offset = loadedAlbums.count
        let batchSize = LoadingConfig.albumBatchSize
        
        albumLoadingState = offset == 0 ? .loading : .loadingMore
        backgroundLoadingProgress = "Loading albums \(offset + 1)-\(offset + batchSize)..."
        
        do {
            // Add small delay for UI responsiveness
            if offset > 0 {
                try await Task.sleep(nanoseconds: LoadingConfig.batchDelay)
            }
            
            let newAlbums = try await service.getAllAlbums(
                sortBy: sortBy,
                size: batchSize,
                offset: offset
            )
            
            if newAlbums.isEmpty {
                albumLoadingState = .completed
                backgroundLoadingProgress = ""
                return
            }
            
            // Cache albums for offline use
            AlbumMetadataCache.shared.cacheAlbums(newAlbums)
            
            // Update UI progressively
            loadedAlbums.append(contentsOf: newAlbums)
            
            // Determine if we have more to load
            if newAlbums.count < batchSize {
                albumLoadingState = .completed
                totalAlbumCount = loadedAlbums.count
            } else {
                albumLoadingState = .idle
            }
            
            // Update initial data flag
            if !hasLoadedInitialData && loadedAlbums.count >= LoadingConfig.albumBatchSize {
                hasLoadedInitialData = true
                lastRefreshDate = Date()
            }
            
            backgroundLoadingProgress = ""
            
            print("✅ Loaded album batch: \(newAlbums.count) albums (total: \(loadedAlbums.count))")
            
        } catch {
            await handleLoadingError(error, for: "albums")
        }
    }
    
    // MARK: - ✅ PROGRESSIVE LOADING - ARTISTS
    
    func loadArtistsProgressively(reset: Bool = false) async {
        
        if reset {
            loadedArtists = []
            totalArtistCount = 0
            artistLoadingState = .idle
        }
        
        guard artistLoadingState.canLoadMore else { return }
        guard let service = service else {
            artistLoadingState = .error("Service nicht verfügbar")
            return
        }
        
        artistLoadingState = loadedArtists.isEmpty ? .loading : .loadingMore
        backgroundLoadingProgress = "Loading artists..."
        
        do {
            // Note: Subsonic API doesn't support pagination for artists
            // Load all at once but with proper state management
            let allArtists = try await service.getArtists()
            
            loadedArtists = allArtists
            totalArtistCount = allArtists.count
            artistLoadingState = .completed
            backgroundLoadingProgress = ""
            
            print("✅ Loaded artists: \(allArtists.count)")
            
        } catch {
            await handleLoadingError(error, for: "artists")
        }
    }
    
    // MARK: - ✅ PROGRESSIVE LOADING - GENRES
    
    func loadGenresProgressively(reset: Bool = false) async {
        
        if reset {
            loadedGenres = []
            genreLoadingState = .idle
        }
        
        guard genreLoadingState.canLoadMore else { return }
        guard let service = service else {
            genreLoadingState = .error("Service nicht verfügbar")
            return
        }
        
        genreLoadingState = .loading
        backgroundLoadingProgress = "Loading genres..."
        
        do {
            let allGenres = try await service.getGenres()
            
            loadedGenres = allGenres
            genreLoadingState = .completed
            backgroundLoadingProgress = ""
            
            print("✅ Loaded genres: \(allGenres.count)")
            
        } catch {
            await handleLoadingError(error, for: "genres")
        }
    }
    
    // MARK: - ✅ COORDINATED LOADING
    
    func loadInitialDataIfNeeded() async {
        guard !hasLoadedInitialData,
              let service = service,
              NetworkMonitor.shared.canLoadOnlineContent else {
            print("⚠️ Skipping initial data load")
            return
        }
        
        print("🚀 Starting progressive initial data load...")
        
        // Load first batch of each type with staggered timing
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.loadAlbumsProgressively(reset: true)
            }
            
            group.addTask {
                try? await Task.sleep(nanoseconds: LoadingConfig.initialDelay)
                await self.loadArtistsProgressively(reset: true)
            }
            
            group.addTask {
                try? await Task.sleep(nanoseconds: LoadingConfig.initialDelay * 2)
                await self.loadGenresProgressively(reset: true)
            }
        }
        
        print("✅ Initial progressive data load completed")
    }
    
    func loadMoreAlbumsIfNeeded() async {
        await loadAlbumsProgressively()
    }
    
    func refreshAllData() async {
        print("🔄 Starting progressive data refresh...")
        
        // Reset all states
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.loadAlbumsProgressively(reset: true)
            }
            group.addTask {
                await self.loadArtistsProgressively(reset: true)
            }
            group.addTask {
                await self.loadGenresProgressively(reset: true)
            }
        }
        
        lastRefreshDate = Date()
        print("✅ Progressive data refresh completed")
    }
    
    // MARK: - ERROR HANDLING
    
    private func handleLoadingError(_ error: Error, for dataType: String) async {
        print("❌ Failed to load \(dataType): \(error)")
        
        let errorMessage: String
        if let subsonicError = error as? SubsonicError {
            switch subsonicError {
            case .timeout:
                await handleImmediateOfflineSwitch()
                return
            case .network where subsonicError.isOfflineError:
                await handleOfflineFallback()
                return
            default:
                errorMessage = subsonicError.localizedDescription
            }
        } else {
            errorMessage = error.localizedDescription
        }
        
        // Update appropriate loading state
        switch dataType {
        case "albums":
            albumLoadingState = .error(errorMessage)
        case "artists":
            artistLoadingState = .error(errorMessage)
        case "genres":
            genreLoadingState = .error(errorMessage)
        default:
            break
        }
        
        backgroundLoadingProgress = ""
    }
    
    // MARK: - ✅ DATA FLOW HELPERS
    
    var isDataFresh: Bool {
        guard let lastRefresh = lastRefreshDate else { return false }
        let freshnessDuration: TimeInterval = 10 * 60
        return Date().timeIntervalSince(lastRefresh) < freshnessDuration
    }
    
    var shouldShowRefreshHint: Bool {
        guard let lastRefresh = lastRefreshDate else { return true }
        let hintThreshold: TimeInterval = 30 * 60
        return Date().timeIntervalSince(lastRefresh) > hintThreshold
    }
    
    // MARK: - EXISTING METHODS (unchanged but adapted)
    
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
    
    func testConnection() async {
        guard let url = buildCurrentURL() else {
            connectionStatus = false
            errorMessage = "Ungültige Server-URL"
            return
        }

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
            
            // Reset loading state for new credentials
            hasLoadedInitialData = false
            loadedAlbums = []
            loadedArtists = []
            loadedGenres = []
            albumLoadingState = .idle
            artistLoadingState = .idle
            genreLoadingState = .idle
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
    
    func updateService(_ newService: SubsonicService) {
        self.service = newService
        // Reset loading state when service changes
        hasLoadedInitialData = false
        loadedAlbums = []
        loadedArtists = []
        loadedGenres = []
        albumLoadingState = .idle
        artistLoadingState = .idle
        genreLoadingState = .idle
        lastRefreshDate = nil
    }
    
    func getService() -> SubsonicService? {
        return service
    }
    
    func reset() {
        service = nil
        loadedAlbums = []
        loadedArtists = []
        loadedGenres = []
        songs = []
        albumSongs = [:]
        
        albumLoadingState = .idle
        artistLoadingState = .idle
        genreLoadingState = .idle
        
        scheme = "http"
        host = ""
        port = ""
        username = ""
        password = ""
        connectionStatus = false
        errorMessage = nil
        
        hasLoadedInitialData = false
        lastRefreshDate = nil
        backgroundLoadingProgress = ""
        totalAlbumCount = 0
        totalArtistCount = 0
    }
    
    // MARK: - LEGACY COMPATIBILITY METHODS
    
    func handleNetworkChange(isOnline: Bool) async {
        guard isOnline,
              !OfflineManager.shared.isOfflineMode,
              let service = service else {
            return
        }
        
        if shouldShowRefreshHint {
            print("🌐 Network restored - refreshing stale data")
            await refreshAllData()
        } else {
            print("🌐 Network restored - data is fresh, skipping refresh")
        }
    }
    
    // Song loading methods (unchanged)
    func loadSongs(for albumId: String) async -> [Song] {
        if let cached = albumSongs[albumId], !cached.isEmpty {
            print("📋 Using cached songs for album \(albumId): \(cached.count) songs")
            return cached
        }
        
        if downloadManager.isAlbumDownloaded(albumId) {
            print("📱 Loading offline songs for album \(albumId)")
            let offlineSongs = await loadOfflineSongs(for: albumId)
            if !offlineSongs.isEmpty {
                albumSongs[albumId] = offlineSongs
                return offlineSongs
            }
        }
        
        if NetworkMonitor.shared.canLoadOnlineContent && !OfflineManager.shared.isOfflineMode {
            print("🌐 Loading online songs for album \(albumId)")
            let onlineSongs = await loadOnlineSongs(for: albumId)
            if !onlineSongs.isEmpty {
                albumSongs[albumId] = onlineSongs
                return onlineSongs
            }
        }
        
        print("📱 Fallback to offline songs for album \(albumId)")
        let fallbackSongs = await loadOfflineSongs(for: albumId)
        if !fallbackSongs.isEmpty {
            albumSongs[albumId] = fallbackSongs
        }
        
        return fallbackSongs
    }
    
    private func loadOnlineSongs(for albumId: String) async -> [Song] {
        guard let service = service else {
            print("❌ No service available for online song loading")
            return []
        }
        
        do {
            let songs = try await service.getSongs(for: albumId)
            print("✅ Loaded \(songs.count) online songs for album \(albumId)")
            return songs
        } catch {
            print("⚠️ Failed to load online songs for album \(albumId): \(error)")
            return []
        }
    }
    
    private func loadOfflineSongs(for albumId: String) async -> [Song] {
        let downloadedSongs = downloadManager.getDownloadedSongs(for: albumId)
        if !downloadedSongs.isEmpty {
            let songs = downloadedSongs.map { $0.toSong() }
            print("✅ Loaded \(songs.count) offline songs with full metadata for album \(albumId)")
            return songs
        }
        
        guard let legacyAlbum = downloadManager.downloadedAlbums.first(where: { $0.albumId == albumId }) else {
            print("⚠️ Album \(albumId) not found in downloads")
            return []
        }
        
        let albumMetadata = AlbumMetadataCache.shared.getAlbum(id: albumId)
        
        let fallbackSongs = legacyAlbum.songIds.enumerated().map { index, songId in
            Song.createFromDownload(
                id: songId,
                title: generateFallbackTitle(index: index, songId: songId),
                duration: nil,
                coverArt: albumId,
                artist: albumMetadata?.artist ?? "Unknown Artist",
                album: albumMetadata?.name ?? "Unknown Album",
                albumId: albumId,
                track: index + 1,
                year: albumMetadata?.year,
                genre: albumMetadata?.genre,
                contentType: "audio/mpeg"
            )
        }
        
        print("✅ Created \(fallbackSongs.count) fallback songs for legacy album \(albumId)")
        return fallbackSongs
    }
    
    private func generateFallbackTitle(index: Int, songId: String) -> String {
        let trackNumber = String(format: "%02d", index + 1)
        
        if songId.count > 10 && songId.allSatisfy({ $0.isHexDigit }) {
            return "Track \(trackNumber)"
        }
        
        let cleanTitle = songId
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
        
        return cleanTitle.isEmpty ? "Track \(trackNumber)" : cleanTitle
    }
    
    // ✅ FIXED: Search method with proper state management
    func search(query: String) async {
        guard let service else { return }

        if query.isEmpty {
            clearSearchResults()
            return
        }

        do {
            let result = try await service.search(query: query)
            updateSearchResults(artists: result.artists, albums: result.albums, songs: result.songs)
        } catch {
            clearSearchResults()
            errorMessage = "Fehler bei der Suche: \(error.localizedDescription)"
        }
    }
    
    private func clearSearchResults() {
        loadedArtists = []
        loadedAlbums = []
        songs = []
        errorMessage = nil
    }
    
    private func updateSearchResults(artists: [Artist], albums: [Album], songs: [Song]) {
        loadedArtists = artists
        loadedAlbums = albums
        self.songs = songs
        errorMessage = nil
    }
    
    // Offline fallback methods (unchanged)
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
    
    // Legacy compatibility methods
    func loadAlbums(context: ArtistDetailContext) async throws -> [Album] {
        guard let service else { throw URLError(.networkConnectionLost) }
        
        switch context {
        case .artist(let artist):
            return try await service.getAlbumsByArtist(artistId: artist.id)
        case .genre(let genre):
            return try await service.getAlbumsByGenre(genre: genre.value)
        }
    }
    
    func loadAllAlbums(sortBy: SubsonicService.AlbumSortType = .alphabetical) async {
        await loadAlbumsProgressively(sortBy: sortBy, reset: true)
    }
    
    func clearSongCache() {
        let cacheSize = albumSongs.count
        albumSongs.removeAll()
        print("🧹 Cleared song cache (\(cacheSize) albums)")
    }
    
    func getCachedSongCount() -> Int {
        return albumSongs.values.reduce(0) { $0 + $1.count }
    }
    
    func hasSongsAvailableOffline(for albumId: String) -> Bool {
        return downloadManager.isAlbumDownloaded(albumId)
    }
    
    func getOfflineSongCount(for albumId: String) -> Int {
        return downloadManager.getDownloadedSongs(for: albumId).count
    }
}

// MARK: - EXTENSIONS

extension Character {
    var isHexDigit: Bool {
        return self.isNumber || ("a"..."f").contains(self.lowercased()) || ("A"..."F").contains(self)
    }
}

extension NavidromeViewModel {
    func getSongLoadingStats() -> SongLoadingStats {
        let totalCachedSongs = getCachedSongCount()
        let cachedAlbums = albumSongs.count
        let offlineAlbums = downloadManager.downloadedAlbums.count
        let offlineSongs = downloadManager.downloadedAlbums.reduce(0) { $0 + $1.songs.count }
        
        return SongLoadingStats(
            totalCachedSongs: totalCachedSongs,
            cachedAlbums: cachedAlbums,
            offlineAlbums: offlineAlbums,
            offlineSongs: offlineSongs
        )
    }
}

struct SongLoadingStats {
    let totalCachedSongs: Int
    let cachedAlbums: Int
    let offlineAlbums: Int
    let offlineSongs: Int
    
    var cacheHitRate: Double {
        guard offlineSongs > 0 else { return 0 }
        return Double(totalCachedSongs) / Double(offlineSongs) * 100
    }
}
