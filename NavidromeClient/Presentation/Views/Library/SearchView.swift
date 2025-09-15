//
//  SearchView.swift - Enhanced with Offline Search Support
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
    @StateObject private var debouncer = Debouncer()
    
    // ✅ NEW: Offline search results
    @State private var offlineSearchResults = OfflineSearchResults()
    
    enum SearchTab: String, CaseIterable {
        case artists = "Künstler"
        case albums = "Alben"
        case songs = "Songs"
        
        var icon: String {
            switch self {
            case .artists: return "person.2.fill"
            case .albums: return "record.circle.fill"
            case .songs: return "music.note"
            }
        }
    }
    
    struct OfflineSearchResults {
        var artists: [Artist] = []
        var albums: [Album] = []
        var songs: [Song] = []
    }
    
    private var hasResults: Bool {
        if shouldUseOfflineSearch {
            return !offlineSearchResults.artists.isEmpty ||
                   !offlineSearchResults.albums.isEmpty ||
                   !offlineSearchResults.songs.isEmpty
        } else {
            return !navidromeVM.artists.isEmpty ||
                   !navidromeVM.albums.isEmpty ||
                   !navidromeVM.songs.isEmpty
        }
    }
    
    private var shouldUseOfflineSearch: Bool {
        return !networkMonitor.canLoadOnlineContent || offlineManager.isOfflineMode
    }
    
    private var resultCount: Int {
        if shouldUseOfflineSearch {
            switch selectedTab {
            case .artists: return offlineSearchResults.artists.count
            case .albums: return offlineSearchResults.albums.count
            case .songs: return offlineSearchResults.songs.count
            }
        } else {
            switch selectedTab {
            case .artists: return navidromeVM.artists.count
            case .albums: return navidromeVM.albums.count
            case .songs: return navidromeVM.songs.count
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ✅ NEW: Search Mode Indicator
                SearchModeHeader(isOfflineSearch: shouldUseOfflineSearch)
                
                SearchHeaderView(
                    query: $query,
                    selectedTab: $selectedTab,
                    countForTab: countForTab,
                    onSearch: performSearch,
                    onClear: clearResults
                )
                
                SearchContentView(
                    query: query,
                    selectedTab: selectedTab,
                    hasResults: hasResults,
                    isOfflineSearch: shouldUseOfflineSearch,
                    navidromeVM: navidromeVM,
                    offlineSearchResults: offlineSearchResults,
                    playerVM: playerVM,
                    onSongTap: handleSongTap
                )
                
                Spacer()
            }
            .navigationTitle("Suche")
            .navigationBarTitleDisplayMode(.large)
            .accountToolbar()
        }
        .onChange(of: query) { _, newValue in
            handleQueryChange(newValue)
        }
    }
    
    // ✅ ENHANCED: Smart Search Logic
    private func performSearch() {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if shouldUseOfflineSearch {
            performOfflineSearch(query: trimmedQuery)
        } else {
            Task {
                await navidromeVM.search(query: trimmedQuery)
            }
        }
    }
    
    // ✅ NEW: Offline Search Implementation
    private func performOfflineSearch(query: String) {
        let lowercaseQuery = query.lowercased()
        
        // Search in offline albums
        let searchableAlbums = offlineManager.offlineAlbums
        offlineSearchResults.albums = searchableAlbums.filter { album in
            album.name.lowercased().contains(lowercaseQuery) ||
            album.artist.lowercased().contains(lowercaseQuery) ||
            (album.genre?.lowercased().contains(lowercaseQuery) ?? false)
        }
        
        // Search in offline artists
        offlineSearchResults.artists = offlineManager.offlineArtists.filter { artist in
            artist.name.lowercased().contains(lowercaseQuery)
        }
        
        // Search in offline songs
        offlineSearchResults.songs = searchOfflineSongs(query: lowercaseQuery)
        
        print("🔍 Offline search for '\(query)': \(offlineSearchResults.albums.count) albums, \(offlineSearchResults.artists.count) artists, \(offlineSearchResults.songs.count) songs")
    }
    
    // ✅ NEW: Search Songs in Downloaded Albums
    private func searchOfflineSongs(query: String) -> [Song] {
        var allSongs: [Song] = []
        
        for downloadedAlbum in downloadManager.downloadedAlbums {
            // Get cached songs for this album
            if let cachedSongs = navidromeVM.albumSongs[downloadedAlbum.albumId] {
                allSongs.append(contentsOf: cachedSongs)
            } else {
                // Create minimal song objects from downloaded files
                let albumMetadata = AlbumMetadataCache.shared.getAlbum(id: downloadedAlbum.albumId)
                let songs = downloadedAlbum.songIds.enumerated().map { index, songId in
                    Song.createFromDownload(
                        id: songId,
                        title: "Track \(index + 1)",
                        duration: nil,
                        coverArt: downloadedAlbum.albumId,
                        artist: albumMetadata?.artist ?? "Unknown Artist",
                        album: albumMetadata?.name ?? "Unknown Album",
                        albumId: downloadedAlbum.albumId,
                        track: index + 1,
                        year: albumMetadata?.year,
                        genre: albumMetadata?.genre,
                        contentType: "audio/mpeg"
                    )
                }
                allSongs.append(contentsOf: songs)
            }
        }
        
        // Filter songs by query
        return allSongs.filter { song in
            song.title.lowercased().contains(query) ||
            (song.artist?.lowercased().contains(query) ?? false) ||
            (song.album?.lowercased().contains(query) ?? false)
        }
    }
    
    private func clearResults() {
        navidromeVM.artists = []
        navidromeVM.albums = []
        navidromeVM.songs = []
        navidromeVM.errorMessage = nil
        
        // ✅ NEW: Clear offline results
        offlineSearchResults = OfflineSearchResults()
    }
    
    private func countForTab(_ tab: SearchTab) -> Int {
        if shouldUseOfflineSearch {
            switch tab {
            case .artists: return offlineSearchResults.artists.count
            case .albums: return offlineSearchResults.albums.count
            case .songs: return offlineSearchResults.songs.count
            }
        } else {
            switch tab {
            case .artists: return navidromeVM.artists.count
            case .albums: return navidromeVM.albums.count
            case .songs: return navidromeVM.songs.count
            }
        }
    }
    
    private func handleQueryChange(_ newValue: String) {
        debouncer.debounce {
            if !newValue.isEmpty {
                performSearch()
            }
        }
    }
    
    private func handleSongTap(at index: Int) {
        let songsToPlay: [Song]
        
        if shouldUseOfflineSearch {
            songsToPlay = offlineSearchResults.songs
        } else {
            songsToPlay = navidromeVM.songs
        }
        
        Task {
            await playerVM.setPlaylist(
                songsToPlay,
                startIndex: index,
                albumId: nil
            )
        }
    }
}

