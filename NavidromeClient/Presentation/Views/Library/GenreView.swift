//
//  GenreView.swift - ELIMINATED LibraryViewModel
//  NavidromeClient
//
//  ✅ DIRECT: No unnecessary abstraction layer
//  ✅ CLEAN: Direct manager access for better performance
//

import SwiftUI

struct GenreView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var musicLibraryManager: MusicLibraryManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    
    @State private var searchText = ""
    @StateObject private var debouncer = Debouncer()
    
    // MARK: - ✅ DIRECT: Computed Properties
    
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
    
    private var shouldShowGenresLoading: Bool {
        return musicLibraryManager.isLoading && !musicLibraryManager.hasLoadedInitialData
    }
    
    private var shouldShowGenresEmptyState: Bool {
        return !musicLibraryManager.isLoading && displayedGenres.isEmpty
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
                if shouldShowGenresLoading {
                    LoadingView()
                } else if shouldShowGenresEmptyState {
                    EmptyStateView.genres()
                } else {
                    genresContentView
                }
            }
            .navigationTitle("Genres")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $searchText,
                placement: .automatic,
                prompt: "Search genres..."
            )
            .onChange(of: searchText) { _, _ in
                handleSearchTextChange()
            }
            .toolbar {
                genresToolbarContent
            }
            .refreshable {
                await refreshAllData()
            }
            .navigationDestination(for: Genre.self) { genre in
                ArtistDetailView(context: .genre(genre))
            }
            .accountToolbar()
        }
    }
    
    // MARK: - ✅ DIRECT: Data Source Logic
    
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
    
    // MARK: - ✅ DIRECT: Actions
    
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
    
    // MARK: - ✅ UI Components
    
    private var genresLoadingView: some View {
        VStack(spacing: 16) {
            LoadingView()
            
            if isLoadingInBackground {
                Text(backgroundLoadingProgress)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
      
    private var genresContentView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if isOfflineMode || !canLoadOnlineContent {
                    LibraryStatusHeader.genres(
                        count: genreCount,
                        isOnline: canLoadOnlineContent,
                        isOfflineMode: isOfflineMode
                    )
                }
                
                GenreListView(genres: displayedGenres)
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
            toggleOfflineMode()
        } label: {
            HStack(spacing: DSLayout.tightGap) {
                Image(systemName: isOfflineMode ? "icloud.slash" : "icloud")
                    .font(DSText.metadata)
                Text(isOfflineMode ? "Offline" : "All")
                    .font(DSText.metadata)
            }
            .foregroundStyle(isOfflineMode ? DSColor.warning : DSColor.accent)
            .padding(.horizontal, DSLayout.elementPadding)
            .padding(.vertical, DSLayout.tightPadding)
            .background(
                Capsule()
                    .fill((isOfflineMode ? DSColor.warning : DSColor.accent).opacity(0.1))
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

// MARK: - ✅ Reusable GenreListView (extracted from original code)

struct GenreListView: View {
    let genres: [Genre]
    
    var body: some View {
        LazyVStack(spacing: DSLayout.elementGap) {
            ForEach(genres, id: \.id) { genre in
                NavigationLink(value: genre) {
                    GenreCard(genre: genre)
                }
            }
        }
        .screenPadding()
        .padding(.bottom, DSLayout.miniPlayerHeight)
    }
}
