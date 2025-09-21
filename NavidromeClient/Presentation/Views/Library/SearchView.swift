//
//  SearchView.swift - CLEAN ARCHITECTURE FIXED
//  NavidromeClient
//
//   FIXED: All compile errors resolved
//   CLEAN: Direct manager access, no service extraction
//   SUSTAINABLE: Proper error handling and state management
//

import SwiftUI

struct SearchView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var coverArtManager: CoverArtManager
    
    @State private var query: String = ""
    @State private var selectedTab: SearchTab = .songs
    @State private var searchResults = SearchResults()
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var searchTask: Task<Void, Never>?
    
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
    
    // MARK: - Computed Properties
    
    private var shouldUseOfflineSearch: Bool {
        return !networkMonitor.canLoadOnlineContent || offlineManager.isOfflineMode
    }
    
    private var hasResults: Bool {
        return !searchResults.isEmpty
    }
    
    private var resultCount: Int {
        return searchResults.count(for: selectedTab)
    }
    
    private var searchModeDescription: String {
        return shouldUseOfflineSearch ? "Searching in downloaded content" : "Searching online library"
    }
    
    // MARK: - Main View
    
    var body: some View {
        Group {
            VStack(spacing: 0) {
                if shouldUseOfflineSearch {
                    SearchModeHeader()
                }
                
                SearchHeaderView(
                    query: $query,
                    selectedTab: $selectedTab,
                    countForTab: countForTab,
                    onSearch: performSearch,
                    onClear: clearSearch
                )
                
                SearchContentView()
                
                Spacer()
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
        }
        .onChange(of: query) { _, newValue in
            handleQueryChange(newValue)
        }
        .onDisappear {
            searchTask?.cancel()
        }
    }
    
    // MARK: -  CLEAN: Search Logic via NavidromeViewModel Only
    
    private func handleQueryChange(_ newValue: String) {
        searchTask?.cancel()
        
        let trimmedQuery = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedQuery.isEmpty {
            clearResults()
            return
        }
        
        // Debounce search
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
            
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
        // Clear previous results immediately
        searchResults = SearchResults()
        searchError = nil
        isSearching = true
        
        if shouldUseOfflineSearch {
            performOfflineSearch(query: query)
        } else {
            performOnlineSearch(query: query)
        }
    }
    
    // MARK: -  OFFLINE SEARCH: Field-specific only
    
    private func performOfflineSearch(query: String) {
        searchTask = Task {
            let lowercaseQuery = query.lowercased()
            
            // Artists: ONLY search in artist.name
            let artists = await searchArtistsByName(query: lowercaseQuery)
            
            // Albums: ONLY search in album.name
            let albums = await searchAlbumsByName(query: lowercaseQuery)
            
            // Songs: ONLY search in song.title
            let songs = await searchSongsByTitle(query: lowercaseQuery)
            
            if !Task.isCancelled {
                await MainActor.run {
                    searchResults = SearchResults(
                        artists: artists,
                        albums: albums,
                        songs: songs
                    )
                    isSearching = false
                    print("🎯 Offline search: Artists:\(artists.count), Albums:\(albums.count), Songs:\(songs.count)")
                }
            }
        }
    }
    
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
                album.name.lowercased().contains(query)
            }
            
            return sortByRelevance(matches, query: query) { $0.name.lowercased() }
        }
    }
    
    private func searchSongsByTitle(query: String) async -> [Song] {
        return await MainActor.run {
            var allSongs: [Song] = []
            
            // Collect all songs from downloaded albums
            for downloadedAlbum in downloadManager.downloadedAlbums {
                if let cachedSongs = navidromeVM.albumSongs[downloadedAlbum.albumId] {
                    allSongs.append(contentsOf: cachedSongs)
                } else {
                    let songs = downloadedAlbum.songs.map { $0.toSong() }
                    allSongs.append(contentsOf: songs)
                }
            }
            
            // Filter: ONLY song.title contains query
            let matches = allSongs.filter { song in
                song.title.lowercased().contains(query)
            }
            
            return sortByRelevance(matches, query: query) { $0.title.lowercased() }
        }
    }
    
    // MARK: -  ONLINE SEARCH: Via NavidromeViewModel Only
    
    private func performOnlineSearch(query: String) {
        searchTask = Task {
            //  ROUTE: Through NavidromeViewModel only (no direct service access)
            let result = await navidromeVM.search(query: query)
            
            if !Task.isCancelled {
                await MainActor.run {
                    let filteredResults = filterResultsByField(result, query: query.lowercased())
                    searchResults = filteredResults
                    isSearching = false
                    print("🎯 Online search via NavidromeVM: Artists:\(filteredResults.artists.count), Albums:\(filteredResults.albums.count), Songs:\(filteredResults.songs.count)")
                }
            }
        }
    }
    
    private func filterResultsByField(_ result: SearchResult, query: String) -> SearchResults {
        
        // Artists: ONLY where artist.name contains query
        let filteredArtists = result.artists.filter { artist in
            artist.name.lowercased().contains(query)
        }
        let sortedArtists = sortByRelevance(filteredArtists, query: query) { artist in
            artist.name.lowercased()
        }
        
        // Albums: ONLY where album.name contains query
        let filteredAlbums = result.albums.filter { album in
            album.name.lowercased().contains(query)
        }
        let sortedAlbums = sortByRelevance(filteredAlbums, query: query) { album in
            album.name.lowercased()
        }
        
        // Songs: ONLY where song.title contains query
        let filteredSongs = result.songs.filter { song in
            song.title.lowercased().contains(query)
        }
        let sortedSongs = sortByRelevance(filteredSongs, query: query) { song in
            song.title.lowercased()
        }
        
        return SearchResults(
            artists: sortedArtists,
            albums: sortedAlbums,
            songs: sortedSongs
        )
    }
    
    // MARK: -  UTILITY: Relevance Sorting
    
    private func sortByRelevance<T>(_ items: [T], query: String, keyPath: (T) -> String) -> [T] {
        return items.sorted { item1, item2 in
            let text1 = keyPath(item1)
            let text2 = keyPath(item2)
            
            // Exact match first
            if text1 == query && text2 != query { return true }
            if text2 == query && text1 != query { return false }
            
            // Starts with second
            let starts1 = text1.hasPrefix(query)
            let starts2 = text2.hasPrefix(query)
            if starts1 && !starts2 { return true }
            if starts2 && !starts1 { return false }
            
            // Alphabetical for same match type
            return text1 < text2
        }
    }
    
    // MARK: -  STATE Management
    
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
    
    private func countForTab(_ tab: SearchTab) -> Int {
        return searchResults.count(for: tab)
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
    
    // MARK: -  UI Components
    
    @ViewBuilder
    private func SearchModeHeader() -> some View {
        HStack(spacing: DSLayout.elementGap) {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(DSColor.warning)
            
            Text("Searching in downloaded music only")
                .font(DSText.metadata)
                .foregroundStyle(DSColor.warning)
            
            Spacer()
        }
        .listItemPadding()
        .background(DSColor.warning.opacity(0.1), in: RoundedRectangle(cornerRadius: DSCorners.element))
        .screenPadding()
        .padding(.top, DSLayout.tightGap)
    }
    
    @ViewBuilder
    private func SearchContentView() -> some View {
        Group {
            if let error = searchError {
                SearchErrorView(error: error)
            } else if hasResults {
                SearchResultsView()
            } else if !query.isEmpty && !isSearching {
                SearchEmptyView()
            } else if query.isEmpty {
                SearchInitialView()
            } else if isSearching {
                SearchLoadingView()
            }
        }
    }
    
    @ViewBuilder
    private func SearchResultsView() -> some View {
        ScrollView {
            LazyVStack(spacing: DSLayout.elementGap) {
                switch selectedTab {
                case .artists:
                    ForEach(searchResults.artists.indices, id: \.self) { index in
                        SearchResultArtistRow(artist: searchResults.artists[index], index: index)
                    }
                    
                case .albums:
                    ForEach(searchResults.albums.indices, id: \.self) { index in
                        SearchResultAlbumRow(album: searchResults.albums[index], index: index)
                    }
                    
                case .songs:
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
            }
            .screenPadding()
            .padding(.bottom, DSLayout.miniPlayerHeight)
        }
        .id(selectedTab) // Force refresh when tab changes 
    }
    
    @ViewBuilder
    private func SearchErrorView(error: String) -> some View {
        VStack(spacing: DSLayout.sectionGap) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(DSColor.warning)
            
            VStack(spacing: DSLayout.elementGap) {
                Text("Search Error")
                    .font(DSText.prominent)
                
                Text(error)
                    .font(DSText.sectionTitle)
                    .foregroundStyle(DSColor.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Try Again") {
                performSearch()
            }
        }
        .padding(DSLayout.screenGap)
        .cardStyle()
        .screenPadding()
    }
    
    @ViewBuilder
    private func SearchEmptyView() -> some View {
        VStack(spacing: DSLayout.sectionGap) {
            Image(systemName: shouldUseOfflineSearch ? "arrow.down.circle" : "music.note.house")
                .font(.system(size: 60))
                .foregroundStyle(DSColor.secondary)
            
            VStack(spacing: DSLayout.elementGap) {
                Text("No Results")
                    .font(DSText.sectionTitle)
                
                Text(shouldUseOfflineSearch ?
                     "No downloads found matching your search" :
                     "Try different search terms")
                    .font(DSText.sectionTitle)
                    .foregroundStyle(DSColor.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(DSLayout.screenGap)
        .cardStyle()
        .screenPadding()
    }
    
    @ViewBuilder
    private func SearchInitialView() -> some View {
        VStack(spacing: DSLayout.sectionGap) {
            Image(systemName: shouldUseOfflineSearch ? "arrow.down.circle" : "magnifyingglass.circle")
                .font(.system(size: 80))
                .foregroundStyle(DSColor.secondary.opacity(0.6))
            
            VStack(spacing: DSLayout.elementGap) {
                Text(shouldUseOfflineSearch ? "Search Downloads" : "Search Music")
                    .font(DSText.sectionTitle)
                
                Text(shouldUseOfflineSearch ?
                     "Search through your downloaded albums" :
                     "Search for artists, albums, or songs")
                    .font(DSText.sectionTitle)
                    .foregroundStyle(DSColor.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(DSLayout.screenPadding)
        .cardStyle()
        .screenPadding()
    }
    
    @ViewBuilder
    private func SearchLoadingView() -> some View {
        VStack(spacing: DSLayout.sectionGap) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Searching...")
                .font(DSText.prominent)
                .foregroundStyle(DSColor.primary)
            
            Text(searchModeDescription)
                .font(DSText.metadata)
                .foregroundStyle(DSColor.secondary)
        }
        .padding(DSLayout.screenGap)
        .cardStyle()
        .screenPadding()
    }
}

// MARK: -  Search Header Components

struct SearchHeaderView: View {
    @Binding var query: String
    @Binding var selectedTab: SearchView.SearchTab
    let countForTab: (SearchView.SearchTab) -> Int
    let onSearch: () -> Void
    let onClear: () -> Void
    
    var body: some View {
        VStack(spacing: DSLayout.contentGap) {
            // Search Bar
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
            .background(DSColor.background, in: RoundedRectangle(cornerRadius: DSCorners.comfortable))
            .animation(DSAnimations.ease, value: query.isEmpty)
            
            // Search Tabs
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
        .background(DSColor.background)
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
