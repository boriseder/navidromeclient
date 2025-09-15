//
//  NavidromeViewModel.swift - Enhanced with Offline Song Loading Support
//

import Foundation
import SwiftUI

@MainActor
class NavidromeViewModel: ObservableObject {

    // ******************************************************************
    // **                           PROPERTIES                          **
    // ******************************************************************

    // MARK: - Published Data Properties
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

    @Published var hasLoadedInitialData = false
    @Published var lastRefreshDate: Date?
    @Published var isLoadingInBackground = false
    @Published var backgroundLoadingProgress: String = ""

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

    // MARK: - Credentials / UI Bindings
    @Published var scheme: String = "http"
    @Published var host: String = ""
    @Published var port: String = ""
    @Published var username: String = ""
    @Published var password: String = ""

    // MARK: - Dependencies
    private var service: SubsonicService?
    private let downloadManager: DownloadManager

    // ******************************************************************
    // **                            INITIALIZER                         **
    // ******************************************************************

    init(downloadManager: DownloadManager? = nil) {
        self.downloadManager = downloadManager ?? DownloadManager.shared
        loadSavedCredentials()
    }

    // ******************************************************************
    // **                     CREDENTIALS MANAGEMENT                   **
    // ******************************************************************

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

    // ******************************************************************
    // **                         SERVICE MANAGEMENT                    **
    // ******************************************************************

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
    
        // ******************************************************************
    // **                         INITIAL / REFRESH DATA                **
    // ******************************************************************

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
    
    func refreshAllData() async {
        guard let service = service else {
            print("❌ No service available for refresh")
            return
        }
        
        print("🔄 Starting data refresh...")
        await loadDataSequentially(isInitial: false)
    }
    
    private func loadDataSequentially(isInitial: Bool) async {
        let canLoadOnline = NetworkMonitor.shared.canLoadOnlineContent
        let isOffline = OfflineManager.shared.isOfflineMode
        
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
                
                if index < dataTypes.count - 1 {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
                
            } catch {
                print("❌ Failed to load \(dataType.displayName): \(error)")
            }
        }
        
        hasLoadedInitialData = true
        lastRefreshDate = Date()
        backgroundLoadingProgress = ""
        
        print("✅ Sequential data loading completed. Loaded: \(loadedDataTypes.map { $0.displayName }.joined(separator: ", "))")
    }
    
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

    // ******************************************************************
    // **                      NETWORK / OFFLINE HANDLING              **
    // ******************************************************************

    func handleNetworkChange(isOnline: Bool) async {
        guard isOnline,
              !OfflineManager.shared.isOfflineMode,
              let service = service else {
            return
        }
        
        let refreshThreshold: TimeInterval = 5 * 60
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

    // ******************************************************************
    // **                       DATA LOADING METHODS                   **
    // ******************************************************************

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
        
        hasLoadedInitialData = false
        loadedDataTypes.removeAll()
        lastRefreshDate = nil
        isLoadingInBackground = false
        backgroundLoadingProgress = ""
    }

    // ******************************************************************
    // **                    ENHANCED ALBUM & ARTIST LOADING           **
    // ******************************************************************

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
        
        await loadArtists()
        if artists.isEmpty {
            print("🔄 Artists loading failed - switching to offline")
            await handleImmediateOfflineSwitch()
            await loadOfflineArtists()
        }
    }
    
    func loadGenresWithOfflineSupport() async {
        guard NetworkMonitor.shared.canLoadOnlineContent else {
            print("🔄 Loading genres from offline cache")
            await loadOfflineGenres()
            return
        }
        
        await loadGenres()
        if genres.isEmpty {
            print("🔄 Genres loading failed - switching to offline")
            await handleImmediateOfflineSwitch()
            await loadOfflineGenres()
        }
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
    
        // ******************************************************************
    // **                      SONG LOADING / OFFLINE SUPPORT          **
    // ******************************************************************

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
            
            if let subsonicError = error as? SubsonicError {
                if subsonicError.isOfflineError || subsonicError.isRecoverable {
                    print("🔄 Network error detected - this will trigger offline fallback")
                }
            }
            
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

    // ******************************************************************
    // **                      BATCH & PRELOAD SONGS                   **
    // ******************************************************************

    func loadSongsForAlbums(_ albumIds: [String]) async -> [String: [Song]] {
        var results: [String: [Song]] = [:]
        
        for albumId in albumIds {
            let songs = await loadSongs(for: albumId)
            if !songs.isEmpty {
                results[albumId] = songs
            }
        }
        
        print("✅ Batch loaded songs for \(results.count)/\(albumIds.count) albums")
        return results
    }
    
    func preloadSongsForAlbums(_ albums: [Album]) async {
        let albumIds = Array(albums.prefix(5).map { $0.id })
        var albumsToLoad: [String] = []
        
        for albumId in albumIds {
            if albumSongs[albumId] == nil || albumSongs[albumId]?.isEmpty == true {
                albumsToLoad.append(albumId)
            }
        }
        
        await withTaskGroup(of: Void.self) { group in
            for albumId in albumsToLoad {
                group.addTask { @MainActor in
                    _ = await self.loadSongs(for: albumId)
                }
            }
        }
    }

    // ******************************************************************
    // **                      MEMORY & CACHE MANAGEMENT               **
    // ******************************************************************

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

    // ******************************************************************
    // **                      OFFLINE FALLBACK HELPERS                **
    // ******************************************************************

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
}

// ******************************************************************
// **                          EXTENSIONS / UTIL                     **
// ******************************************************************

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