// MARK: - SearchHeaderView (Enhanced with DS)
struct SearchHeaderView: View {
    @Binding var query: String
    @Binding var selectedTab: SearchView.SearchTab
    let countForTab: (SearchView.SearchTab) -> Int
    let onSearch: () -> Void
    let onClear: () -> Void
    
    var body: some View {
        VStack(spacing: Spacing.m) {
            SearchBarView(
                query: $query,
                onSearch: onSearch,
                onClear: onClear
            )
            
            SearchTabsView(
                selectedTab: $selectedTab,
                countForTab: countForTab
            )
        }
        .padding(.top, Spacing.s)
        .background(BackgroundColor.thin)
    }
}

// MARK: - SearchBarView (Enhanced with DS)
struct SearchBarView: View {
    @Binding var query: String
    let onSearch: () -> Void
    let onClear: () -> Void
    
    var body: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(TextColor.secondary)
                .font(Typography.title3)
            
            TextField("Nach Musik suchen...", text: $query)
                .font(Typography.body)
                .submitLabel(.search)
                .onSubmit(onSearch)
            
            if !query.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(TextColor.secondary)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, Padding.m)
        .padding(.vertical, Padding.s)
        .background(
            RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                .fill(BackgroundColor.thin)
                .miniShadow()
        )
        .animation(Animations.ease, value: query.isEmpty)
    }
}

// MARK: - SearchTabsView (Enhanced with DS)
struct SearchTabsView: View {
    @Binding var selectedTab: SearchView.SearchTab
    let countForTab: (SearchView.SearchTab) -> Int
    
    var body: some View {
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
        .listItemPadding()
    }
}

