//
//  NavidromeViewModel.swift - FINAL CLEAN COORDINATOR
//  NavidromeClient
//
//  ✅ CLEAN: Minimal coordinator - delegates everything to managers
//  ✅ ELIMINATES: All redundant ViewModels dependencies
//

import Foundation
import SwiftUI

@MainActor
class NavidromeViewModel: ObservableObject {
    
    // MARK: - Manager Dependencies (unchanged)
    private let connectionManager = ConnectionManager()
    let musicLibraryManager = MusicLibraryManager.shared
    private let searchManager = SearchManager()
    private let songManager = SongManager()
    
    // MARK: - Service Management (unchanged)
    private var service: SubsonicService? {
        connectionManager.getService()
    }
    
    init() {
        setupManagerDependencies()
    }
    
    // MARK: - ✅ DELEGATION: Published Properties (unchanged)
    
    // Library Data (delegated)
    var albums: [Album] { musicLibraryManager.albums }
    var artists: [Artist] { musicLibraryManager.artists }
    var genres: [Genre] { musicLibraryManager.genres }
    
    // Loading States (delegated)
    var isLoading: Bool { musicLibraryManager.isLoading }
    var hasLoadedInitialData: Bool { musicLibraryManager.hasLoadedInitialData }
    var isLoadingInBackground: Bool { musicLibraryManager.isLoadingInBackground }
    var backgroundLoadingProgress: String { musicLibraryManager.backgroundLoadingProgress }
    var isDataFresh: Bool { musicLibraryManager.isDataFresh }
    
    // Connection State (delegated)
    var connectionStatus: Bool { connectionManager.connectionStatus }
    var serverType: String? { connectionManager.serverType }
    var serverVersion: String? { connectionManager.serverVersion }
    var subsonicVersion: String? { connectionManager.subsonicVersion }
    var openSubsonic: Bool? { connectionManager.openSubsonic }
    var errorMessage: String? { connectionManager.connectionError }
    
    // Search Results (delegated)
    var searchResults: SearchManager.SearchResults { searchManager.searchResults }
    var songs: [Song] { searchResults.songs } // Legacy compatibility
    
    // Credential UI Bindings (delegated)
    var scheme: String {
        get { connectionManager.scheme }
        set { connectionManager.scheme = newValue }
    }
    var host: String {
        get { connectionManager.host }
        set { connectionManager.host = newValue }
    }
    var port: String {
        get { connectionManager.port }
        set { connectionManager.port = newValue }
    }
    var username: String {
        get { connectionManager.username }
        set { connectionManager.username = newValue }
    }
    var password: String {
        get { connectionManager.password }
        set { connectionManager.password = newValue }
    }
    
    // Song Cache (delegated)
    var albumSongs: [String: [Song]] { songManager.albumSongs }
    
    // MARK: - ✅ COORDINATION: Setup & Configuration (unchanged)
    
    private func setupManagerDependencies() {
        if let service = service {
            configureManagers(with: service)
        }
    }
    
    private func configureManagers(with service: SubsonicService) {
        musicLibraryManager.configure(service: service)
        searchManager.configure(service: service)
        songManager.configure(service: service)
    }
    
    func updateService(_ newService: SubsonicService) {
        connectionManager.updateService(newService)
        configureManagers(with: newService)
        objectWillChange.send()
    }
    
    func getService() -> SubsonicService? {
        return service
    }
    
    // MARK: - ✅ DELEGATION: Core Operations (unchanged)
    
    // Connection Management
    func testConnection() async {
        await connectionManager.testConnection()
        objectWillChange.send()
    }
    
    func saveCredentials() async -> Bool {
        let success = await connectionManager.testAndSaveCredentials()
        if success, let service = connectionManager.getService() {
            configureManagers(with: service)
        }
        objectWillChange.send()
        return success
    }
    
    // Data Loading
    func loadInitialDataIfNeeded() async {
        await musicLibraryManager.loadInitialDataIfNeeded()
        objectWillChange.send()
    }
    
    func refreshAllData() async {
        await musicLibraryManager.refreshAllData()
        objectWillChange.send()
    }
    
    func loadMoreAlbumsIfNeeded() async {
        await musicLibraryManager.loadMoreAlbumsIfNeeded()
        objectWillChange.send()
    }
    
    func loadAllAlbums(sortBy: SubsonicService.AlbumSortType = .alphabetical) async {
        await musicLibraryManager.loadAlbumsProgressively(sortBy: sortBy, reset: true)
        objectWillChange.send()
    }
    
    // Song Management
    func loadSongs(for albumId: String) async -> [Song] {
        return await songManager.loadSongs(for: albumId)
    }
    
    func clearSongCache() {
        songManager.clearSongCache()
        objectWillChange.send()
    }
    
    // Search
    func search(query: String) async {
        await searchManager.search(query: query)
        objectWillChange.send()
    }
    
    // Network Change Handling
    func handleNetworkChange(isOnline: Bool) async {
        await musicLibraryManager.handleNetworkChange(isOnline: isOnline)
        objectWillChange.send()
    }
    
    // MARK: - ✅ LEGACY COMPATIBILITY (unchanged)
    
    // Artist/Genre Detail Support
    func loadAlbums(context: ArtistDetailContext) async throws -> [Album] {
        return try await musicLibraryManager.loadAlbums(context: context)
    }
    
    // Statistics
    func getCachedSongCount() -> Int {
        return songManager.getCachedSongCount()
    }
    
    func hasSongsAvailableOffline(for albumId: String) -> Bool {
        return songManager.hasSongsAvailableOffline(for: albumId)
    }
    
    func getOfflineSongCount(for albumId: String) -> Int {
        return songManager.getOfflineSongCount(for: albumId)
    }
    
    func getSongLoadingStats() -> SongLoadingStats {
        let stats = songManager.getCacheStats()
        return SongLoadingStats(
            totalCachedSongs: stats.totalCachedSongs,
            cachedAlbums: stats.cachedAlbums,
            offlineAlbums: stats.offlineAlbums,
            offlineSongs: stats.offlineSongs
        )
    }
    
    // MARK: - ✅ RESET (Factory Reset Support) (unchanged)
    
    func reset() {
        connectionManager.reset()
        musicLibraryManager.reset()
        searchManager.reset()
        songManager.reset()
        
        objectWillChange.send()
        print("✅ NavidromeViewModel: All managers reset")
    }
}

// MARK: - ✅ LEGACY COMPATIBILITY TYPES (unchanged)

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

// MARK: - ✅ CONVENIENCE COMPUTED PROPERTIES (unchanged)

extension NavidromeViewModel {
    
    /// Quick connection health check
    var isConnectedAndHealthy: Bool {
        return connectionManager.isConnectedAndHealthy
    }
    
    /// Connection status for UI display
    var connectionStatusText: String {
        return connectionManager.connectionStatusText
    }
    
    /// Connection status color for UI
    var connectionStatusColor: Color {
        return connectionManager.connectionStatusColor
    }
    
    /// Search mode description
    var searchModeDescription: String {
        return searchManager.searchModeDescription
    }
}
