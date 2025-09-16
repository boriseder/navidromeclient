//
//  SearchManager.swift - MIGRATED to SearchService
//  NavidromeClient
//
//  ✅ MIGRATION COMPLETE: SubsonicService → SearchService
//  ✅ ALL SERVICE CALLS UPDATED
//

import Foundation
import SwiftUI

@MainActor
class SearchManager: ObservableObject {
    
    // MARK: - ✅ SEARCH STATE (unchanged)
    
    @Published private(set) var searchResults = SearchResults()
    @Published private(set) var isSearching = false
    @Published private(set) var searchError: String?
    @Published private(set) var lastSearchQuery: String = ""
    
    // ✅ MIGRATION: SearchService dependency
    private weak var searchService: SearchService?
    private let offlineManager: OfflineManager
    private let downloadManager: DownloadManager
    
    /// Debounced search for real-time search as user types
    private var searchTask: Task<Void, Never>?

    // MARK: - ✅ SEARCH RESULTS MODEL (unchanged)
    
    struct SearchResults {
        var artists: [Artist] = []
        var albums: [Album] = []
        var songs: [Song] = []
        
        var isEmpty: Bool {
            return artists.isEmpty && albums.isEmpty && songs.isEmpty
        }
        
        var totalCount: Int {
            return artists.count + albums.count + songs.count
        }
        
        func count(for type: SearchResultType) -> Int {
            switch type {
            case .artists: return artists.count
            case .albums: return albums.count
            case .songs: return songs.count
            }
        }
    }
    
    enum SearchResultType: String, CaseIterable {
        case artists = "Artists"
        case albums = "Albums"
        case songs = "Songs"
        
        var icon: String {
            switch self {
            case .artists: return "person.2.fill"
            case .albums: return "record.circle.fill"
            case .songs: return "music.note"
            }
        }
    }
    
    // MARK: - ✅ INITIALIZATION (unchanged)
    
    init(offlineManager: OfflineManager = OfflineManager.shared,
         downloadManager: DownloadManager = DownloadManager.shared) {
        self.offlineManager = offlineManager
        self.downloadManager = downloadManager
    }
    
    // MARK: - ✅ MIGRATION: New configuration method
    
    func configure(searchService: SearchService) {
        self.searchService = searchService
        print("✅ SearchManager configured with SearchService")
    }
    
    // MARK: - ✅ PRIMARY API: Smart Search (unchanged logic, updated service calls)
    
    /// Perform search with automatic online/offline detection
    func search(query: String) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Clear results for empty query (unchanged)
        guard !trimmedQuery.isEmpty else {
            clearSearch()
            return
        }
        
        lastSearchQuery = trimmedQuery
        isSearching = true
        searchError = nil
        
        defer { isSearching = false }
        
        // Determine search mode (unchanged)
        let shouldUseOffline = !NetworkMonitor.shared.canLoadOnlineContent || offlineManager.isOfflineMode
        
