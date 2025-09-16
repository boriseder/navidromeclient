//
//  AlbumsView.swift - FIXED: Proper LibraryViewModel usage
//  NavidromeClient
//
//  ✅ FIXED: LibraryViewModel as @StateObject with no arguments
//

import SwiftUI

struct AlbumsView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var coverArtManager: CoverArtManager
    
    // ✅ FIXED: LibraryViewModel as @StateObject (no arguments needed - uses singletons internally)
    @StateObject private var libraryVM = LibraryViewModel()
    
    var body: some View {
        NavigationStack {
            Group {
                if libraryVM.shouldShowAlbumsLoading {
                    albumsLoadingView
                } else if libraryVM.shouldShowAlbumsEmptyState {
                    albumsEmptyStateView
                } else {
                    albumsContentView
                }
            }
            .navigationTitle("Albums")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $libraryVM.searchText, // ✅ FIXED: Now works
                placement: .automatic,
                prompt: "Search albums..."
            )
            .onChange(of: libraryVM.searchText) { _, _ in
                libraryVM.handleSearchTextChange()
            }
            .toolbar {
                albumsToolbarContent
            }
            .refreshable {
                await libraryVM.refreshAllData()
            }
            .task(id: libraryVM.displayedAlbums.count) {
                await libraryVM.preloadAlbumImages(libraryVM.displayedAlbums, coverArtManager: coverArtManager)
            }
            .accountToolbar()
        }
    }
    
    // MARK: - ✅ Pure UI Components (unchanged)
    
    private var albumsLoadingView: some View {
        VStack(spacing: 16) {
            loadingView()
            
            if libraryVM.isLoadingInBackground {
                Text(libraryVM.backgroundLoadingProgress)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var albumsEmptyStateView: some View {
        AlbumsEmptyStateView(
            isOnline: libraryVM.canLoadOnlineContent,
            isOfflineMode: libraryVM.isOfflineMode
        )
    }
    
    private var albumsContentView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if libraryVM.isOfflineMode || !libraryVM.canLoadOnlineContent {
                    LibraryStatusHeader(
                        itemType: .albums,
                        count: libraryVM.albumCount,
                        isOnline: libraryVM.canLoadOnlineContent,
                        isOfflineMode: libraryVM.isOfflineMode
                    )
                }
                
                AlbumGridView(albums: libraryVM.displayedAlbums)
            }
        }
    }
    
    @ToolbarContentBuilder
    private var albumsToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            albumSortMenu
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            offlineModeToggle
        }
        
        ToolbarItem(placement: .navigationBarLeading) {
            refreshButton
        }
    }
    
    private var albumSortMenu: some View {
        Menu {
            ForEach(libraryVM.availableAlbumSorts, id: \.self) { sortType in
                Button {
                    Task {
                        await libraryVM.loadAlbums(sortBy: sortType)
                    }
                } label: {
                    HStack {
                        Text(sortType.displayName)
                        if libraryVM.isAlbumSortSelected(sortType) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: libraryVM.selectedAlbumSort.icon)
        }
    }
    
    private var offlineModeToggle: some View {
        Button {
            libraryVM.toggleOfflineMode()
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: libraryVM.isOfflineMode ? "icloud.slash" : "icloud")
                    .font(Typography.caption)
                Text(libraryVM.isOfflineMode ? "Offline" : "All")
                    .font(Typography.caption)
            }
            .foregroundStyle(libraryVM.isOfflineMode ? BrandColor.warning : BrandColor.primary)
            .padding(.horizontal, Padding.s)
            .padding(.vertical, Padding.xs)
            .background(
                Capsule()
                    .fill((libraryVM.isOfflineMode ? BrandColor.warning : BrandColor.primary).opacity(0.1))
            )
        }
    }
    
    private var refreshButton: some View {
        Button {
            Task {
                await libraryVM.refreshAllData()
            }
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .disabled(libraryVM.isLoadingInBackground)
    }
}

// MARK: - ✅ Reusable AlbumGridView (unchanged)

struct AlbumGridView: View {
    let albums: [Album]
    
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var libraryVM: LibraryViewModel

    var body: some View {
        ScrollView {
            albumsGrid
                .screenPadding()
                .padding(.bottom, 100)
        }
    }
    
    private var albumsGrid: some View {
        LazyVGrid(columns: GridColumns.two, spacing: Spacing.l) {
            ForEach(albums.indices, id: \.self) { index in
                let album = albums[index]
                NavigationLink {
                    AlbumDetailView(album: album)
                } label: {
                    AlbumCard(album: album, accentColor: .primary, index: index)
                }
                .onAppear {
                    if index == albums.count - 5 {
                        Task { await navidromeVM.loadMoreAlbumsIfNeeded() }
                    }
                }
            }
        }
    }
}
