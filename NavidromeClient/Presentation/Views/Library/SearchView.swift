//
//  SearchView.swift - MIGRATED: Unified State System
//  NavidromeClient
//
//   UNIFIED: Single ContentLoadingStrategy for consistent state
//   CLEAN: Proper offline/online search routing
//   FIXED: Consistent state management pattern
//

import SwiftUI

struct SearchView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var coverArtManager: CoverArtManager
    @EnvironmentObject var appConfig: AppConfig
    
    @State private var query: String = ""
    @State private var selectedTab: SearchTab = .songs
    @State private var searchResults = SearchResults()
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var searchTask: Task<Void, Never>?
    
    // UNIFIED: Single state logic following the pattern
    private var hasQuery: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var currentState: ViewState? {
        if appConfig.isInitializingServices {
            return .loading("Setting up your music library")
        } else if let error = searchError, !isSearching {
            return .serverError
        } else if !hasQuery && !isSearching {
            return .empty(type: .search)
        } else if isSearching {
            return .loading("Searching your music")
        } else if hasQuery && searchResults.isEmpty && !isSearching {
            return .empty(type: .search)
        }
        return nil
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // UNIFIED: Consistent offline banner pattern
                if case .offlineOnly(let reason) = networkMonitor.contentLoadingStrategy {
                    SearchModeHeader(reason: reason)
                }
                
                SearchHeaderView(
                    query: $query,
                    selectedTab: $selectedTab,
                    countForTab: { searchResults.count(for: $0) },
                    onSearch: performSearch,
                    onClear: clearSearch
                )
                
                // UNIFIED: Single component handles all states
                if let state = currentState {
                    UnifiedStateView(
                        state: state,
                        primaryAction: StateAction("Try Again") {
                            performSearch()
                        }
                    )
                } else if searchResults.totalCount > 0 {
                    searchResultsContainer
                }
                
                Spacer()
            }
            .navigationTitle("Search your music")
            .navigationBarTitleDisplayMode(.automatic)
            .navigationDestination(for: Artist.self) { artist in
                AlbumCollectionView(context: .byArtist(artist))
            }
            .navigationDestination(for: Album.self) { album in
                AlbumDetailViewContent(album: album)
            }
        }
        .onChange(of: query) { _, newValue in
            handleQueryChange(newValue)
        }
        .onDisappear {
            searchTask?.cancel()
        }
    }

    @ViewBuilder
    private var searchResultsContainer: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                switch selectedTab {
                case .artists:
                    LazyVStack(spacing: DSLayout.elementGap) {
                        ForEach(searchResults.artists.indices, id: \.self) { index in
                            let artist = searchResults.artists[index]
                            
                            NavigationLink(value: artist) {
                                SearchResultArtistRow(artist: artist, index: index)
                            }
                        }
                    }
                    .padding(.horizontal, DSLayout.screenPadding)
                    .padding(.bottom, DSLayout.miniPlayerHeight)
                    
                case .albums:
                    LazyVStack(spacing: DSLayout.elementGap) {
                        ForEach(searchResults.albums.indices, id: \.self) { index in
                            let album = searchResults.albums[index]
                            
                            NavigationLink(value: album) {
                                SearchResultAlbumRow(album: album, index: index)
                            }
                        }
                    }
                    .padding(.horizontal, DSLayout.screenPadding)
                    .padding(.bottom, DSLayout.miniPlayerHeight)
                    
                case .songs:
                    LazyVStack(spacing: DSLayout.elementGap) {
                        ForEach(searchResults.songs.indices, id: \.self) { index in
                            let song = searchResults.songs[index]
                            
                            SearchResultSongRow(
                                song: song,
                                index: index + 1,
                                isPlaying: playerVM.currentSong?.id == song.id && playerVM.isPlaying,
                                action: { handleSongTap(at: index) }
                            )
                        }
                    }
                    .padding(.horizontal, DSLayout.screenPadding)
                    .padding(.bottom, DSLayout.miniPlayerHeight)
                }
            }
        }
    }
    
    // MARK: - Search Logic
    
    private func handleQueryChange(_ newValue: String) {
        searchTask?.cancel()
        
        let trimmedQuery = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedQuery.isEmpty {
            clearResults()
            return
        }
        
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            
            if !Task.isCancelled {
                await MainActor.run {
                    performSearchInternal(query: trimmedQuery)
                }
            }
        }
    }
    
    private func performSearch() {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }
        
        searchTask?.cancel()
        performSearchInternal(query: trimmedQuery)
    }
    
    private func performSearchInternal(query: String) {
        searchResults = SearchResults()
        searchError = nil
        isSearching = true
        
        // UNIFIED: Use contentLoadingStrategy for search routing
        switch networkMonitor.contentLoadingStrategy {
        case .online:
            performOnlineSearch(query: query)
        case .offlineOnly:
            performOfflineSearch(query: query)
        }
    }
    
    private func performOfflineSearch(query: String) {
        searchTask = Task {
            let lowercaseQuery = query.lowercased()
            
            let artists = await searchArtistsByName(query: lowercaseQuery)
            let albums = await searchAlbumsByName(query: lowercaseQuery)
            let songs = await searchSongsByTitle(query: lowercaseQuery)
            
            if !Task.isCancelled {
                await MainActor.run {
                    searchResults = SearchResults(
                        artists: artists,
                        albums: albums,
                        songs: songs
                    )
                    isSearching = false
                    print("Offline search completed: Artists:\(artists.count), Albums:\(albums.count), Songs:\(songs.count)")
                }
            }
        }
    }
    
    private func performOnlineSearch(query: String) {
        searchTask = Task {
            let result = await navidromeVM.search(query: query)
            
            if !Task.isCancelled {
                await MainActor.run {
                    let filteredResults = filterResultsByField(result, query: query.lowercased())
                    searchResults = filteredResults
                    isSearching = false
                    print("Online search completed: Artists:\(filteredResults.artists.count), Albums:\(filteredResults.albums.count), Songs:\(filteredResults.songs.count)")
                }
            }
        }
    }
    
    // MARK: - Offline Search Implementation
    
    private func searchArtistsByName(query: String) async -> [Artist] {
        return await MainActor.run {
            let matches = offlineManager.offlineArtists.filter { artist in
                artist.name.lowercased().contains(query)
            }
            return sortByRelevance(matches, query: query) { $0.name.lowercased() }
        }
    }
    
    private func searchAlbumsByName(query: String) async -> [Album] {
        return await MainActor.run {
            let matches = offlineManager.offlineAlbums.filter { album in
                album.name.lowercased().contains(query) ||
                album.artist.lowercased().contains(query)
            }
            return sortByRelevance(matches, query: query) { $0.name.lowercased() }
        }
    }
    
    private func searchSongsByTitle(query: String) async -> [Song] {
        return await MainActor.run {
            var allSongs: [Song] = []
            
            for downloadedAlbum in downloadManager.downloadedAlbums {
                if let cachedSongs = navidromeVM.albumSongs[downloadedAlbum.albumId] {
                    allSongs.append(contentsOf: cachedSongs)
                } else {
                    let songs = downloadedAlbum.songs.map { $0.toSong() }
                    allSongs.append(contentsOf: songs)
                }
            }
            
            let matches = allSongs.filter { song in
                song.title.lowercased().contains(query) ||
                (song.artist ?? "").lowercased().contains(query)
            }
            
            return sortByRelevance(matches, query: query) { $0.title.lowercased() }
        }
    }
    
    private func filterResultsByField(_ result: SearchResult, query: String) -> SearchResults {
        let filteredArtists = result.artists.filter { artist in
            artist.name.lowercased().contains(query)
        }
        let sortedArtists = sortByRelevance(filteredArtists, query: query) { $0.name.lowercased() }
        
        let filteredAlbums = result.albums.filter { album in
            album.name.lowercased().contains(query) ||
            album.artist.lowercased().contains(query)
        }
        let sortedAlbums = sortByRelevance(filteredAlbums, query: query) { $0.name.lowercased() }
        
        let filteredSongs = result.songs.filter { song in
            song.title.lowercased().contains(query) ||
            (song.artist ?? "").lowercased().contains(query)
        }
        let sortedSongs = sortByRelevance(filteredSongs, query: query) { $0.title.lowercased() }
        
        return SearchResults(
            artists: sortedArtists,
            albums: sortedAlbums,
            songs: sortedSongs
        )
    }
    
    private func sortByRelevance<T>(_ items: [T], query: String, keyPath: (T) -> String) -> [T] {
        return items.sorted { item1, item2 in
            let text1 = keyPath(item1)
            let text2 = keyPath(item2)
            
            // Exact match first
            if text1 == query && text2 != query { return true }
            if text2 == query && text1 != query { return false }
            
            // Starts with query second
            let starts1 = text1.hasPrefix(query)
            let starts2 = text2.hasPrefix(query)
            if starts1 && !starts2 { return true }
            if starts2 && !starts1 { return false }
            
            // Alphabetical order
            return text1 < text2
        }
    }
    
    // MARK: - State Management
    
    private func clearResults() {
        searchTask?.cancel()
        searchResults = SearchResults()
        searchError = nil
        isSearching = false
    }
    
    private func clearSearch() {
        searchTask?.cancel()
        query = ""
        searchResults = SearchResults()
        searchError = nil
        isSearching = false
    }
    
    private func handleSongTap(at index: Int) {
        Task {
            await playerVM.setPlaylist(
                searchResults.songs,
                startIndex: index,
                albumId: nil
            )
        }
    }
}

