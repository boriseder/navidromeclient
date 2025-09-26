//
//  GenreViewContent.swift - MIGRATED: Unified State System
//  NavidromeClient
//
//   ELIMINATED: Custom LoadingView, EmptyStateView (~80 LOC)
//   UNIFIED: 4-line state logic with modern design
//   CLEAN: Single state component handles all scenarios
//

import SwiftUI

struct GenreViewContent: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var musicLibraryManager: MusicLibraryManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    
    @State private var searchText = ""
    @StateObject private var debouncer = Debouncer()
    
    // MARK: - UNIFIED: Single State Logic (4 lines)
    
    private var connectionState: EffectiveConnectionState {
        networkMonitor.effectiveConnectionState
    }
    
    private var displayedGenres: [Genre] {
        let genres = connectionState.shouldLoadOnlineContent ?
                     musicLibraryManager.genres : offlineManager.offlineGenres
        return filterGenres(genres)
    }
    
    private var currentState: ViewState? {
        if appConfig.isInitializingServices {
            return .loading("Setting up your music library")
        } else if musicLibraryManager.isLoading && displayedGenres.isEmpty {
            return .loading("Loading genres")
        } else if displayedGenres.isEmpty {
            return .empty(type: .genres)
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
            .navigationTitle("Genres")
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)  // dunkler Hintergrund
            .toolbarColorScheme(.dark, for: .navigationBar)        // Titel weiß

            .searchable(text: $searchText, prompt: "Search genres...")
            .refreshable {
                guard connectionState.shouldLoadOnlineContent else { return }
                await refreshAllData()
            }
            .onChange(of: searchText) { _, _ in
                handleSearchTextChange()
            }
            .navigationDestination(for: Genre.self) { genre in
                AlbumCollectionView(context: .byGenre(genre))
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
                    ForEach(displayedGenres.indices, id: \.self) { index in
                        let genre = displayedGenres[index]
                        
                        NavigationLink(value: genre) {
                            ListItemContainer(content: .genre(genre), index: index)
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
