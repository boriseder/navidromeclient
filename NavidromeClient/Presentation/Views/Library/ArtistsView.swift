//
//  ArtistsView.swift - REFACTORED to Pure UI
//  NavidromeClient
//
//  ✅ CLEAN: All business logic moved to LibraryViewModel
//  ✅ DRY: No more duplicated filtering/sorting logic
//

import SwiftUI

struct ArtistsView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var coverArtManager: CoverArtManager
    
    // ✅ NEW: Single source of truth for all UI logic
    @StateObject private var libraryVM = LibraryViewModel()
    
    var body: some View {
        NavigationStack {
            Group {
                if libraryVM.shouldShowArtistsLoading {
                    artistsLoadingView
                } else if libraryVM.shouldShowArtistsEmptyState {
                    artistsEmptyStateView
                } else {
                    artistsContentView
                }
            }
            .navigationTitle("Artists")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $libraryVM.searchText,
                placement: .automatic,
                prompt: "Search artists..."
            )
            .onChange(of: libraryVM.searchText) { _, _ in
                // ✅ REACTIVE: ViewModel handles debouncing
                libraryVM.handleSearchTextChange()
            }
            .toolbar {
                artistsToolbarContent
            }
            .refreshable {
                // ✅ SINGLE LINE: ViewModel handles all complexity
                await libraryVM.refreshAllData()
            }
            .task(id: libraryVM.displayedArtists.count) {
                // ✅ SINGLE LINE: ViewModel coordinates preloading
                await libraryVM.preloadArtistImages(libraryVM.displayedArtists, coverArtManager: coverArtManager)
            }
            .navigationDestination(for: Artist.self) { artist in
                ArtistDetailView(context: .artist(artist))
            }
            .accountToolbar()
        }
    }
    
    // MARK: - ✅ Pure UI Components
    
    private var artistsLoadingView: some View {
        VStack(spacing: 16) {
            loadingView()
            
            if libraryVM.isLoadingInBackground {
                Text(libraryVM.backgroundLoadingProgress)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var artistsEmptyStateView: some View {
        ArtistsEmptyStateView(
            isOnline: libraryVM.canLoadOnlineContent,
            isOfflineMode: libraryVM.isOfflineMode
        )
    }
    
    private var artistsContentView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // ✅ REACTIVE: Show status header based on ViewModel state
                if libraryVM.isOfflineMode || !libraryVM.canLoadOnlineContent {
                    LibraryStatusHeader.artists(
                        count: libraryVM.artistCount,
                        isOnline: libraryVM.canLoadOnlineContent,
                        isOfflineMode: libraryVM.isOfflineMode
                    )
                }
                
                // ✅ REACTIVE: Artists automatically filtered by ViewModel
                ArtistListView(artists: libraryVM.displayedArtists)
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

// MARK: - ✅ Reusable ArtistListView (extracted from original code)

struct ArtistListView: View {
    let artists: [Artist]
    
    var body: some View {
        LazyVStack(spacing: Spacing.s) {
            ForEach(artists.indices, id: \.self) { index in
                let artist = artists[index]
                NavigationLink(value: artist) {
                    // ✅ PASS INDEX: For staggered loading
                    ArtistCard(artist: artist, index: index)
                }
            }
        }
        .screenPadding()
        .padding(.bottom, Sizes.miniPlayer)
    }
}