        do {
            if shouldUseOffline {
                print("🔍 Performing offline search for: '\(trimmedQuery)'")
                searchResults = await performOfflineSearch(query: trimmedQuery)
            } else {
                print("🔍 Performing online search for: '\(trimmedQuery)' via SearchService")
                searchResults = try await performOnlineSearch(query: trimmedQuery)
            }
            
            print("✅ Search completed: \(searchResults.totalCount) results")
            
        } catch {
            print("❌ Search failed via SearchService: \(error)")
            searchError = handleSearchError(error)
            searchResults = SearchResults() // Clear results on error
        }
    }
    
    /// Clear search results and state (unchanged)
    func clearSearch() {
        searchResults = SearchResults()
        searchError = nil
        lastSearchQuery = ""
        print("🧹 Search cleared")
    }
    
    /// Refresh current search if query exists (unchanged)
    func refreshSearch() async {
        guard !lastSearchQuery.isEmpty else { return }
        await search(query: lastSearchQuery)
    }
    
    // MARK: - ✅ MIGRATION: Online search with SearchService
    
    private func performOnlineSearch(query: String) async throws -> SearchResults {
        // ✅ MIGRATION: SearchService guard
        guard let searchService = searchService else {
            print("❌ SearchService not available for online search")
            throw SearchError.serviceUnavailable
        }
        
        // ✅ MIGRATION: SearchService call
        let result = try await searchService.search(query: query, maxResults: 50)
        
        print("✅ Online search completed via SearchService: \(result.artists.count) artists, \(result.albums.count) albums, \(result.songs.count) songs")
        
        return SearchResults(
            artists: result.artists,
            albums: result.albums,
            songs: result.songs
        )
    }
    
    // MARK: - ✅ OFFLINE SEARCH IMPLEMENTATION (unchanged - no service calls)
    
    private func performOfflineSearch(query: String) async -> SearchResults {
        let lowercaseQuery = query.lowercased()
        
        async let artistResults = searchOfflineArtists(query: lowercaseQuery)
        async let albumResults = searchOfflineAlbums(query: lowercaseQuery)
        async let songResults = searchOfflineSongs(query: lowercaseQuery)
        
        let results = await SearchResults(
            artists: artistResults,
            albums: albumResults,
            songs: songResults
        )
        
        print("🔍 Offline search results: \(results.artists.count) artists, \(results.albums.count) albums, \(results.songs.count) songs")
        
        return results
    }
    
    /// Search in offline artists (unchanged)
    private func searchOfflineArtists(query: String) async -> [Artist] {
        return offlineManager.offlineArtists.filter { artist in
            artist.name.lowercased().contains(query)
        }.sorted { $0.name < $1.name }
    }
    
    /// Search in offline albums (unchanged)
    private func searchOfflineAlbums(query: String) async -> [Album] {
        return offlineManager.offlineAlbums.filter { album in
            album.name.lowercased().contains(query) ||
            album.artist.lowercased().contains(query) ||
            (album.genre?.lowercased().contains(query) ?? false)
        }.sorted { $0.name < $1.name }
    }
    
    /// Search in offline songs (cached or downloaded) (unchanged)
    private func searchOfflineSongs(query: String) async -> [Song] {
        var allSongs: [Song] = []
        
        // Search in downloaded albums (unchanged)
        for downloadedAlbum in downloadManager.downloadedAlbums {
            // Try to get songs from album metadata if available (unchanged)
            let albumMetadata = AlbumMetadataCache.shared.getAlbum(id: downloadedAlbum.albumId)
            
            let songs = downloadedAlbum.songs.map { downloadedSong in
                downloadedSong.toSong()
            }
            
            allSongs.append(contentsOf: songs)
        }
        
        // Filter songs by query (unchanged)
        return allSongs.filter { song in
            song.title.lowercased().contains(query) ||
            (song.artist?.lowercased().contains(query) ?? false) ||
            (song.album?.lowercased().contains(query) ?? false)
        }.sorted { $0.title < $1.title }
    }
    
    // MARK: - ✅ SEARCH SUGGESTIONS & AUTOCOMPLETION (unchanged - no service calls)
    
    /// Get search suggestions based on offline content
    func getSearchSuggestions(for partialQuery: String) -> [String] {
        let query = partialQuery.lowercased()
        guard query.count >= 2 else { return [] }
        
        var suggestions: Set<String> = []
        
        // Artist name suggestions (unchanged)
        for artist in offlineManager.offlineArtists {
            if artist.name.lowercased().hasPrefix(query) {
                suggestions.insert(artist.name)
            }
        }
        
        // Album name suggestions (unchanged)
        for album in offlineManager.offlineAlbums {
            if album.name.lowercased().hasPrefix(query) {
                suggestions.insert(album.name)
            }
            if album.artist.lowercased().hasPrefix(query) {
                suggestions.insert(album.artist)
            }
        }
        
        return Array(suggestions).sorted().prefix(5).map { $0 }
    }
    
    /// Get recent search queries (could be extended with persistence) (unchanged)
    func getRecentSearches() -> [String] {
        // For now, return last search if available
        return lastSearchQuery.isEmpty ? [] : [lastSearchQuery]
    }
    
    // MARK: - ✅ SEARCH FILTERING & SORTING (unchanged)
    
    /// Filter current results by type
    func filterResults(by type: SearchResultType) -> SearchResults {
        switch type {
        case .artists:
            return SearchResults(artists: searchResults.artists, albums: [], songs: [])
        case .albums:
            return SearchResults(artists: [], albums: searchResults.albums, songs: [])
        case .songs:
            return SearchResults(artists: [], albums: [], songs: searchResults.songs)
        }
    }
    
    /// Sort results by relevance (name match priority) (unchanged)
    func sortByRelevance(query: String) {
        let lowercaseQuery = query.lowercased()
        
        // Sort artists by relevance (unchanged)
        searchResults.artists.sort { a, b in
            let aStarts = a.name.lowercased().hasPrefix(lowercaseQuery)
            let bStarts = b.name.lowercased().hasPrefix(lowercaseQuery)
            
            if aStarts && !bStarts { return true }
            if !aStarts && bStarts { return false }
            return a.name < b.name
        }
        
        // Sort albums by relevance (unchanged)
        searchResults.albums.sort { a, b in
            let aNameStarts = a.name.lowercased().hasPrefix(lowercaseQuery)
            let bNameStarts = b.name.lowercased().hasPrefix(lowercaseQuery)
            let aArtistStarts = a.artist.lowercased().hasPrefix(lowercaseQuery)
            let bArtistStarts = b.artist.lowercased().hasPrefix(lowercaseQuery)
            
            if aNameStarts && !bNameStarts { return true }
            if !aNameStarts && bNameStarts { return false }
            if aArtistStarts && !bArtistStarts { return true }
            if !aArtistStarts && bArtistStarts { return false }
            return a.name < b.name
        }
        
        // Sort songs by relevance (unchanged)
        searchResults.songs.sort { a, b in
            let aTitleStarts = a.title.lowercased().hasPrefix(lowercaseQuery)
            let bTitleStarts = b.title.lowercased().hasPrefix(lowercaseQuery)
            let aArtistStarts = (a.artist?.lowercased().hasPrefix(lowercaseQuery) ?? false)
            let bArtistStarts = (b.artist?.lowercased().hasPrefix(lowercaseQuery) ?? false)
            
            if aTitleStarts && !bTitleStarts { return true }
            if !aTitleStarts && bTitleStarts { return false }
            if aArtistStarts && !bArtistStarts { return true }
            if !aArtistStarts && bArtistStarts { return false }
            return a.title < b.title
        }
        
        objectWillChange.send()
    }
    
    // MARK: - ✅ SEARCH STATISTICS (updated for SearchService context)
    
    /// Get search mode description
    var searchModeDescription: String {
        let isOffline = !NetworkMonitor.shared.canLoadOnlineContent || offlineManager.isOfflineMode
        return isOffline ? "Searching in downloaded content" : "Searching online library via SearchService"
    }
    
    /// Get search statistics
    func getSearchStats() -> SearchStats {
        return SearchStats(
            isOfflineMode: !NetworkMonitor.shared.canLoadOnlineContent || offlineManager.isOfflineMode,
            totalResults: searchResults.totalCount,
            artistCount: searchResults.artists.count,
            albumCount: searchResults.albums.count,
            songCount: searchResults.songs.count,
            searchQuery: lastSearchQuery,
            hasError: searchError != nil
        )
    }
    
    // MARK: - ✅ ERROR HANDLING (updated for SearchService context)
    
    private func handleSearchError(_ error: Error) -> String {
        if let subsonicError = error as? SubsonicError {
            switch subsonicError {
            case .timeout:
                return "Search timed out via SearchService. Check your connection."
            case .network:
                return "Network error via SearchService. Switching to offline search."
            case .unauthorized:
                return "Authentication failed. Please check your credentials."
            case .emptyResponse:
                return "No results found."
            default:
                return "Search failed via SearchService: \(subsonicError.localizedDescription)"
            }
        } else if let searchError = error as? SearchError {
            return searchError.localizedDescription
        } else {
            return "Search failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - ✅ RESET (unchanged)
    
    func reset() {
        searchResults = SearchResults()
        isSearching = false
        searchError = nil
        lastSearchQuery = ""
        print("✅ SearchManager reset completed")
    }
}

// MARK: - ✅ SUPPORTING TYPES (unchanged)

enum SearchError: LocalizedError {
    case serviceUnavailable
    case invalidQuery
    case noResults
    
    var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "SearchService is not available"
        case .invalidQuery:
            return "Invalid search query"
        case .noResults:
            return "No results found"
        }
    }
}

struct SearchStats {
    let isOfflineMode: Bool
    let totalResults: Int
    let artistCount: Int
    let albumCount: Int
    let songCount: Int
    let searchQuery: String
    let hasError: Bool
    
    var resultSummary: String {
        if totalResults == 0 {
            return "No results"
        }
        
        var parts: [String] = []
        if artistCount > 0 { parts.append("\(artistCount) artist\(artistCount != 1 ? "s" : "")") }
        if albumCount > 0 { parts.append("\(albumCount) album\(albumCount != 1 ? "s" : "")") }
        if songCount > 0 { parts.append("\(songCount) song\(songCount != 1 ? "s" : "")") }
        
        return parts.joined(separator: ", ")
    }
}

// MARK: - ✅ SEARCH PERFORMANCE HELPERS (unchanged)

extension SearchManager {
    
    func searchWithDebounce(query: String, delay: TimeInterval = 0.5) {
        searchTask?.cancel()
        
        searchTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            guard !Task.isCancelled else { return }
            await search(query: query)
        }
    }
    
    /// Cancel any ongoing search
    func cancelSearch() {
        searchTask?.cancel()
        if isSearching {
            isSearching = false
            print("🛑 Search cancelled")
        }
    }
}
