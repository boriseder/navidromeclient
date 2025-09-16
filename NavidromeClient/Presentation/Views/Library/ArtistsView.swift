//
//  ArtistsView.swift - ELIMINATED LibraryViewModel
//  NavidromeClient
//
//  ✅ DIRECT: No unnecessary abstraction layer
//  ✅ CLEAN: Direct manager access for better performance
//

import SwiftUI

struct ArtistsView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var coverArtManager: CoverArtManager
    @EnvironmentObject var musicLibraryManager: MusicLibraryManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    
    @State private var searchText = ""
    @StateObject private var debouncer = Debouncer()
    
    // MARK: - ✅ DIRECT: Computed Properties
    
    private var displayedArtists: [Artist] {
        let sourceArtists = getArtistDataSource()
        return filterArtists(sourceArtists)
    }
    
    private var artistCount: Int {
        return displayedArtists.count
    }
    
    private var isOfflineMode: Bool {
        return !networkMonitor.canLoadOnlineContent || offlineManager.isOfflineMode
    }
    
    private var canLoadOnlineContent: Bool {
        return networkMonitor.canLoadOnlineContent
    }
    
    private var shouldShowArtistsLoading: Bool {
        return musicLibraryManager.isLoading && !musicLibraryManager.hasLoadedInitialData
    }
    
    private var shouldShowArtistsEmptyState: Bool {
        return !musicLibraryManager.isLoading && displayedArtists.isEmpty
    }
    
    private var isLoadingInBackground: Bool {
        return musicLibraryManager.isLoadingInBackground
    }
    
    private var backgroundLoadingProgress: String {
        return musicLibraryManager.backgroundLoadingProgress
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if shouldShowArtistsLoading {
                    artistsLoadingView
                } else if shouldShowArtistsEmptyState {
                    artistsEmptyStateView
                } else {
                    artistsContentView
                }
            }
            .navigationTitle("Artists")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $searchText,
                placement: .automatic,
                prompt: "Search artists..."
            )
            .onChange(of: searchText) { _, _ in
                handleSearchTextChange()
            }
            .toolbar {
                artistsToolbarContent
            }
            .refreshable {
                await refreshAllData()
            }
            .task(id: displayedArtists.count) {
                await preloadArtistImages()
            }
            .navigationDestination(for: Artist.self) { artist in
                ArtistDetailView(context: .artist(artist))
            }
            .accountToolbar()
        }
    }
    
    // MARK: - ✅ DIRECT: Data Source Logic
    
    private func getArtistDataSource() -> [Artist] {
        if canLoadOnlineContent && !isOfflineMode {
            return musicLibraryManager.artists
        } else {
            return offlineManager.offlineArtists
        }
    }
    
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
    
    // MARK: - ✅ DIRECT: Actions
    
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
    
    private func toggleOfflineMode() {
        offlineManager.toggleOfflineMode()
    }
    
    // MARK: - ✅ UI Components
    
    private var artistsLoadingView: some View {
        VStack(spacing: 16) {
            loadingView()
            
            if isLoadingInBackground {
                Text(backgroundLoadingProgress)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var artistsEmptyStateView: some View {
        ArtistsEmptyStateView(
            isOnline: canLoadOnlineContent,
            isOfflineMode: isOfflineMode
        )
    }
    
    private var artistsContentView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if isOfflineMode || !canLoadOnlineContent {
                    LibraryStatusHeader.artists(
                        count: artistCount,
                        isOnline: canLoadOnlineContent,
                        isOfflineMode: isOfflineMode
                    )
                }
                
                ArtistListView(artists: displayedArtists)
            }
        }
    }
    
    @ToolbarContentBuilder
    private var artistsToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            offlineModeToggle
        }
        
        ToolbarItem(placement: .navigationBarLeading) {
            refreshButton
        }
    }
    
    private var offlineModeToggle: some View {
        Button {
            toggleOfflineMode()
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: isOfflineMode ? "icloud.slash" : "icloud")
                    .font(Typography.caption)
                Text(isOfflineMode ? "Offline" : "All")
                    .font(Typography.caption)
            }
            .foregroundStyle(isOfflineMode ? BrandColor.warning : BrandColor.primary)
            .padding(.horizontal, Padding.s)
            .padding(.vertical, Padding.xs)
            .background(
                Capsule()
                    .fill((isOfflineMode ? BrandColor.warning : BrandColor.primary).opacity(0.1))
            )
        }
    }
    
    private var refreshButton: some View {
        Button {
            Task {
                await refreshAllData()
            }
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .disabled(isLoadingInBackground)
    }
}

struct ArtistListView: View {
    let artists: [Artist]
    
    var body: some View {
        LazyVStack(spacing: Spacing.s) {
            ForEach(artists.indices, id: \.self) { index in
                let artist = artists[index]
                NavigationLink(value: artist) {
                    ArtistCard(artist: artist, index: index)
                }
            }
        }
        .screenPadding()
        .padding(.bottom, Sizes.miniPlayer)
    }
}

