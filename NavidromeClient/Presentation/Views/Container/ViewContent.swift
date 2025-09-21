//
//  ExploreViewContent.swift
//  NavidromeClient
//
//  Created by Boris Eder on 21.09.25.
//
import SwiftUI

struct ExploreViewContent: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var coverArtManager: CoverArtManager
    
    @StateObject private var homeScreenManager = HomeScreenManager.shared
    @State private var hasLoaded = false

    var body: some View {
        NavigationStack {
            ZStack {
                if networkMonitor.canLoadOnlineContent && !offlineManager.isOfflineMode {
                    onlineContent
                } else {
                    offlineContent
                }
            }
            .task(id: hasLoaded) {
                guard !hasLoaded else { return }
                await setupHomeScreenData()
                hasLoaded = true
            }
            .refreshable {
                await homeScreenManager.loadHomeScreenData()
                await preloadHomeScreenCovers()
            }
            .navigationDestination(for: Album.self) { album in
                AlbumDetailViewContent(album: album)
            }
            .navigationTitle("Explore your music")
        }
    }
    
    private var onlineContent: some View {
        ScrollView {
            LazyVStack(spacing: DSLayout.screenGap) {
                WelcomeHeader(
                    username: "User",
                    nowPlaying: playerVM.currentSong
                )
                
                if !homeScreenManager.recentAlbums.isEmpty {
                    AlbumSection(
                        title: "Recently played",
                        albums: homeScreenManager.recentAlbums,
                        icon: "clock.fill",
                        accentColor: .orange
                    )
                }
                
                if !homeScreenManager.newestAlbums.isEmpty {
                    AlbumSection(
                        title: "Newly added",
                        albums: homeScreenManager.newestAlbums,
                        icon: "sparkles",
                        accentColor: .green
                    )
                }
                
                if !homeScreenManager.frequentAlbums.isEmpty {
                    AlbumSection(
                        title: "Often played",
                        albums: homeScreenManager.frequentAlbums,
                        icon: "chart.bar.fill",
                        accentColor: .purple
                    )
                }
                
                if !homeScreenManager.randomAlbums.isEmpty {
                    AlbumSection(
                        title: "Explore",
                        albums: homeScreenManager.randomAlbums,
                        icon: "dice.fill",
                        accentColor: .blue,
                        showRefreshButton: true,
                        refreshAction: { await refreshRandomAlbums() }
                    )
                }
                
                Color.clear.frame(height: DSLayout.miniPlayerHeight)
            }
            .padding(.top, DSLayout.elementGap)
        }
    }
    
    private var offlineContent: some View {
        ScrollView {
            LazyVStack(spacing: DSLayout.screenGap) {
                OfflineWelcomeHeader(
                    downloadedAlbums: downloadManager.downloadedAlbums.count,
                    isConnected: networkMonitor.isConnected
                )
                .screenPadding()
                
                if !offlineManager.offlineAlbums.isEmpty {
                    AlbumSection(
                        title: "Downloaded Albums",
                        albums: Array(offlineManager.offlineAlbums.prefix(10)),
                        icon: "arrow.down.circle.fill",
                        accentColor: .green
                    )
                }
                
                Color.clear.frame(height: DSLayout.miniPlayerHeight)
            }
            .padding(.top, DSLayout.elementGap)
        }
    }
    
    private func setupHomeScreenData() async {
        if networkMonitor.canLoadOnlineContent && !offlineManager.isOfflineMode {
            await homeScreenManager.loadHomeScreenData()
            await preloadHomeScreenCovers()
        }
    }
    
    private func preloadHomeScreenCovers() async {
        let allAlbums = homeScreenManager.recentAlbums +
                       homeScreenManager.newestAlbums +
                       homeScreenManager.frequentAlbums +
                       homeScreenManager.randomAlbums
        
        await coverArtManager.preloadAlbums(Array(allAlbums.prefix(20)), size: 200)
    }
    
    private func refreshRandomAlbums() async {
        await homeScreenManager.refreshRandomAlbums()
        await coverArtManager.preloadAlbums(homeScreenManager.randomAlbums, size: 200)
    }
}

