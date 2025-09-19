//
//  AlbumsView.swift - MIGRATED: Single Dependency Injection
//  NavidromeClient
//
//   BEFORE: 8 @EnvironmentObject declarations
//   AFTER: 1 @EnvironmentObject declaration + deps.prefix
//

import SwiftUI

struct AlbumsView: View {
    // Nur eine Dependency statt 8+
    @EnvironmentObject var deps: AppDependencies
    
    
    // State
    @State private var searchText = ""
    @State private var selectedAlbumSort: ContentService.AlbumSortType = .alphabetical
    @StateObject private var debouncer = Debouncer()
    
    // MARK: - Computed Properties (with deps.prefix)
    
    private var displayedAlbums: [Album] {
        let sourceAlbums = getAlbumDataSource()
        return filterAlbums(sourceAlbums)
    }
    
    private var isOfflineMode: Bool {
        return !deps.networkMonitor.isConnected || deps.offlineManager.isOfflineMode
    }
    
    private var shouldShowLoading: Bool {
        return deps.musicLibraryManager.isLoading && !deps.musicLibraryManager.hasLoadedInitialData
    }
    
    private var isEmpty: Bool {
        return displayedAlbums.isEmpty
    }
    
    // MARK: - Body (unchanged structure, deps.prefix usage)
    
    var body: some View {
        LibraryView(
            title: "Albums",
            isLoading: shouldShowLoading,
            isEmpty: isEmpty && !shouldShowLoading,
            isOfflineMode: isOfflineMode,
            emptyStateType: .albums,
            onRefresh: { await refreshAllData() },
            searchText: $searchText,
            searchPrompt: "Search albums...",
            toolbarConfig: .libraryWithSort(
                title: "Albums",
                isOffline: isOfflineMode,
                currentSort: selectedAlbumSort,
                sortOptions: ContentService.AlbumSortType.allCases,
                onRefresh: { await refreshAllData() },
                onToggleOffline: { toggleOfflineMode() },
                onSort: { sortType in
                    Task { await loadAlbums(sortBy: sortType) }
                }
            )
        ) {
            AlbumsGridContent()
        }
        .onChange(of: searchText) { _, _ in
            handleSearchTextChange()
        }
        .task(id: displayedAlbums.count) {
            await preloadAlbumImages()
        }
    }

    // MARK: - Grid Content (deps.prefix usage)
    
    @ViewBuilder
    private func AlbumsGridContent() -> some View {
        UnifiedContainer(
            items: displayedAlbums,
            layout: .twoColumnGrid,
            onLoadMore: { _ in
                Task {
                    await deps.musicLibraryManager.loadMoreAlbumsIfNeeded()
                }
            }
        ) { album, index in
            NavigationLink {
                AlbumDetailView(album: album)
            } label: {
                CardItemContainer(content: .album(album), index: index)
            }
        }
    }

    // MARK: - Business Logic (deps.prefix usage)
    
    private func getAlbumDataSource() -> [Album] {
        if deps.networkMonitor.canLoadOnlineContent && !isOfflineMode {
            return deps.musicLibraryManager.albums
        } else {
            let downloadedAlbumIds = Set(deps.downloadManager.downloadedAlbums.map { $0.albumId })
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
        await deps.musicLibraryManager.refreshAllData()
    }
    
    private func loadAlbums(sortBy: ContentService.AlbumSortType) async {
        selectedAlbumSort = sortBy
        await deps.musicLibraryManager.loadAlbumsProgressively(sortBy: sortBy, reset: true)
    }
    
    private func preloadAlbumImages() async {
        let albumsToPreload = Array(displayedAlbums.prefix(20))
        await deps.coverArtManager.preloadAlbums(albumsToPreload, size: 200)
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

// MARK: - Migration Summary

/*
CHANGES MADE:
✅ 8 @EnvironmentObject → 1 @EnvironmentObject
✅ All manager access via deps.prefix
✅ All business logic unchanged
✅ All UI logic unchanged

BEFORE → AFTER:
navidromeVM.loadAlbums() → deps.navidromeVM.loadAlbums()
musicLibraryManager.albums → deps.musicLibraryManager.albums
networkMonitor.isConnected → deps.networkMonitor.isConnected
offlineManager.isOfflineMode → deps.offlineManager.isOfflineMode
downloadManager.downloadedAlbums → deps.downloadManager.downloadedAlbums
coverArtManager.preloadAlbums() → deps.coverArtManager.preloadAlbums()

EFFORT: ~15 Änderungen in einer 120-Zeilen View
RESULT: Gleiche Funktionalität, viel sauberere Dependencies
*/
