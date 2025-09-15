//
//  GenreView.swift - REFACTORED to Pure UI
//  NavidromeClient
//
//  ✅ CLEAN: All business logic moved to LibraryViewModel
//  ✅ DRY: No more duplicated filtering/sorting logic
//

import SwiftUI

struct GenreView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    
    // ✅ NEW: Single source of truth for all UI logic
    @StateObject private var libraryVM = LibraryViewModel()
    
    var body: some View {
        NavigationStack {
            Group {
                if libraryVM.shouldShowGenresLoading {
                    genresLoadingView
                } else if libraryVM.shouldShowGenresEmptyState {
                    genresEmptyStateView
                } else {
                    genresContentView
                }
            }
            .navigationTitle("Genres")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $libraryVM.searchText,
                placement: .automatic,
                prompt: "Search genres..."
            )
            .onChange(of: libraryVM.searchText) { _, _ in
                // ✅ REACTIVE: ViewModel handles debouncing
                libraryVM.handleSearchTextChange()
            }
            .toolbar {
                genresToolbarContent
            }
            .refreshable {
                // ✅ SINGLE LINE: ViewModel handles all complexity
                await libraryVM.refreshAllData()
            }
            .navigationDestination(for: Genre.self) { genre in
                ArtistDetailView(context: .genre(genre))
            }
            .accountToolbar()
        }
    }
    
    // MARK: - ✅ Pure UI Components
    
    private var genresLoadingView: some View {
        VStack(spacing: 16) {
            loadingView()
            
            if libraryVM.isLoadingInBackground {
                Text(libraryVM.backgroundLoadingProgress)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var genresEmptyStateView: some View {
        GenresEmptyStateView(
            isOnline: libraryVM.canLoadOnlineContent,
            isOfflineMode: libraryVM.isOfflineMode
        )
    }
    
    private var genresContentView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // ✅ REACTIVE: Show status header based on ViewModel state
                if libraryVM.isOfflineMode || !libraryVM.canLoadOnlineContent {
                    LibraryStatusHeader.genres(
                        count: libraryVM.genreCount,
                        isOnline: libraryVM.canLoadOnlineContent,
                        isOfflineMode: libraryVM.isOfflineMode
                    )
                }
                
                // ✅ REACTIVE: Genres automatically filtered by ViewModel
                GenreListView(genres: libraryVM.displayedGenres)
            }
        }
    }
    
    @ToolbarContentBuilder
    private var genresToolbarContent: some ToolbarContent {
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

// MARK: - ✅ Reusable GenreListView (extracted from original code)

struct GenreListView: View {
    let genres: [Genre]
    
    var body: some View {
        LazyVStack(spacing: Spacing.s) {
            ForEach(genres, id: \.id) { genre in
                NavigationLink(value: genre) {
                    GenreCard(genre: genre)
                }
            }
        }
        .screenPadding()
        .padding(.bottom, Sizes.miniPlayer)
    }
}
