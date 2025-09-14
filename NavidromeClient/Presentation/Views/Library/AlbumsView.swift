//
//  AlbumsView.swift - Enhanced with Design System
//  NavidromeClient
//
//  ✅ ENHANCED: Vollständige Anwendung des Design Systems
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
    @State private var isLoading = false
    @State private var hasLoadedOnce = false

    // Broken up complex expression into simpler computed properties
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
    
    private var availableSortTypes: [SubsonicService.AlbumSortType] {
        let canLoadOnline = networkMonitor.canLoadOnlineContent
        let isOffline = offlineManager.isOfflineMode
        
        if canLoadOnline && !isOffline {
            return SubsonicService.AlbumSortType.allCases
        } else {
            return [.alphabetical, .alphabeticalByArtist]
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                VStack(spacing: 0) {
                    if isLoading {
                        Spacer()
                        loadingView()
                        Spacer()
                    } else if displayedAlbums.isEmpty {
                        Spacer()
                        albumsEmptyStateView
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                AlbumGridView(albums: displayedAlbums)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Albums")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, placement: .automatic, prompt: "Search albums...")
            .task {
                if !hasLoadedOnce {
                    await loadAlbums()
                    hasLoadedOnce = true
                }
            }
            .refreshable {
                await loadAlbums()
            }
            .onChange(of: networkMonitor.canLoadOnlineContent) { _, canLoad in
                handleNetworkChange(canLoad: canLoad)
            }
            .onChange(of: offlineManager.isOfflineMode) { _, _ in
                // Trigger UI refresh when offline mode changes
            }
            .task(id: displayedAlbums.count) {
                // Preload with delay to avoid publishing during view updates
                await preloadDisplayedAlbums()
            }
            .onReceive(NotificationCenter.default.publisher(for: .serverUnreachable)) { _ in
                offlineManager.switchToOfflineMode()
            }
            .toolbar {
                toolbarContent
            }
            .accountToolbar()
        }
    }
    
    // Simplified empty state view
    private var albumsEmptyStateView: some View {
        AlbumsEmptyStateView(
            isOnline: networkMonitor.canLoadOnlineContent,
            isOfflineMode: offlineManager.isOfflineMode
        )
    }
    
    // Extracted toolbar content with DS
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                ForEach(availableSortTypes, id: \.self) { sortType in
                    Button {
                        selectedSortType = sortType
                        Task { await loadAlbums() }
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
        
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                Task {
                    await loadAlbums()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(navidromeVM.isLoading || networkMonitor.shouldForceOfflineMode)
        }
    }
    
    // Simplified helper methods
    private func handleNetworkChange(canLoad: Bool) {
        if canLoad && !offlineManager.isOfflineMode {
            Task { await loadAlbums() }
        } else if !canLoad {
            offlineManager.switchToOfflineMode()
        }
    }
    
    private func loadAlbums() async {
        let canLoadOnline = networkMonitor.canLoadOnlineContent
        let isOffline = offlineManager.isOfflineMode
        
        guard canLoadOnline && !isOffline else {
            await navidromeVM.loadOfflineAlbums()
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        await navidromeVM.loadAllAlbums(sortBy: selectedSortType)
    }
    
    private func preloadDisplayedAlbums() async {
        let albums = displayedAlbums
        guard !albums.isEmpty else { return }
        
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second delay
        
        Task {
            await coverArtService.preloadAlbums(Array(albums.prefix(20)), size: 200)
        }
    }
}

