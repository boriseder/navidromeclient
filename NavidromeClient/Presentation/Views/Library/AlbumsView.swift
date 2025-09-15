//
//  AlbumsView.swift - REFACTORED to Pure UI
//  NavidromeClient
//
//  ✅ CLEAN: All business logic moved to LibraryViewModel
//  ✅ DRY: No more duplicated filtering/sorting logic
//

import SwiftUI

struct AlbumsView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var coverArtManager: CoverArtManager
    
    // ✅ NEW: Single source of truth for all UI logic
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
                text: $libraryVM.searchText,
                placement: .automatic,
                prompt: "Search albums..."
            )
            .onChange(of: libraryVM.searchText) { _, _ in
                // ✅ REACTIVE: ViewModel handles debouncing
                libraryVM.handleSearchTextChange()
            }
            .toolbar {
                albumsToolbarContent
            }
            .refreshable {
                // ✅ SINGLE LINE: ViewModel handles all complexity
                await libraryVM.refreshAllData()
            }
            .task(id: libraryVM.displayedAlbums.count) {
                // ✅ SINGLE LINE: ViewModel coordinates preloading
                await libraryVM.preloadAlbumImages(libraryVM.displayedAlbums, coverArtManager: coverArtManager)
            }
            .accountToolbar()
        }
    }
    
    // MARK: - ✅ Pure UI Components
    
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
                // ✅ REACTIVE: Show status header based on ViewModel state
                if libraryVM.isOfflineMode || !libraryVM.canLoadOnlineContent {
                    LibraryStatusHeader(
                        itemType: .albums,
                        count: libraryVM.albumCount,
                        isOnline: libraryVM.canLoadOnlineContent,
                        isOfflineMode: libraryVM.isOfflineMode
                    )
                }
                
                // ✅ REACTIVE: Albums automatically filtered by ViewModel
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
                        // ✅ SINGLE LINE: ViewModel handles sorting logic
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
            // ✅ SINGLE LINE: ViewModel handles mode switching
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
                // ✅ SINGLE LINE: ViewModel handles refresh logic
                await libraryVM.refreshAllData()
            }
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .disabled(libraryVM.isLoadingInBackground)
    }
}

// MARK: - ✅ Reusable AlbumGridView (unchanged but can be enhanced)

struct AlbumGridView: View {
    let albums: [Album]
    
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    
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
                    // ✅ PASS INDEX: For staggered loading
                    AlbumCard(album: album, accentColor: .primary, index: index)
                }
            }
        }
    }
}