// MARK: - SearchTabButton (Enhanced with DS)
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
                
                if count > 0 {
                    Text("\(count)")
                        .font(Typography.caption2)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, Spacing.xs)
                        .background(countBackground)
                        .clipShape(Capsule())
                        .foregroundStyle(isSelected ? TextColor.onDark : TextColor.primary)
                }
            }
            .padding(.vertical, Padding.s)
            .padding(.horizontal, Padding.s)
            .background(tabBackground)
            .foregroundStyle(isSelected ? TextColor.onDark : TextColor.primary)
        }
        .animation(Animations.ease, value: isSelected)
    }
    
    @ViewBuilder
    private var countBackground: some View {
        if isSelected {
            LinearGradient(
                colors: [BrandColor.primary, BrandColor.secondary],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            BackgroundColor.secondary
        }
    }
    
    private var tabBackground: some View {
        RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
            .fill(
                isSelected
                ? AnyShapeStyle(LinearGradient(
                    colors: [BrandColor.primary, BrandColor.secondary],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                : AnyShapeStyle(BackgroundColor.secondary)
            )
    }
}

// MARK: - SearchErrorView (Enhanced with DS)
struct SearchErrorView: View {
    let error: String
    
    var body: some View {
        VStack(spacing: Spacing.l) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(BrandColor.warning)
            
            VStack(spacing: Spacing.s) {
                Text("Fehler bei der Suche")
                    .font(Typography.headline)
                
                Text(error)
                    .font(Typography.subheadline)
                    .foregroundStyle(TextColor.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Spacing.xl)
        .materialCardStyle()
        .largeShadow()
        .padding(.horizontal, Padding.xl)
        .padding(.vertical, 60)
    }
}

// ✅ NEW: Search Mode Header Component
struct SearchModeHeader: View {
    let isOfflineSearch: Bool
    
    var body: some View {
        if isOfflineSearch {
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
            .overlay(
                RoundedRectangle(cornerRadius: Radius.s)
                    .stroke(BrandColor.warning.opacity(0.3), lineWidth: 1)
            )
            .screenPadding()
            .padding(.top, Spacing.xs)
        }
    }
}

// ✅ ENHANCED: Search Content View with Offline Support
struct SearchContentView: View {
    let query: String
    let selectedTab: SearchView.SearchTab
    let hasResults: Bool
    let isOfflineSearch: Bool
    let navidromeVM: NavidromeViewModel
    let offlineSearchResults: SearchView.OfflineSearchResults
    let playerVM: PlayerViewModel
    let onSongTap: (Int) -> Void
    
    var body: some View {
        Group {
            if let error = navidromeVM.errorMessage, !isOfflineSearch {
                SearchErrorView(error: error)
            } else if hasResults {
                SearchResultsView(
                    selectedTab: selectedTab,
                    isOfflineSearch: isOfflineSearch,
                    navidromeVM: navidromeVM,
                    offlineSearchResults: offlineSearchResults,
                    playerVM: playerVM,
                    onSongTap: onSongTap
                )
            } else if !query.isEmpty && !navidromeVM.isLoading {
                SearchEmptyView(isOfflineSearch: isOfflineSearch)
            } else if query.isEmpty {
                SearchInitialView(isOfflineSearch: isOfflineSearch)
            }
        }
    }
}

// ✅ ENHANCED: Search Results View with Offline Support
struct SearchResultsView: View {
    let selectedTab: SearchView.SearchTab
    let isOfflineSearch: Bool
    let navidromeVM: NavidromeViewModel
    let offlineSearchResults: SearchView.OfflineSearchResults
    let playerVM: PlayerViewModel
    let onSongTap: (Int) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.s) {
                Section {
                    switch selectedTab {
                    case .artists:
                        let artists = isOfflineSearch ? offlineSearchResults.artists : navidromeVM.artists
                        ForEach(artists) { artist in
                            SearchResultArtistRow(artist: artist)
                        }
                        
                    case .albums:
                        let albums = isOfflineSearch ? offlineSearchResults.albums : navidromeVM.albums
                        ForEach(albums) { album in
                            SearchResultAlbumRow(album: album)
                        }
                        
                    case .songs:
                        let songs = isOfflineSearch ? offlineSearchResults.songs : navidromeVM.songs
                        ForEach(songs.indices, id: \.self) { index in
                            let song = songs[index]
                            SearchResultSongRow(
                                song: song,
                                index: index + 1,
                                isPlaying: playerVM.currentSong?.id == song.id && playerVM.isPlaying,
                                action: { onSongTap(index) }
                            )
                        }
                    }
                }
            }
            .screenPadding()
            .padding(.bottom, 100)
        }
    }
}

// ✅ ENHANCED: Empty Views with Offline Context
struct SearchEmptyView: View {
    let isOfflineSearch: Bool
    
    var body: some View {
        VStack(spacing: Spacing.l) {
            Image(systemName: isOfflineSearch ? "arrow.down.circle" : "music.note.house")
                .font(.system(size: 60))
                .foregroundStyle(TextColor.secondary)
            
            VStack(spacing: Spacing.s) {
                Text("Keine Ergebnisse")
                    .font(Typography.title2)
                
                Text(isOfflineSearch ?
                     "Keine Downloads gefunden" :
                     "Versuchen Sie andere Suchbegriffe")
                    .font(Typography.subheadline)
                    .foregroundStyle(TextColor.secondary)
            }
        }
        .padding(Spacing.xl)
        .materialCardStyle()
        .largeShadow()
        .padding(.vertical, 60)
    }
}

struct SearchInitialView: View {
    let isOfflineSearch: Bool
    
    var body: some View {
        VStack(spacing: Spacing.l) {
            Image(systemName: isOfflineSearch ? "arrow.down.circle" : "magnifyingglass.circle")
                .font(.system(size: 80))
                .foregroundStyle(TextColor.secondary.opacity(0.6))
            
            VStack(spacing: Spacing.s) {
                Text(isOfflineSearch ? "Downloads durchsuchen" : "Musik durchsuchen")
                    .font(Typography.title2)
                
                Text(isOfflineSearch ?
                     "Suchen Sie in Ihren heruntergeladenen Alben" :
                     "Suchen Sie nach Künstlern, Alben oder Songs")
                    .font(Typography.subheadline)
                    .foregroundStyle(TextColor.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Padding.xl)
        .materialCardStyle()
        .largeShadow()
        .padding(.vertical, 80)
    }
}
