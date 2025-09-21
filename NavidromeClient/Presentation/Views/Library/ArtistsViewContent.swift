//
//  ArtistsViewContent.swift
//  NavidromeClient
//
//  Created by Boris Eder on 21.09.25.
//
import SwiftUI

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
            .unifiedToolbar(albumsToolbarConfig)
        }
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
    
    private var albumsToolbarConfig: ToolbarConfiguration {
        .library(
            title: "Artists",
            isOffline: isOfflineMode,
            onRefresh: {
                await refreshAllData()
            },
            onToggleOffline: offlineManager.toggleOfflineMode
        )
    }
}