// MARK: - Supporting Types

extension SearchView {
    enum SearchTab: String, CaseIterable {
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

    struct SearchResults {
        var artists: [Artist] = []
        var albums: [Album] = []
        var songs: [Song] = []
        
        var isEmpty: Bool {
            artists.isEmpty && albums.isEmpty && songs.isEmpty
        }
        
        var totalCount: Int {
            artists.count + albums.count + songs.count
        }
        
        func count(for type: SearchTab) -> Int {
            switch type {
            case .artists: return artists.count
            case .albums: return albums.count
            case .songs: return songs.count
            }
        }
    }
}

// MARK: - Search UI Components

struct SearchModeHeader: View {
    let reason: ContentLoadingStrategy.OfflineReason
    @EnvironmentObject private var offlineManager: OfflineManager
    
    var body: some View {
        HStack(spacing: DSLayout.elementGap) {
            Image(systemName: reason.icon)
                .foregroundStyle(reason.color)
            
            Text("Searching in downloaded music only")
                .font(DSText.metadata)
                .foregroundStyle(reason.color)
            
            Spacer()
            
            if reason.canGoOnline {
                Button(reason.actionTitle) {
                    reason.performAction(offlineManager: offlineManager)
                }
                .font(DSText.metadata)
                .foregroundStyle(DSColor.accent)
            }
        }
        .listItemPadding()
        .background(reason.color.opacity(0.1), in: RoundedRectangle(cornerRadius: DSCorners.element))
        .padding(.horizontal, DSLayout.screenPadding)
        .padding(.top, DSLayout.tightGap)
    }
}

struct SearchHeaderView: View {
    @Binding var query: String
    @Binding var selectedTab: SearchView.SearchTab
    let countForTab: (SearchView.SearchTab) -> Int
    let onSearch: () -> Void
    let onClear: () -> Void
    
