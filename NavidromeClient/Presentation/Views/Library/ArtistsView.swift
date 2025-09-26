//
//  ArtistsViewContent.swift - MIGRATED: Unified State System
//  NavidromeClient
//
//   ELIMINATED: Custom LoadingView, EmptyStateView (~80 LOC)
//   UNIFIED: 4-line state logic with modern design
//   CLEAN: Single state component handles all scenarios
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
    
    // MARK: - UNIFIED: Single State Logic (4 lines)
    
    private var connectionState: EffectiveConnectionState {
        networkMonitor.effectiveConnectionState
    }
    
    private var displayedArtists: [Artist] {
        let artists = connectionState.shouldLoadOnlineContent ?
                      musicLibraryManager.artists : offlineManager.offlineArtists
        return filterArtists(artists)
    }
    
    private var currentState: ViewState? {
        if appConfig.isInitializingServices {
            return .loading("Setting up your music library")
        } else if musicLibraryManager.isLoading && displayedArtists.isEmpty {
            return .loading("Loading artists")
        } else if displayedArtists.isEmpty {
            return .empty(type: .artists)
        }
        return nil
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                DynamicMusicBackground()
                
                // UNIFIED: Single component handles all states
                if let state = currentState {
                    UnifiedStateView(
                        state: state,
                        primaryAction: StateAction("Refresh") {
                            Task { await refreshAllData() }
                        }
                    )
                } else {
                    contentView

                }
            }
            .navigationTitle("Artists")
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)  // dunkler Hintergrund
            .toolbarColorScheme(.dark, for: .navigationBar)        // Titel weiß

            .searchable(text: $searchText, prompt: "Search artists...")
            .refreshable {
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
        }

    }
    
    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DSLayout.elementGap) {
                if connectionState.isEffectivelyOffline {
                    OfflineStatusBanner()
                }
                
                LazyVStack(spacing: DSLayout.elementGap) {
                    ForEach(displayedArtists.indices, id: \.self) { index in
                        let artist = displayedArtists[index]
                        
                        NavigationLink(value: artist) {
                            ListItemContainer(content: .artist(artist), index: index)
                        }
                    }
                }
                .padding(.bottom, DSLayout.miniPlayerHeight)
            }
        }
        .padding(.horizontal, DSLayout.screenPadding)
        .padding(.top, DSLayout.tightGap)
    }
    
    // MARK: - Business Logic (unchanged)
    
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
