//
//  SearchView.swift - COMPLETE OPTIMIZED VERSION
//  NavidromeClient
//
//  ✅ PRECISE: Field-specific search only
//  ✅ OPTIMIZED: Simplified logic and better state management
//  ✅ FIXED: All previous issues resolved
//

import SwiftUI

struct SearchView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var downloadManager: DownloadManager
    
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
        NavigationStack {
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
            .accountToolbar()
        }
        .onChange(of: query) { _, newValue in
            handleQueryChange(newValue)
        }
        .onDisappear {
            searchTask?.cancel()
        }
    }
    
    // MARK: - ✅ PRECISE Search Logic
    
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
    
    // MARK: - ✅ OFFLINE SEARCH: Field-specific only
    
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
            
            // Collect all songs
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
    
    // MARK: - ✅ ONLINE SEARCH: Field-specific filtering
    
    private func performOnlineSearch(query: String) {
        guard let service = navidromeVM.getService() else {
            searchError = "Service not available"
            isSearching = false
            return
        }
        
        searchTask = Task {
            do {
                let result = try await service.search(query: query, maxResults: 200)
                
                if !Task.isCancelled {
                    await MainActor.run {
                        let filteredResults = filterResultsByField(result, query: query.lowercased())
                        searchResults = filteredResults
                        isSearching = false
                        print("🎯 Online search: Artists:\(filteredResults.artists.count), Albums:\(filteredResults.albums.count), Songs:\(filteredResults.songs.count)")
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        searchError = "Search failed: \(error.localizedDescription)"
                        searchResults = SearchResults()
                        isSearching = false
                    }
                }
            }
        }
    }
    
    private func filterResultsByField(_ result: SearchResult, query: String) -> SearchResults {
        
        // Artists: ONLY where artist.name contains query
        let filteredArtists = result.artists.filter { (artist: Artist) in
            artist.name.lowercased().contains(query)
        }
        let sortedArtists = sortByRelevance(filteredArtists, query: query) { (artist: Artist) in artist.name.lowercased() }
        
        // Albums: ONLY where album.name contains query
        let filteredAlbums = result.albums.filter { (album: Album) in
            album.name.lowercased().contains(query)
        }
        let sortedAlbums = sortByRelevance(filteredAlbums, query: query) { (album: Album) in album.name.lowercased() }
        
        // Songs: ONLY where song.title contains query
        let filteredSongs = result.songs.filter { (song: Song) in
            song.title.lowercased().contains(query)
        }
        let sortedSongs = sortByRelevance(filteredSongs, query: query) { (song: Song) in song.title.lowercased() }
        
        return SearchResults(
            artists: sortedArtists,
            albums: sortedAlbums,
            songs: sortedSongs
        )
    }
    
    // MARK: - ✅ UTILITY: Relevance Sorting
    
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
    
    // MARK: - ✅ STATE Management
    
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
    
    // MARK: - ✅ UI Components
    
    @ViewBuilder
    private func SearchModeHeader() -> some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(BrandColor.warning)
            
            Text("Searching in downloaded music only")
                .font(Typography.caption)
                .foregroundStyle(BrandColor.warning)
            
            Spacer()
        }
        .listItemPadding()
        .background(BrandColor.warning.opacity(0.1), in: RoundedRectangle(cornerRadius: Radius.s))
        .screenPadding()
        .padding(.top, Spacing.xs)
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
            LazyVStack(spacing: Spacing.s) {
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
            .padding(.bottom, 100)
        }
        .id(selectedTab) // Force refresh when tab changes
    }
    
    @ViewBuilder
    private func SearchErrorView(error: String) -> some View {
        VStack(spacing: Spacing.l) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(BrandColor.warning)
            
            VStack(spacing: Spacing.s) {
                Text("Search Error")
                    .font(Typography.headline)
                
                Text(error)
                    .font(Typography.subheadline)
                    .foregroundStyle(TextColor.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Try Again") {
                performSearch()
            }
            .primaryButtonStyle()
        }
        .padding(Spacing.xl)
        .materialCardStyle()
    }
    
    @ViewBuilder
    private func SearchEmptyView() -> some View {
        VStack(spacing: Spacing.l) {
            Image(systemName: shouldUseOfflineSearch ? "arrow.down.circle" : "music.note.house")
                .font(.system(size: 60))
                .foregroundStyle(TextColor.secondary)
            
            VStack(spacing: Spacing.s) {
                Text("No Results")
                    .font(Typography.title2)
                
                Text(shouldUseOfflineSearch ?
                     "No downloads found matching your search" :
                     "Try different search terms")
                    .font(Typography.subheadline)
                    .foregroundStyle(TextColor.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Spacing.xl)
        .materialCardStyle()
    }
    
    @ViewBuilder
    private func SearchInitialView() -> some View {
        VStack(spacing: Spacing.l) {
            Image(systemName: shouldUseOfflineSearch ? "arrow.down.circle" : "magnifyingglass.circle")
                .font(.system(size: 80))
                .foregroundStyle(TextColor.secondary.opacity(0.6))
            
            VStack(spacing: Spacing.s) {
                Text(shouldUseOfflineSearch ? "Search Downloads" : "Search Music")
                    .font(Typography.title2)
                
                Text(shouldUseOfflineSearch ?
                     "Search through your downloaded albums" :
                     "Search for artists, albums, or songs")
                    .font(Typography.subheadline)
                    .foregroundStyle(TextColor.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Padding.xl)
        .materialCardStyle()
    }
    
    @ViewBuilder
    private func SearchLoadingView() -> some View {
        VStack(spacing: Spacing.l) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Searching...")
                .font(Typography.headline)
                .foregroundStyle(TextColor.primary)
            
            Text(searchModeDescription)
                .font(Typography.caption)
                .foregroundStyle(TextColor.secondary)
        }
        .padding(Spacing.xl)
        .materialCardStyle()
    }
}

// MARK: - ✅ Search Header Components

struct SearchHeaderView: View {
    @Binding var query: String
    @Binding var selectedTab: SearchView.SearchTab
    let countForTab: (SearchView.SearchTab) -> Int
    let onSearch: () -> Void
    let onClear: () -> Void
    
    var body: some View {
        VStack(spacing: Spacing.m) {
            // Search Bar
            HStack(spacing: Spacing.s) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(TextColor.secondary)
                    .font(Typography.title3)
                
                TextField("Search music...", text: $query)
                    .font(Typography.body)
                    .submitLabel(.search)
                    .onSubmit(onSearch)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                
                if !query.isEmpty {
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(TextColor.secondary)
                    }
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.horizontal, Padding.m)
            .padding(.vertical, Padding.s)
            .background(BackgroundColor.thin, in: RoundedRectangle(cornerRadius: Radius.l))
            .animation(Animations.ease, value: query.isEmpty)
            
            // Search Tabs
            HStack(spacing: Spacing.s) {
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
        .background(BackgroundColor.thin)
    }
}

struct SearchTabButton: View {
    let tab: SearchView.SearchTab
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: tab.icon)
                    .font(Typography.caption)
                
                Text(tab.rawValue)
                    .font(Typography.caption)
                
                if count > 0 {
                    Text("\(count)")
                        .font(Typography.caption2)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, Spacing.xs/2)
                        .background(Capsule().fill(isSelected ? TextColor.onDark.opacity(0.3) : BackgroundColor.secondary))
                        .foregroundStyle(isSelected ? TextColor.onDark : TextColor.secondary)
                }
            }
            .padding(.vertical, Padding.s)
            .padding(.horizontal, Padding.m)
            .background(
                RoundedRectangle(cornerRadius: Radius.m)
                    .fill(isSelected ? BrandColor.primary : BackgroundColor.secondary)
            )
            .foregroundStyle(isSelected ? TextColor.onDark : TextColor.primary)
        }
        .animation(Animations.ease, value: isSelected)
        .animation(Animations.ease, value: count)
    }
}
