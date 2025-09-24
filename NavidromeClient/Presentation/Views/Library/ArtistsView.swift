//
//  ArtistsViewContent.swift - PHASE 3: Standardized View Logic
//  NavidromeClient
//
//   STANDARDIZED: Consistent state handling across all views
//   ELIMINATED: Inconsistent loading patterns
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
    
    // MARK: - PHASE 3: Standardized State Logic
    
    private var connectionState: EffectiveConnectionState {
        networkMonitor.effectiveConnectionState
    }
    
    private var displayedArtists: [Artist] {
        switch connectionState {
        case .online:
            return filterArtists(musicLibraryManager.artists)
        case .userOffline, .serverUnreachable, .disconnected:
            return filterArtists(offlineManager.offlineArtists)
        }
    }
    
    private var shouldShowLoading: Bool {
        return connectionState.shouldLoadOnlineContent &&
               musicLibraryManager.isLoading &&
               !musicLibraryManager.hasLoadedInitialData
    }
    
    private var isEmpty: Bool {
        return displayedArtists.isEmpty
    }
    
    private var isEffectivelyOffline: Bool {
        return connectionState.isEffectivelyOffline
    }
    
    var body: some View {
        NavigationStack {
            UnifiedLibraryContainer(
                items: displayedArtists,
                isLoading: shouldShowLoading,
                isEmpty: isEmpty && !shouldShowLoading,
                isOfflineMode: isEffectivelyOffline,
                emptyStateType: .artists,
                layout: .list
            ) { artist, index in
                NavigationLink(value: artist) {
                    ListItemContainer(content: CardContent.artist(artist), index: index)
                }
            }
            .searchable(text: $searchText, prompt: "Search artists...")
            .refreshable {
                // PHASE 3: Only refresh if we should load online content
                guard connectionState.shouldLoadOnlineContent else { return }
                await refreshAllData()
            }
            .onChange(of: searchText) { _, _ in
                handleSearchTextChange()
            }
            .task(id: displayedArtists.count) {
                await preloadArtistImages()
            }
            .navigationDestination(for: Artist.self) { artist in
                AlbumCollectionView(context: .byArtist(artist))
            }
            .navigationDestination(for: Album.self) { album in
                AlbumDetailViewContent(album: album)
            }
            .unifiedToolbar(artistsToolbarConfig)
        }
    }
    
    // MARK: - PHASE 3: Standardized Business Logic
    
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
    
    private var artistsToolbarConfig: ToolbarConfiguration {
        .library(
            title: "Artists",
            isOffline: isEffectivelyOffline,
            onRefresh: {
                guard connectionState.shouldLoadOnlineContent else { return }
                await refreshAllData()
            },
            onToggleOffline: offlineManager.toggleOfflineMode
        )
    }
}
