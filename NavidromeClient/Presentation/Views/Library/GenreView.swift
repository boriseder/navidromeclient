//
//  AlbumsView 2.swift
//  NavidromeClient
//
//  Created by Boris Eder on 18.09.25.
//

/*

import SwiftUI

struct GenreView: View {
    // MARK: - Dependencies (unchanged)
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var musicLibraryManager: MusicLibraryManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    
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
        return !networkMonitor.canLoadOnlineContent || offlineManager.isOfflineMode
    }
    
    private var canLoadOnlineContent: Bool {
        return networkMonitor.canLoadOnlineContent
    }

    private var shouldShowLoading: Bool {
        return musicLibraryManager.isLoading && !musicLibraryManager.hasLoadedInitialData
    }
    
    private var isEmpty: Bool {
        return displayedGenres.isEmpty
    }
    
    // MARK: -  NEW: Simplified Body using LibraryContainer
    var body: some View {
        LibraryView(
            isLoading: shouldShowLoading,
            isEmpty: isEmpty && !shouldShowLoading,
            isOfflineMode: isOfflineMode,
            emptyStateType: .genres
        ) {
            GenresListContent()
        }
        .onChange(of: searchText) { _, _ in
            handleSearchTextChange()
        }
        .task(id: displayedGenres.count) {
         //   await preloadArtistImages()
        }
        .navigationTitle("Genres")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search genres...")
        .refreshable { await refreshAllData() }

    }

    // MARK: -  FIXED: Grid Content with Load More
    @ViewBuilder
    private func GenresListContent() -> some View {
        UnifiedContainer(
            items: displayedGenres,
            layout: .list
        ) { genre, index in
            NavigationLink(value: genre) {
                ListItemContainer(content: .genre(genre), index: index)
            }
        }
    }

    // MARK: -  UNCHANGED: All business logic remains identical
    
    private func getGenreDataSource() -> [Genre] {
        if canLoadOnlineContent && !isOfflineMode {
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
    
    private func toggleOfflineMode() {
        offlineManager.toggleOfflineMode()
    }
}
*/
