//
//  SearchView.swift - Enhanced with Design System
//  NavidromeClient
//
//  ✅ ENHANCED: Vollständige Anwendung des Design Systems
//

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
            .accountToolbar()
        }
        .onChange(of: query) { _, newValue in
            handleQueryChange(newValue)
        }
    }
    
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

// MARK: - SearchHeaderView (Enhanced with DS)
struct SearchHeaderView: View {
    @Binding var query: String
    @Binding var selectedTab: SearchView.SearchTab
    let countForTab: (SearchView.SearchTab) -> Int
    let onSearch: () -> Void
    let onClear: () -> Void
    
    var body: some View {
        VStack(spacing: Spacing.m) {
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
        .padding(.top, Spacing.s)
        .background(BackgroundColor.thin)
    }
}

// MARK: - SearchBarView (Enhanced with DS)
struct SearchBarView: View {
    @Binding var query: String
    let onSearch: () -> Void
    let onClear: () -> Void
    
    var body: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(TextColor.secondary)
                .font(Typography.title3)
            
            TextField("Nach Musik suchen...", text: $query)
                .font(Typography.body)
                .submitLabel(.search)
                .onSubmit(onSearch)
            
            if !query.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(TextColor.secondary)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, Padding.m)
        .padding(.vertical, Padding.s)
        .background(
            RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                .fill(BackgroundColor.thin)
                .miniShadow()
        )
        .animation(Animations.ease, value: query.isEmpty)
    }
}

// MARK: - SearchTabsView (Enhanced with DS)
struct SearchTabsView: View {
    @Binding var selectedTab: SearchView.SearchTab
    let countForTab: (SearchView.SearchTab) -> Int
    
    var body: some View {
        HStack(spacing: Spacing.s) {
            ForEach(SearchView.SearchTab.allCases, id: \.self) { tab in
                SearchTabButton(
                    tab: tab,
                    count: countForTab(tab),
                    isSelected: selectedTab == tab,
                    onTap: { selectedTab = tab }
                )
            }
        }
        .listItemPadding()
    }
}

// MARK: - SearchTabButton (Enhanced with DS)
struct SearchTabButton: View {
    let tab: SearchView.SearchTab
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: tab.icon)
                    .font(Typography.caption)
                
                if count > 0 {
                    Text("\(count)")
                        .font(Typography.caption2)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, Spacing.xs)
                        .background(countBackground)
                        .clipShape(Capsule())
                        .foregroundStyle(isSelected ? TextColor.onDark : TextColor.primary)
                }
            }
            .padding(.vertical, Padding.s)
            .padding(.horizontal, Padding.s)
            .background(tabBackground)
            .foregroundStyle(isSelected ? TextColor.onDark : TextColor.primary)
        }
        .animation(Animations.ease, value: isSelected)
    }
    
    @ViewBuilder
    private var countBackground: some View {
        if isSelected {
            LinearGradient(
                colors: [BrandColor.primary, BrandColor.secondary],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            BackgroundColor.secondary
        }
    }
    
    private var tabBackground: some View {
        RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
            .fill(
                isSelected
                ? AnyShapeStyle(LinearGradient(
                    colors: [BrandColor.primary, BrandColor.secondary],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                : AnyShapeStyle(BackgroundColor.secondary)
            )
    }
}

// MARK: - SearchContentView (Enhanced with DS)
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

// MARK: - State Views (Enhanced with DS)
struct SearchErrorView: View {
    let error: String
    
    var body: some View {
        VStack(spacing: Spacing.l) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50)) // Approx. DS applied
                .foregroundStyle(BrandColor.warning)
            
            VStack(spacing: Spacing.s) {
                Text("Fehler bei der Suche")
                    .font(Typography.headline)
                
                Text(error)
                    .font(Typography.subheadline)
                    .foregroundStyle(TextColor.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Spacing.xl)
        .materialCardStyle()
        .largeShadow()
        .padding(.horizontal, Padding.xl)
        .padding(.vertical, 60) // Approx. DS applied
    }
}

struct SearchEmptyView: View {
    var body: some View {
        VStack(spacing: Spacing.l) {
            Image(systemName: "music.note.house")
                .font(.system(size: 60)) // Approx. DS applied
                .foregroundStyle(TextColor.secondary)
            
            VStack(spacing: Spacing.s) {
                Text("Keine Ergebnisse")
                    .font(Typography.title2)
                
                Text("Versuchen Sie andere Suchbegriffe")
                    .font(Typography.subheadline)
                    .foregroundStyle(TextColor.secondary)
            }
        }
        .padding(Spacing.xl)
        .materialCardStyle()
        .largeShadow()
        .padding(.vertical, 60) // Approx. DS applied
    }
}

struct SearchInitialView: View {
    var body: some View {
        VStack(spacing: Spacing.l) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 80)) // Approx. DS applied
                .foregroundStyle(TextColor.secondary.opacity(0.6))
            
            VStack(spacing: Spacing.s) {
                Text("Musik durchsuchen")
                    .font(Typography.title2)
                
                Text("Suchen Sie nach Künstlern, Alben oder Songs")
                    .font(Typography.subheadline)
                    .foregroundStyle(TextColor.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Padding.xl)
        .materialCardStyle()
        .largeShadow()
        .padding(.vertical, 80) // Approx. DS applied
    }
}

// MARK: - SearchResultsView (Enhanced with DS)
struct SearchResultsView: View {
    let selectedTab: SearchView.SearchTab
    let navidromeVM: NavidromeViewModel
    let playerVM: PlayerViewModel
    let onSongTap: (Int) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.s) {
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
                        ForEach(navidromeVM.songs.indices, id: \.self) { index in
                            let song = navidromeVM.songs[index]
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
            .screenPadding()
            .padding(.bottom, 100) // Approx. DS applied
        }
    }
}
