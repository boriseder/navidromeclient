//
//  AlbumsView.swift
//  NavidromeClient
//
//
//

import SwiftUI

struct AlbumsView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var coverArtService: ReactiveCoverArtService
    
    @State private var searchText = ""
    @State private var selectedSortType: SubsonicService.AlbumSortType = .alphabetical

    // ✅ SIMPLIFIED: No hasLoadedOnce, no task, no onChange
    
    var body: some View {
        NavigationStack {
            Group {
                if navidromeVM.isLoading && !navidromeVM.hasLoadedInitialData {
                    VStack(spacing: 16) {
                        loadingView()
                        
                        if navidromeVM.isLoadingInBackground {
                            Text(navidromeVM.backgroundLoadingProgress)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if displayedAlbums.isEmpty {
                    albumsEmptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if !networkMonitor.canLoadOnlineContent || offlineManager.isOfflineMode {
                                LibraryStatusHeader.albums(
                                    count: displayedAlbums.count,
                                    isOnline: networkMonitor.canLoadOnlineContent,
                                    isOfflineMode: offlineManager.isOfflineMode
                                )
                            }
                            
                            AlbumGridView(albums: displayedAlbums)
                        }
                    }
                    // ✅ SIMPLIFIED: Only refreshable - no other loading triggers
                    .refreshable {
                        await navidromeVM.refreshAllData()
                    }
                }
            }
            .navigationTitle("Albums")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, placement: .automatic, prompt: "Search albums...")
            .toolbar {
                toolbarContent
            }
            .accountToolbar()
            .task(id: displayedAlbums.count) {
                await preloadDisplayedAlbums()
            }
        }
    }
    
    // Rest of the computed properties and helper methods remain the same...
    private var displayedAlbums: [Album] {
        let sourceAlbums = getSourceAlbums()
        return filterAlbums(sourceAlbums)
    }
    
    private func getSourceAlbums() -> [Album] {
        let canLoadOnline = networkMonitor.canLoadOnlineContent
        let isOffline = offlineManager.isOfflineMode
        
        if canLoadOnline && !isOffline {
            return navidromeVM.albums
        } else {
            let downloadedAlbumIds = Set(DownloadManager.shared.downloadedAlbums.map { $0.albumId })
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
    
    private var albumsEmptyStateView: some View {
        AlbumsEmptyStateView(
            isOnline: networkMonitor.canLoadOnlineContent,
            isOfflineMode: offlineManager.isOfflineMode
        )
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                ForEach(SubsonicService.AlbumSortType.allCases, id: \.self) { sortType in
                    Button {
                        selectedSortType = sortType
                        Task { await navidromeVM.loadAllAlbums(sortBy: sortType) }
                    } label: {
                        HStack {
                            Text(sortType.displayName)
                            if selectedSortType == sortType {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: selectedSortType.icon)
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            OfflineModeToggle()
        }
        
        // ✅ SIMPLIFIED: Manual refresh button (optional)
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                Task { await navidromeVM.refreshAllData() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(navidromeVM.isLoadingInBackground)
        }
    }
    
    private func preloadDisplayedAlbums() async {
        let albums = displayedAlbums
        guard !albums.isEmpty else { return }
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        Task {
            await coverArtService.preloadAlbums(Array(albums.prefix(20)), size: 200)
        }
    }
}