struct AlbumsViewContent: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var coverArtManager: CoverArtManager
    @EnvironmentObject var musicLibraryManager: MusicLibraryManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var downloadManager: DownloadManager
    
    @State private var searchText = ""
    @State private var selectedAlbumSort: ContentService.AlbumSortType = .alphabetical
    @StateObject private var debouncer = Debouncer()
    
    private var displayedAlbums: [Album] {
        let sourceAlbums = getAlbumDataSource()
        return filterAlbums(sourceAlbums)
    }
    
    private var isOfflineMode: Bool {
        return !networkMonitor.canLoadOnlineContent || offlineManager.isOfflineMode
    }
    
    private var shouldShowLoading: Bool {
        return musicLibraryManager.isLoading && !musicLibraryManager.hasLoadedInitialData
    }
    
    private var isEmpty: Bool {
        return displayedAlbums.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ContentOnlyLibraryView(
                isLoading: shouldShowLoading,
                isEmpty: isEmpty && !shouldShowLoading,
                isOfflineMode: isOfflineMode,
                emptyStateType: .albums
            ) {
                AlbumsGridContent()
            }
            .searchable(text: $searchText, prompt: "Search albums...")
            .refreshable { await refreshAllData() }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button(action: { Task { await refreshAllData() } }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(ContentService.AlbumSortType.allCases, id: \.self) { sortType in
                            Button {
                                Task { await loadAlbums(sortBy: sortType) }
                            } label: {
                                HStack {
                                    Text(sortType.displayName)
                                    if sortType == selectedAlbumSort {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                    }
                    
                    Button(action: { toggleOfflineMode() }) {
                        HStack(spacing: 4) {
                            Image(systemName: isOfflineMode ? "icloud.slash" : "icloud")
                            Text(isOfflineMode ? "Offline" : "All")
                        }
                        .font(.caption)
                        .foregroundStyle(isOfflineMode ? DSColor.warning : DSColor.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill((isOfflineMode ? DSColor.warning : DSColor.accent).opacity(0.1)))
                    }
                    
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .onChange(of: searchText) { _, _ in
                handleSearchTextChange()
            }
            .task(id: displayedAlbums.count) {
                await preloadAlbumImages()
            }
            .navigationDestination(for: Album.self) { album in
                AlbumDetailViewContent(album: album)
            }
        }
        .navigationTitle("Albums")
        .navigationBarTitleDisplayMode(.large)
    }
    
    @ViewBuilder
    private func AlbumsGridContent() -> some View {
        UnifiedContainer(
            items: displayedAlbums,
            layout: .twoColumnGrid,
            onLoadMore: { _ in
                Task { await musicLibraryManager.loadMoreAlbumsIfNeeded() }
            }
        ) { album, index in
            // ✅ NavigationLink mit value für zentrale Navigation
            NavigationLink(value: album) {
                CardItemContainer(content: .album(album), index: index)
            }
        }
    }
    
    // Business Logic (unverändert)
    private func getAlbumDataSource() -> [Album] {
        if networkMonitor.canLoadOnlineContent && !isOfflineMode {
            return musicLibraryManager.albums
        } else {
            let downloadedAlbumIds = Set(downloadManager.downloadedAlbums.map { $0.albumId })
            return AlbumMetadataCache.shared.getAlbums(ids: downloadedAlbumIds)
        }
    }
    
    private func filterAlbums(_ albums: [Album]) -> [Album] {
        if searchText.isEmpty {
            return albums
        } else {
            return albums.filter { album in
                let nameMatches = album.name.localizedCaseInsensitiveContains(searchText)
                let artistMatches = album.artist.localizedCaseInsensitiveContains(searchText)
                return nameMatches || artistMatches
            }
        }
    }
    
    private func refreshAllData() async {
        await musicLibraryManager.refreshAllData()
    }
    
    private func loadAlbums(sortBy: ContentService.AlbumSortType) async {
        selectedAlbumSort = sortBy
        await musicLibraryManager.loadAlbumsProgressively(sortBy: sortBy, reset: true)
    }
    
    private func preloadAlbumImages() async {
        let albumsToPreload = Array(displayedAlbums.prefix(20))
        await coverArtManager.preloadAlbums(albumsToPreload, size: 200)
    }
    
    private func handleSearchTextChange() {
        debouncer.debounce {
            // Search filtering happens automatically via computed property
        }
    }
    
    private func toggleOfflineMode() {
        offlineManager.toggleOfflineMode()
    }
}

struct ArtistsViewContent: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var coverArtManager: CoverArtManager
    @EnvironmentObject var musicLibraryManager: MusicLibraryManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var downloadManager: DownloadManager
    
    @State private var searchText = ""
    @StateObject private var debouncer = Debouncer()
    
    private var displayedArtists: [Artist] {
        let sourceArtists = getArtistDataSource()
        return filterArtists(sourceArtists)
    }
    
    private var isOfflineMode: Bool {
        return !networkMonitor.canLoadOnlineContent || offlineManager.isOfflineMode
    }
    
    private var shouldShowLoading: Bool {
        return musicLibraryManager.isLoading && !musicLibraryManager.hasLoadedInitialData
    }
    
    private var isEmpty: Bool {
        return displayedArtists.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ContentOnlyLibraryView(
                isLoading: shouldShowLoading,
                isEmpty: isEmpty && !shouldShowLoading,
                isOfflineMode: isOfflineMode,
                emptyStateType: .artists
            ) {
                ArtistListContent()
            }
            .searchable(text: $searchText, prompt: "Search artists...")
            .refreshable { await refreshAllData() }
            .accountToolbar()
            .onChange(of: searchText) { _, _ in
                handleSearchTextChange()
            }
            .task(id: displayedArtists.count) {
                await preloadArtistImages()
            }
            .navigationDestination(for: Artist.self) { artist in
                ArtistDetailViewContent(context: .artist(artist))
            }
            .navigationDestination(for: Album.self) { album in
                AlbumDetailViewContent(album: album)
            }
        }
        .navigationTitle("Artists")
        .navigationBarTitleDisplayMode(.large)
    }
    
    @ViewBuilder
    private func ArtistListContent() -> some View {
        UnifiedContainer(
            items: displayedArtists,
            layout: .list
        ) { artist, index in
            // ✅ NavigationLink mit value für zentrale Navigation
            NavigationLink(value: artist) {
                ListItemContainer(content: .artist(artist), index: index)
            }
        }
    }
    
    // Business Logic (unverändert)
    private func getArtistDataSource() -> [Artist] {
        if networkMonitor.canLoadOnlineContent && !isOfflineMode {
            return musicLibraryManager.artists
        } else {
            return offlineManager.offlineArtists
        }
    }
    
    private func filterArtists(_ artists: [Artist]) -> [Artist] {
        let filteredArtists: [Artist]
        
        if searchText.isEmpty {
            filteredArtists = artists
        } else {
            filteredArtists = artists.filter { artist in
                artist.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filteredArtists.sorted(by: { $0.name < $1.name })
    }

    private func refreshAllData() async {
        await musicLibraryManager.refreshAllData()
    }
    
    private func preloadArtistImages() async {
        let artistsToPreload = Array(displayedArtists.prefix(20))
        await coverArtManager.preloadArtists(artistsToPreload, size: 120)
    }
    
    private func handleSearchTextChange() {
        debouncer.debounce {
            // Search filtering happens automatically via computed property
        }
    }
}

struct GenreViewContent: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var musicLibraryManager: MusicLibraryManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    
    @State private var searchText = ""
    @StateObject private var debouncer = Debouncer()
    
    private var displayedGenres: [Genre] {
        let sourceGenres = getGenreDataSource()
        return filterGenres(sourceGenres)
    }
    
    private var isOfflineMode: Bool {
        return !networkMonitor.canLoadOnlineContent || offlineManager.isOfflineMode
    }
    
    private var shouldShowLoading: Bool {
        return musicLibraryManager.isLoading && !musicLibraryManager.hasLoadedInitialData
    }
    
    private var isEmpty: Bool {
        return displayedGenres.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ContentOnlyLibraryView(
                isLoading: shouldShowLoading,
                isEmpty: isEmpty && !shouldShowLoading,
                isOfflineMode: isOfflineMode,
                emptyStateType: .genres
            ) {
                GenresListContent()
            }
            .searchable(text: $searchText, prompt: "Search genres...")
            .refreshable { await refreshAllData() }
            .accountToolbar()
            .onChange(of: searchText) { _, _ in
                handleSearchTextChange()
            }
            .navigationDestination(for: Genre.self) { genre in
                ArtistDetailViewContent(context: .genre(genre))
            }
            .navigationDestination(for: Album.self) { album in
                AlbumDetailViewContent(album: album)
            }
        }
        .navigationTitle("Genres")
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private func GenresListContent() -> some View {
        UnifiedContainer(
            items: displayedGenres,
            layout: .list
        ) { genre, index in
            // ✅ NavigationLink mit value für zentrale Navigation
            NavigationLink(value: genre) {
                ListItemContainer(content: .genre(genre), index: index)
            }
        }
    }
    
    // Business Logic (unverändert)
    private func getGenreDataSource() -> [Genre] {
        if networkMonitor.canLoadOnlineContent && !isOfflineMode {
            return musicLibraryManager.genres
        } else {
            return offlineManager.offlineGenres
        }
    }
    
    private func filterGenres(_ genres: [Genre]) -> [Genre] {
        let filteredGenres: [Genre]
        
        if searchText.isEmpty {
            filteredGenres = genres
        } else {
            filteredGenres = genres.filter { genre in
                genre.value.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filteredGenres.sorted(by: { $0.value < $1.value })
    }
    
    private func refreshAllData() async {
        await musicLibraryManager.refreshAllData()
    }
    
    private func handleSearchTextChange() {
        debouncer.debounce {
            // Search filtering happens automatically via computed property
        }
    }
}

struct FavoritesViewContent: View {
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var playerVM: PlayerViewModel
    
    @StateObject private var favoritesManager = FavoritesManager.shared
    @State private var searchText = ""
    @StateObject private var debouncer = Debouncer()
    
    private var displayedSongs: [Song] {
        let songs = favoritesManager.favoriteSongs
        
        if searchText.isEmpty {
            return songs
        } else {
            return songs.filter { song in
                let titleMatches = song.title.localizedCaseInsensitiveContains(searchText)
                let artistMatches = (song.artist ?? "").localizedCaseInsensitiveContains(searchText)
                let albumMatches = (song.album ?? "").localizedCaseInsensitiveContains(searchText)
                return titleMatches || artistMatches || albumMatches
            }
        }
    }
    
    private var shouldShowLoading: Bool {
        return favoritesManager.isLoading && favoritesManager.favoriteSongs.isEmpty
    }
    
    private var isEmpty: Bool {
        return displayedSongs.isEmpty
    }
    
    private var isOfflineMode: Bool {
        return !networkMonitor.canLoadOnlineContent || offlineManager.isOfflineMode
    }
    
    var body: some View {
        NavigationStack {
            ContentOnlyLibraryView(
                isLoading: shouldShowLoading,
                isEmpty: isEmpty && !shouldShowLoading,
                isOfflineMode: isOfflineMode,
                emptyStateType: .favorites
            ) {
                FavoritesListContent()
            }
            .searchable(text: $searchText, prompt: "Search favorites...")
            .refreshable { await refreshFavorites() }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button(action: { Task { await refreshFavorites() } }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Play All", action: { Task { await playAllFavorites() } })
                        Button("Shuffle All", action: { Task { await shuffleAllFavorites() } })
                        Divider()
                        Button("Clear All Favorites", role: .destructive, action: { Task { await clearAllFavorites() } })
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .task {
                await favoritesManager.loadFavoriteSongs()
            }
            .onChange(of: searchText) { _, _ in
                handleSearchTextChange()
            }
            .navigationDestination(for: Album.self) { album in
                AlbumDetailViewContent(album: album)
            }
        }
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.large)
    }
    
    @ViewBuilder
    private func FavoritesListContent() -> some View {
        LazyVStack(spacing: DSLayout.elementGap) {
            if !favoritesManager.favoriteSongs.isEmpty {
                FavoritesStatsHeader()
            }
            
            ForEach(displayedSongs.indices, id: \.self) { index in
                let song = displayedSongs[index]
                
                FavoriteSongRow(
                    song: song,
                    index: index + 1,
                    isPlaying: playerVM.currentSong?.id == song.id && playerVM.isPlaying,
                    onPlay: {
                        Task {
                            await playerVM.setPlaylist(
                                displayedSongs,
                                startIndex: index,
                                albumId: nil
                            )
                        }
                    },
                    onToggleFavorite: {
                        Task {
                            await favoritesManager.toggleFavorite(song)
                        }
                    }
                )
            }
        }
        .screenPadding()
    }
    
    // Business Logic (unverändert)
    private func refreshFavorites() async {
        await favoritesManager.loadFavoriteSongs(forceRefresh: true)
    }
    
    private func playAllFavorites() async {
        guard !displayedSongs.isEmpty else { return }
        
        await playerVM.setPlaylist(
            displayedSongs,
            startIndex: 0,
            albumId: nil
        )
    }
    
    private func shuffleAllFavorites() async {
        guard !displayedSongs.isEmpty else { return }
        
        let shuffledSongs = displayedSongs.shuffled()
        await playerVM.setPlaylist(
            shuffledSongs,
            startIndex: 0,
            albumId: nil
        )
        
        if !playerVM.isShuffling {
            playerVM.toggleShuffle()
        }
    }
    
    private func clearAllFavorites() async {
        await favoritesManager.clearAllFavorites()
    }
    
    private func handleSearchTextChange() {
        debouncer.debounce {
            // Search filtering happens automatically via computed property
        }
    }
}

struct AlbumDetailViewContent: View {
    let album: Album
    @State private var scrollOffset: CGFloat = 0
    
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var coverArtManager: CoverArtManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    
    @State private var songs: [Song] = []
    @State private var coverArt: UIImage?
    @State private var isOfflineAlbum = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: DSLayout.screenGap) {
                AlbumHeaderView(
                    album: album,
                    cover: coverArt,
                    songs: songs,
                    isOfflineAlbum: isOfflineAlbum
                )
                
                if isOfflineAlbum || !networkMonitor.canLoadOnlineContent {
                    HStack {
                        if downloadManager.isAlbumDownloaded(album.id) {
                            OfflineStatusBadge(album: album)
                        } else {
                            NetworkStatusIndicator(showText: true)
                        }
                        Spacer()
                    }
                    .screenPadding()
                }
                
                if songs.isEmpty {
                    EmptyStateView(
                        type: .songs,
                        customTitle: "No Songs Available",
                        customMessage: isOfflineAlbum ?
                            "This album is not downloaded for offline listening." :
                            "No songs found in this album."
                    )
                    .screenPadding()
                } else {
                    AlbumSongsListView(
                        songs: songs,
                        album: album
                    )
                }
            }
            .screenPadding()
            .padding(.bottom, DSLayout.miniPlayerHeight + DSLayout.contentGap)
        }
        .navigationTitle(album.name)
        .navigationBarTitleDisplayMode(.inline)
        .accountToolbar()
        .task {
            await loadAlbumData()
        }
    }
    
    @MainActor
    private func loadAlbumData() async {
        isOfflineAlbum = !networkMonitor.canLoadOnlineContent || offlineManager.isOfflineMode
        
        coverArt = await coverArtManager.loadAlbumImage(album: album, size: Int(DSLayout.fullCover))
        songs = await navidromeVM.loadSongs(for: album.id)
    }
}