    var body: some View {
        VStack(spacing: DSLayout.contentGap) {
            HStack(spacing: DSLayout.elementGap) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DSColor.secondary)
                    .font(DSText.sectionTitle)
                
                TextField("Search music...", text: $query)
                    .font(DSText.body)
                    .submitLabel(.search)
                    .onSubmit(onSearch)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                
                if !query.isEmpty {
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DSColor.secondary)
                    }
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.horizontal, DSLayout.contentPadding)
            .padding(.vertical, DSLayout.elementPadding)
            .background(DSMaterial.background, in: RoundedRectangle(cornerRadius: DSCorners.comfortable))
            .animation(DSAnimations.ease, value: query.isEmpty)
            
            HStack(spacing: DSLayout.elementGap) {
                ForEach(SearchView.SearchTab.allCases, id: \.self) { tab in
                    SearchTabButton(
                        tab: tab,
                        count: countForTab(tab),
                        isSelected: selectedTab == tab,
                        onTap: { selectedTab = tab }
                    )
                }
            }
        }
        .listItemPadding()
        .background(DSMaterial.background)
    }
}

struct SearchTabButton: View {
    let tab: SearchView.SearchTab
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DSLayout.tightGap) {
                Image(systemName: tab.icon)
                    .font(DSText.metadata)
                
                Text(tab.rawValue)
                    .font(DSText.metadata)
                
                if count > 0 {
                    Text("\(count)")
                        .font(DSText.body)
                        .padding(.horizontal, DSLayout.tightGap)
                        .padding(.vertical, DSLayout.tightGap/2)
                        .background(Capsule().fill(isSelected ? DSColor.onDark.opacity(0.3) : DSColor.surface))
                        .foregroundStyle(isSelected ? DSColor.onDark : DSColor.secondary)
                }
            }
            .padding(.vertical, DSLayout.elementPadding)
            .padding(.horizontal, DSLayout.contentPadding)
            .background(
                RoundedRectangle(cornerRadius: DSCorners.content)
                    .fill(isSelected ? DSColor.accent : DSColor.surface)
            )
            .foregroundStyle(isSelected ? DSColor.onDark : DSColor.primary)
        }
        .animation(DSAnimations.ease, value: isSelected)
        .animation(DSAnimations.ease, value: count)
    }
}

// MARK: - Supporting Types

