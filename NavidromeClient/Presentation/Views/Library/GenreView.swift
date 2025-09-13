import SwiftUI

struct GenreView: View {
    // ALLE zu @EnvironmentObject geändert - KEINE @StateObject für Singletons!
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var downloadManager: DownloadManager

    // NUR View-spezifischer State als @State
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
        let genres: [Genre]
        
        if networkMonitor.canLoadOnlineContent && !offlineManager.isOfflineMode {
            genres = navidromeVM.genres
        } else {
            genres = getOfflineGenres()
        }
        
        if searchText.isEmpty {
            return genres.sorted(by: { $0.value < $1.value })
        } else {
            return genres
                .filter { $0.value.localizedCaseInsensitiveContains(searchText) }
                .sorted(by: { $0.value < $1.value })
        }
    }
    
    private func getOfflineGenres() -> [Genre] {
        let downloadedAlbums = downloadManager.downloadedAlbums
        let albumIds = Set(downloadedAlbums.map { $0.albumId })
        let cachedAlbums = AlbumMetadataCache.shared.getAlbums(ids: albumIds)
        
        let genreGroups = Dictionary(grouping: cachedAlbums) { $0.genre ?? "Unknown" }
        return genreGroups.map { genreName, albums in
            Genre(
                value: genreName,
                songCount: albums.reduce(0) { $0 + ($1.songCount ?? 0) },
                albumCount: albums.count
            )
        }
    }

    private var mainContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Status header for offline mode
                if !networkMonitor.canLoadOnlineContent || offlineManager.isOfflineMode {
                    GenresStatusHeader(
                        isOnline: networkMonitor.canLoadOnlineContent,
                        isOfflineMode: offlineManager.isOfflineMode,
                        genreCount: filteredGenres.count
                    )
                }
                
                ForEach(filteredGenres, id: \.id) { genre in
                    NavigationLink(value: genre) {
                        GenreCard(genre: genre)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 90)
        }
    }
    
    private func loadGenres() async {
        if networkMonitor.canLoadOnlineContent && !offlineManager.isOfflineMode {
            await navidromeVM.loadGenresWithOfflineSupport()
        }
    }
}

// MARK: - Genre Card
struct GenreCard: View {
    let genre: Genre

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(.black.opacity(0.1))
                .frame(width: 44, height: 44)
                .blur(radius: 1)
                .overlay(
                    Image(systemName: "music.note")
                        .foregroundStyle(.white)
                )
            
            VStack(alignment: .leading, spacing: 6) {
                Text(genre.value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.black.opacity(0.9))
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Image(systemName: "record.circle")
                        .font(.caption)
                        .foregroundColor(.black.opacity(0.6))

                    let count = genre.albumCount
                    Text("\(count) Album\(count != 1 ? "s" : "")")
                        .font(.caption)
                        .foregroundColor(.black.opacity(0.6))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Genres Empty State View
struct GenresEmptyStateView: View {
    let isOnline: Bool
    let isOfflineMode: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text(emptyStateTitle)
                    .font(.title2.weight(.semibold))
                
                Text(emptyStateMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if !isOnline && !isOfflineMode {
                Button("Switch to Downloaded Music") {
                    OfflineManager.shared.switchToOfflineMode()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(40)
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

// MARK: - Genres Status Header
struct GenresStatusHeader: View {
    let isOnline: Bool
    let isOfflineMode: Bool
    let genreCount: Int
    
    var body: some View {
        HStack {
            NetworkStatusIndicator()
            
            Spacer()
            
            Text("\(genreCount) Genres")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            if isOnline {
                OfflineModeToggle()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
