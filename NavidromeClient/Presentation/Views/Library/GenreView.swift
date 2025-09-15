//
//  GenreView.swift - FIXED (DRY)
//  NavidromeClient
//
//  ✅ FIXED: Removed GenresStatusHeader reference
//  ✅ USES: LibraryStatusHeader.genres() instead
//

import SwiftUI

struct GenreView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var downloadManager: DownloadManager

    @State private var searchText = ""
    
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
                } else if filteredGenres.isEmpty {
                    GenresEmptyStateView(
                        isOnline: networkMonitor.canLoadOnlineContent,
                        isOfflineMode: offlineManager.isOfflineMode
                    )
                } else {
                    mainContent
                }
            }
            .navigationTitle("Genres")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $searchText, placement: .automatic, prompt: "Search genres...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    OfflineModeToggle()
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task { await navidromeVM.refreshAllData() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(navidromeVM.isLoadingInBackground)
                }
            }
            // ✅ SIMPLIFIED: Only refreshable
            .refreshable {
                await navidromeVM.refreshAllData()
            }
            .navigationDestination(for: Genre.self) { genre in
                ArtistDetailView(context: .genre(genre))
            }
            .accountToolbar()
        }
    }
    
    private var filteredGenres: [Genre] {
        let genres: [Genre]
        
        if networkMonitor.canLoadOnlineContent && !offlineManager.isOfflineMode {
            genres = navidromeVM.genres
        } else {
            genres = offlineManager.offlineGenres
        }
        
        if searchText.isEmpty {
            return genres.sorted(by: { $0.value < $1.value })
        } else {
            return genres
                .filter { $0.value.localizedCaseInsensitiveContains(searchText) }
                .sorted(by: { $0.value < $1.value })
        }
    }

    private var mainContent: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.s) {
                if !networkMonitor.canLoadOnlineContent || offlineManager.isOfflineMode {
                    LibraryStatusHeader.genres(
                        count: filteredGenres.count,
                        isOnline: networkMonitor.canLoadOnlineContent,
                        isOfflineMode: offlineManager.isOfflineMode
                    )
                }
                
                ForEach(filteredGenres, id: \.id) { genre in
                    NavigationLink(value: genre) {
                        GenreCard(genre: genre)
                    }
                }
            }
            .screenPadding()
            .padding(.bottom, Sizes.miniPlayer)
        }
    }
}