struct ArtistDetailViewContent: View {
    let context: ArtistDetailContext
    
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var coverArtManager: CoverArtManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var musicLibraryManager: MusicLibraryManager
    
    @State private var albums: [Album] = []
    @State private var artistImage: UIImage?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var artist: Artist? {
        if case .artist(let a) = context { return a }
        return nil
    }
    
    private var isOfflineMode: Bool {
        !networkMonitor.canLoadOnlineContent || offlineManager.isOfflineMode
    }
    
    private var availableOfflineAlbums: [Album] {
        switch context {
        case .artist(let artist):
            return offlineManager.getOfflineAlbums(for: artist)
        case .genre(let genre):
            return offlineManager.getOfflineAlbums(for: genre)
        }
    }
    
    private var contextTitle: String {
        switch context {
        case .artist(let artist): return artist.name
        case .genre(let genre): return genre.value
        }
    }
    
    private var displayAlbums: [Album] {
        return isOfflineMode ? availableOfflineAlbums : albums
    }
    
    private var emptyMessageForContext: String {
        switch context {
        case .artist(let artist):
            return "No albums from \(artist.name) are downloaded for offline listening."
        case .genre(let genre):
            return "No \(genre.value) albums are downloaded for offline listening."
        }
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: DSLayout.screenGap) {
                headerView
                    .screenPadding()
                
                if isOfflineMode && availableOfflineAlbums.isEmpty {
                    EmptyStateView(
                        type: .artists,
                        customTitle: "No Downloaded Content",
                        customMessage: emptyMessageForContext,
                        primaryAction: EmptyStateAction("Browse Online Content") {
                            offlineManager.switchToOnlineMode()
                        }
                    )
                    .screenPadding()
                } else if !displayAlbums.isEmpty {
                    LazyVGrid(columns: GridColumns.two, spacing: DSLayout.contentGap) {
                        ForEach(albums, id: \.id) { album in
                            // ✅ NavigationLink mit value für zentrale Navigation
                            NavigationLink(value: album) {
                                CardItemContainer(content: .album(album), index: 0)
                            }
                        }
                    }
                    .screenPadding()
                    .padding(.bottom, 100)
                }
                
                Color.clear.frame(height: DSLayout.miniPlayerHeight)
            }
        }
        .navigationTitle(contextTitle)
        .navigationBarTitleDisplayMode(.inline)
        .accountToolbar()
        .task {
            await loadContent()
        }
        .refreshable {
            await loadContent()
        }
    }
    
    private var headerView: some View {
        VStack(spacing: DSLayout.sectionGap) {
            HStack(spacing: DSLayout.sectionGap) {
                artistAvatar()
                
                VStack(alignment: .leading, spacing: DSLayout.elementGap) {
                    Text(contextTitle)
                        .font(DSText.sectionTitle)
                        .lineLimit(2)
                    
                    albumCountView
                    
                    if !displayAlbums.isEmpty {
                        shuffleButton
                    }
                }
                
                Spacer()
            }
            
            if isOfflineMode && !availableOfflineAlbums.isEmpty {
                LibraryStatusHeader.artists(
                    count: availableOfflineAlbums.count,
                    isOnline: networkMonitor.canLoadOnlineContent,
                    isOfflineMode: true
                )
            }
        }
        .cardStyle()
    }
    
    private func artistAvatar() -> some View {
        Group {
            if let image = artistImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: DSLayout.smallAvatar, height: DSLayout.smallAvatar)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: DSLayout.smallAvatar, height: DSLayout.smallAvatar)
                    .overlay(
                        Image(systemName: contextIcon)
                            .font(.system(size: DSLayout.largeIcon))
                            .foregroundStyle(DSColor.onDark)
                    )
            }
        }
        .cardStyle()
    }
    
    private var contextIcon: String {
        switch context {
        case .artist: return "music.mic"
        case .genre: return "music.note.list"
        }
    }
    
    private var albumCountView: some View {
        VStack(alignment: .leading, spacing: DSLayout.tightGap) {
            if !isOfflineMode && !albums.isEmpty {
                AlbumCountBadge(
                    count: albums.count,
                    label: "Total",
                    color: DSColor.accent
                )
            }
            
            if !availableOfflineAlbums.isEmpty {
                AlbumCountBadge(
                    count: availableOfflineAlbums.count,
                    label: "Downloaded",
                    color: DSColor.success
                )
            }
        }
    }
    
    private var shuffleButton: some View {
        Button {
            Task { await shufflePlayAllAlbums() }
        } label: {
            HStack(spacing: DSLayout.tightGap) {
                Image(systemName: "shuffle")
                    .font(DSText.metadata)
                Text("Shuffle All")
                    .font(DSText.metadata.weight(.semibold))
            }
            .foregroundStyle(DSColor.onDark)
            .padding(.horizontal, DSLayout.contentPadding)
            .padding(.vertical, DSLayout.elementPadding)
            .background(DSColor.accent, in: Capsule())
        }
    }
    
    private func loadContent() async {
        isLoading = true
        errorMessage = nil
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.loadAlbumsViaManager()
            }
            
            group.addTask {
                await self.loadArtistImageViaManager()
            }
        }
        
        isLoading = false
    }
    
    private func loadAlbumsViaManager() async {
        guard !isOfflineMode else {
            albums = availableOfflineAlbums
            return
        }
        
        do {
            albums = try await musicLibraryManager.loadAlbums(context: context)
        } catch {
            errorMessage = "Failed to load albums: \(error.localizedDescription)"
            albums = availableOfflineAlbums
        }
    }
    
    private func loadArtistImageViaManager() async {
        if case .artist(let artist) = context {
            artistImage = await coverArtManager.loadArtistImage(
                artist: artist,
                size: Int(DSLayout.smallAvatar)
            )
        }
    }
    
    private func shufflePlayAllAlbums() async {
        let albumsToPlay = displayAlbums
        guard !albumsToPlay.isEmpty else { return }
        
        var allSongs: [Song] = []
        
        for album in albumsToPlay {
            let songs = await navidromeVM.loadSongs(for: album.id)
            allSongs.append(contentsOf: songs)
        }
        
        guard !allSongs.isEmpty else { return }
        
        let shuffledSongs = allSongs.shuffled()
        await playerVM.setPlaylist(shuffledSongs, startIndex: 0, albumId: nil)
        
        if !playerVM.isShuffling {
            playerVM.toggleShuffle()
        }
    }
}

// MARK: - Content-Only Library Container
struct ContentOnlyLibraryView<Content: View>: View {
    let isLoading: Bool
    let isEmpty: Bool
    let isOfflineMode: Bool
    let emptyStateType: EmptyStateView.EmptyStateType
    let content: () -> Content
    
    var body: some View {
        Group {
            if isLoading {
                LoadingView()
            } else if isEmpty {
                EmptyStateView(type: emptyStateType)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if isOfflineMode {
                            OfflineStatusBanner()
                                .screenPadding()
                                .padding(.bottom, DSLayout.elementGap)
                        }
                        
                        content()
                    }
                    .padding(.bottom, DSLayout.miniPlayerHeight)
                }
            }
        }
    }
}
