import SwiftUI

struct SearchView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    
    @State private var query: String = ""
    @State private var selectedTab: SearchTab = .songs
    
    @StateObject private var debouncer = Debouncer()
    
    enum SearchTab: String, CaseIterable {
        case artists = "Künstler"
        case albums = "Alben"
        case songs = "Songs"
        
        var icon: String {
            switch self {
            case .artists: return "person.2.fill"
            case .albums: return "record.circle.fill"
            case .songs: return "music.note"
            }
        }
    }
    
    // MARK: - Computed Properties
    private var hasResults: Bool {
        !navidromeVM.artists.isEmpty || !navidromeVM.albums.isEmpty || !navidromeVM.songs.isEmpty
    }
    
    private var resultCount: Int {
        switch selectedTab {
        case .artists: return navidromeVM.artists.count
        case .albums: return navidromeVM.albums.count
        case .songs: return navidromeVM.songs.count
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                
                VStack(spacing: 0) {
                    SearchHeaderView(
                        query: $query,
                        selectedTab: $selectedTab,
                        countForTab: countForTab,
                        onSearch: performSearch,
                        onClear: clearResults
                    )
                    
                    SearchContentView(
                        query: query,
                        selectedTab: selectedTab,
                        hasResults: hasResults,
                        navidromeVM: navidromeVM,
                        playerVM: playerVM,
                        onSongTap: handleSongTap
                    )
                    
                    Spacer()
                }
            }
            .navigationTitle("Suche")
            .navigationBarTitleDisplayMode(.large)
            .accountToolbar()  // hier wird das Icon hinzugefügt

        }
        .onChange(of: query) { _, newValue in
            handleQueryChange(newValue)
        }
    }
    
    // MARK: - Private Methods
    private func performSearch() {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        Task {
            await navidromeVM.search(query: query.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
    
    private func clearResults() {
        navidromeVM.artists = []
        navidromeVM.albums = []
        navidromeVM.songs = []
        navidromeVM.errorMessage = nil
    }
    
    private func countForTab(_ tab: SearchTab) -> Int {
        switch tab {
        case .artists: return navidromeVM.artists.count
        case .albums: return navidromeVM.albums.count
        case .songs: return navidromeVM.songs.count
        }
    }
    
    private func handleQueryChange(_ newValue: String) {
        debouncer.debounce {
            if !newValue.isEmpty {
                performSearch()
            }
        }
    }
    
    private func handleSongTap(at index: Int) {
        Task {
            await playerVM.setPlaylist(
                navidromeVM.songs,
                startIndex: index,
                albumId: nil
            )
        }
    }
}

// MARK: - SearchHeaderView
struct SearchHeaderView: View {
    @Binding var query: String
    @Binding var selectedTab: SearchView.SearchTab
    let countForTab: (SearchView.SearchTab) -> Int
    let onSearch: () -> Void
    let onClear: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            SearchBarView(
                query: $query,
                onSearch: onSearch,
                onClear: onClear
            )
            
            SearchTabsView(
                selectedTab: $selectedTab,
                countForTab: countForTab
            )
        }
        .padding(.top, 8)
        .background(.ultraThinMaterial)
    }
}

// MARK: - SearchBarView
struct SearchBarView: View {
    @Binding var query: String
    let onSearch: () -> Void
    let onClear: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.title3)
            
            TextField("Nach Musik suchen...", text: $query)
                .font(.body)
                .submitLabel(.search)
                .onSubmit(onSearch)
            
            if !query.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .animation(.easeInOut(duration: 0.2), value: query.isEmpty)
    }
}

// MARK: - SearchTabsView
struct SearchTabsView: View {
    @Binding var selectedTab: SearchView.SearchTab
    let countForTab: (SearchView.SearchTab) -> Int
    
    var body: some View {
        HStack(spacing: 10) {
            ForEach(SearchView.SearchTab.allCases, id: \.self) { tab in
                SearchTabButton(
                    tab: tab,
                    count: countForTab(tab),
                    isSelected: selectedTab == tab,
                    onTap: { selectedTab = tab }
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

// MARK: - SearchTabButton
struct SearchTabButton: View {
    let tab: SearchView.SearchTab
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.caption)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(countBackground)
                        .clipShape(Capsule())
                        .foregroundStyle(isSelected ? .white : .primary)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(tabBackground)
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    @ViewBuilder
    private var countBackground: some View {
        if isSelected {
            LinearGradient(
                colors: [.blue, .purple],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            Color.gray.opacity(0.2)
        }
    }
    
    private var tabBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                isSelected
                ? AnyShapeStyle(LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                : AnyShapeStyle(Color.gray.opacity(0.1))
            )
    }
}

// MARK: - SearchContentView
struct SearchContentView: View {
    let query: String
    let selectedTab: SearchView.SearchTab
    let hasResults: Bool
    let navidromeVM: NavidromeViewModel
    let playerVM: PlayerViewModel
    let onSongTap: (Int) -> Void
    
    var body: some View {
        Group {
            if let error = navidromeVM.errorMessage {
                SearchErrorView(error: error)
            } else if hasResults {
                SearchResultsView(
                    selectedTab: selectedTab,
                    navidromeVM: navidromeVM,
                    playerVM: playerVM,
                    onSongTap: onSongTap
                )
            } else if !query.isEmpty && !navidromeVM.isLoading {
                SearchEmptyView()
            } else if query.isEmpty {
                SearchInitialView()
            }
        }
    }
}

// MARK: - State Views
struct SearchErrorView: View {
    let error: String
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.orange)
            
            VStack(spacing: 8) {
                Text("Fehler bei der Suche")
                    .font(.headline.weight(.semibold))
                
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(radius: 20, y: 10)
        .padding(.horizontal, 40)
        .padding(.vertical, 60)
    }
}

struct SearchEmptyView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "music.note.house")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text("Keine Ergebnisse")
                    .font(.title2.weight(.semibold))
                
                Text("Versuchen Sie andere Suchbegriffe")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(32)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(radius: 20, y: 10)
        .padding(.vertical, 60)
    }
}

struct SearchInitialView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 80))
                .foregroundStyle(.secondary.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("Musik durchsuchen")
                    .font(.title2.weight(.semibold))
                
                Text("Suchen Sie nach Künstlern, Alben oder Songs")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(radius: 20, y: 10)
        .padding(.vertical, 80)
    }
}

// MARK: - SearchResultsView
struct SearchResultsView: View {
    let selectedTab: SearchView.SearchTab
    let navidromeVM: NavidromeViewModel
    let playerVM: PlayerViewModel
    let onSongTap: (Int) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                Section {
                    switch selectedTab {
                    case .artists:
                        ForEach(navidromeVM.artists) { artist in
                            SearchResultArtistRow(artist: artist)
                        }
                        
                    case .albums:
                        ForEach(navidromeVM.albums) { album in
                            SearchResultAlbumRow(album: album)
                        }
                        
                    case .songs:
                        ForEach(Array(navidromeVM.songs.enumerated()), id: \.element.id) { index, song in
                            SearchResultSongRow(
                                song: song,
                                index: index + 1,
                                isPlaying: playerVM.currentSong?.id == song.id && playerVM.isPlaying,
                                action: { onSongTap(index) }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }
}

