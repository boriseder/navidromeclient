//
//  AlbumsView 2.swift
//  NavidromeClient
//
//  Created by Boris Eder on 18.09.25.
//


//
//  AlbumsView.swift - MIGRATED to Container Architecture
//  NavidromeClient
//
//   PHASE 1 MIGRATION: Proof-of-Concept using LibraryContainer
//   MAINTAINS: All existing functionality
//   REDUCES: ~60% of view code through container reuse
//

import SwiftUI

struct GenreView: View {

    @EnvironmentObject var deps: AppDependencies
    
    // MARK: - State (unchanged)
    @State private var searchText = ""
    @StateObject private var debouncer = Debouncer()
    
    // MARK: - Computed Properties (unchanged)
    private var displayedGenres: [Genre] {
        let sourceGenres = getGenreDataSource()
        return filterGenres(sourceGenres)
    }
    
    private var genreCount: Int {
        return displayedGenres.count
    }

    private var isOfflineMode: Bool {
        return !deps.networkMonitor.canLoadOnlineContent || deps.offlineManager.isOfflineMode
    }
    
    private var canLoadOnlineContent: Bool {
        return deps.networkMonitor.canLoadOnlineContent
    }

    private var shouldShowLoading: Bool {
        return deps.musicLibraryManager.isLoading && !deps.musicLibraryManager.hasLoadedInitialData
    }
    
    private var isEmpty: Bool {
        return displayedGenres.isEmpty
    }
    
    // MARK: -  NEW: Simplified Body using LibraryContainer
    var body: some View {
        LibraryView(
            title: "Genres",
            isLoading: shouldShowLoading,
            isEmpty: isEmpty && !shouldShowLoading,
            isOfflineMode: isOfflineMode,
            emptyStateType: .genres,
            onRefresh: { await refreshAllData() },
            searchText: $searchText,
            searchPrompt: "Search genres...",
            toolbarConfig: .empty
        ) {
            GenresListContent()
        }
        .onChange(of: searchText) { _, _ in
            handleSearchTextChange()
        }
        .task(id: displayedGenres.count) {
         //   await preloadArtistImages()
        }
    }

    // MARK: -  FIXED: Grid Content with Load More
    @ViewBuilder
    private func GenresListContent() -> some View {
        UnifiedContainer(
            items: displayedGenres,
            layout: .list
        ) { genre, index in
            NavigationLink(destination: ArtistDetailView(context: .genre(genre))) {
                ListItemContainer(content: .genre(genre), index: index)
            }
        }
    }

    // MARK: -  UNCHANGED: All business logic remains identical
    
    private func getGenreDataSource() -> [Genre] {
        if canLoadOnlineContent && !isOfflineMode {
            return deps.musicLibraryManager.genres
        } else {
            return deps.offlineManager.offlineGenres
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
        await deps.musicLibraryManager.refreshAllData()
    }
    
    private func handleSearchTextChange() {
        debouncer.debounce {
            // Search filtering happens automatically via computed property
        }
    }
    
    private func toggleOfflineMode() {
        deps.offlineManager.toggleOfflineMode()
    }
}
