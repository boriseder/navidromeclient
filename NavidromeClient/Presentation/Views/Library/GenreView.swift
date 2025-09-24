//
//  GenreViewContent.swift - PHASE 3: Standardized View Logic
//  NavidromeClient
//
//   STANDARDIZED: Consistent state handling across all views
//   ELIMINATED: Inconsistent loading patterns
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
    
    // MARK: - PHASE 3: Standardized State Logic
    
    private var connectionState: EffectiveConnectionState {
        networkMonitor.effectiveConnectionState
    }
    
    private var displayedGenres: [Genre] {
        switch connectionState {
        case .online:
            return filterGenres(musicLibraryManager.genres)
        case .userOffline, .serverUnreachable, .disconnected:
            return filterGenres(offlineManager.offlineGenres)
        }
    }
    
    private var shouldShowLoading: Bool {
        return appConfig.isInitializingServices ||
               (connectionState.shouldLoadOnlineContent &&
                musicLibraryManager.isLoading &&
                !musicLibraryManager.hasLoadedInitialData)
    }

    private var isEmpty: Bool {
        return displayedGenres.isEmpty
    }
    
    private var isEffectivelyOffline: Bool {
        return connectionState.isEffectivelyOffline
    }
    
    var body: some View {
        NavigationStack {
            UnifiedLibraryContainer(
                items: displayedGenres,
                isLoading: shouldShowLoading,
                isEmpty: isEmpty && !shouldShowLoading,
                isOfflineMode: isEffectivelyOffline,
                emptyStateType: .genres,
                layout: .list,
                onItemTap: { _ in } // NavigationLink handles tap
            ) { genre, index in
                NavigationLink(value: genre) {
                    ListItemContainer(content: CardContent.genre(genre), index: index)
                }
            }
            .searchable(text: $searchText, prompt: "Search genres...")
            .refreshable {
                // PHASE 3: Only refresh if we should load online content
                guard connectionState.shouldLoadOnlineContent else { return }
                await refreshAllData()
            }
            .onChange(of: searchText) { _, _ in
                handleSearchTextChange()
            }
            .navigationDestination(for: Genre.self) { genre in
                AlbumCollectionView(context: .byGenre(genre))
            }
            .unifiedToolbar(genreToolbarConfig)
        }
    }
    
    // MARK: - PHASE 3: Standardized Business Logic
    
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
    
    private var genreToolbarConfig: ToolbarConfiguration {
        .library(
            title: "Genres",
            isOffline: isEffectivelyOffline,
            onRefresh: {
                guard connectionState.shouldLoadOnlineContent else { return }
                await refreshAllData()
            },
            onToggleOffline: offlineManager.toggleOfflineMode
        )
    }
}
