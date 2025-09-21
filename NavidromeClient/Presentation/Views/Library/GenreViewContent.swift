//
//  GenreViewContent.swift
//  NavidromeClient
//
//  Created by Boris Eder on 21.09.25.
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
            .onChange(of: searchText) { _, _ in
                handleSearchTextChange()
            }
            .navigationDestination(for: Genre.self) { genre in
                ArtistDetailViewContent(context: .genre(genre))
            }
            .navigationDestination(for: Album.self) { album in
                AlbumDetailViewContent(album: album)
            }
            .unifiedToolbar(genreToolbarConfig)
        }
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
    
    private var genreToolbarConfig: ToolbarConfiguration {
        .library(
            title: "Genres",
            isOffline: isOfflineMode,
            onRefresh: {
                await refreshAllData()
            },
            onToggleOffline: offlineManager.toggleOfflineMode
        )
    }
}
