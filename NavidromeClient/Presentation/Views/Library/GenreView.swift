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
    @State private var hasLoadedOnce = false

    var body: some View {
        NavigationStack {
            Group {
                if navidromeVM.isLoading {
                    loadingView()
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
                        Task {
                            await loadGenres()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(navidromeVM.isLoading || networkMonitor.shouldForceOfflineMode)
                }
            }
            .task {
                if !hasLoadedOnce {
                    await loadGenres()
                    hasLoadedOnce = true
                }
            }
            .refreshable {
                await loadGenres()
                hasLoadedOnce = true
            }
            .navigationDestination(for: Genre.self) { genre in
                ArtistDetailView(context: .genre(genre))
            }
            .onChange(of: networkMonitor.canLoadOnlineContent) { _, canLoad in
                if !canLoad {
                    offlineManager.switchToOfflineMode()
                } else if canLoad && !offlineManager.isOfflineMode {
                    Task { await loadGenres() }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .serverUnreachable)) { _ in
                offlineManager.switchToOfflineMode()
            }
            .accountToolbar()
        }
    }
    
    private var filteredGenres: [Genre] {
        // ✅ REFACTORED: Use OfflineManager instead of duplicate logic
        let genres: [Genre]
        
        if networkMonitor.canLoadOnlineContent && !offlineManager.isOfflineMode {
            genres = navidromeVM.genres
        } else {
            // ✅ DRY: Use centralized offline genres
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
    
    private func loadGenres() async {
        if networkMonitor.canLoadOnlineContent && !offlineManager.isOfflineMode {
            await navidromeVM.loadGenresWithOfflineSupport()
        }
    }
}

// MARK: - Genre Card (Enhanced with DS)
struct GenreCard: View {
    let genre: Genre

    var body: some View {
        HStack(spacing: Spacing.m) {
            Circle()
                .fill(BackgroundColor.medium)
                .frame(width: Sizes.buttonHeight, height: Sizes.buttonHeight)
                .blur(radius: 1)
                .overlay(
                    Image(systemName: "music.note")
                        .foregroundStyle(TextColor.primary)
                )
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(genre.value)
                    .font(Typography.bodyEmphasized)
                    .foregroundColor(TextColor.primary)
                    .lineLimit(1)

                HStack(spacing: Spacing.xs) {
                    Image(systemName: "record.circle")
                        .font(Typography.caption)
                        .foregroundColor(TextColor.secondary)

                    let count = genre.albumCount
                    Text("\(count) Album\(count != 1 ? "s" : "")")
                        .font(Typography.caption)
                        .foregroundColor(TextColor.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(TextColor.tertiary)
        }
        .listItemPadding()
        .materialCardStyle()
    }
}

// MARK: - Genres Empty State View (Enhanced with DS)
struct GenresEmptyStateView: View {
    let isOnline: Bool
    let isOfflineMode: Bool
    
    var body: some View {
        VStack(spacing: Spacing.l) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 60))
                .foregroundStyle(TextColor.secondary)
            
            VStack(spacing: Spacing.s) {
                Text(emptyStateTitle)
                    .font(Typography.title2)
                
                Text(emptyStateMessage)
                    .font(Typography.subheadline)
                    .foregroundStyle(TextColor.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if !isOnline && !isOfflineMode {
                Button("Switch to Downloaded Music") {
                    OfflineManager.shared.switchToOfflineMode()
                }
                .primaryButtonStyle()
            }
        }
        .padding(Padding.xl)
    }
    
    private var emptyStateIcon: String {
        if !isOnline {
            return "wifi.slash"
        } else if isOfflineMode {
            return "music.note.list.slash"
        } else {
            return "music.note.list"
        }
    }
    
    private var emptyStateTitle: String {
        if !isOnline {
            return "No Connection"
        } else if isOfflineMode {
            return "No Offline Genres"
        } else {
            return "No Genres Found"
        }
    }
    
    private var emptyStateMessage: String {
        if !isOnline {
            return "Connect to WiFi or cellular to browse music genres"
        } else if isOfflineMode {
            return "Download albums with different genres to see them offline"
        } else {
            return "Your music library appears to have no genres"
        }
    }
}
