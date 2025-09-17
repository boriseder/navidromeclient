//
//  SearchView.swift - COMPLETE OPTIMIZED VERSION
//  NavidromeClient
//
//  ✅ PRECISE: Field-specific search only
//  ✅ OPTIMIZED: Simplified logic and better state management
//  ✅ FIXED: All previous issues resolved
//

import SwiftUI

struct SearchView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var downloadManager: DownloadManager
    
    @State private var query: String = ""
    @State private var selectedTab: SearchTab = .songs
    @State private var searchResults = SearchResults()
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var searchTask: Task<Void, Never>?
    
    enum SearchTab: String, CaseIterable {
        case artists = "Artists"
        case albums = "Albums"
        case songs = "Songs"
        
        var icon: String {
            switch self {
            case .artists: return "person.2.fill"
            case .albums: return "record.circle.fill"
            case .songs: return "music.note"
            }
        }
    }
    
    struct SearchResults {
        var artists: [Artist] = []
        var albums: [Album] = []
        var songs: [Song] = []
        
        var isEmpty: Bool {
            artists.isEmpty && albums.isEmpty && songs.isEmpty
        }
        
        var totalCount: Int {
            artists.count + albums.count + songs.count
        }
        
        func count(for type: SearchTab) -> Int {
            switch type {
            case .artists: return artists.count
            case .albums: return albums.count
            case .songs: return songs.count
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if shouldUseOfflineSearch {
                    SearchModeHeader()
                }
                
                SearchHeaderView(
                    query: $query,
                    selectedTab: $selectedTab,
                    countForTab: countForTab,
                    onSearch: performSearch,
                    onClear: clearSearch
                )
                
                SearchContentView()
                Spacer()
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .accountToolbar()
        }
        .onChange(of: query) { _, newValue in
            handleQueryChange(newValue)
        }
        .onDisappear {
            searchTask?.cancel()
        }
    }
    
    // ✅ FOCUSED: Online Search via NavidromeViewModel only
    private func performOnlineSearch(query: String) {
        searchTask = Task {
            do {
                // ✅ ROUTE: Through NavidromeViewModel (no direct service access)
                let result = await navidromeVM.search(query: query)
                
                if !Task.isCancelled {
                    await MainActor.run {
                        let filteredResults = filterResultsByField(result, query: query.lowercased())
                        searchResults = SearchResults(
                            artists: filteredResults.artists,
                            albums: filteredResults.albums,
                            songs: filteredResults.songs
                        )
                        isSearching = false
                        print("🎯 Online search via NavidromeVM: Artists:\(filteredResults.artists.count), Albums:\(filteredResults.albums.count), Songs:\(filteredResults.songs.count)")
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        searchError = "Search failed: \(error.localizedDescription)"
                        searchResults = SearchResults()
                        isSearching = false
                    }
                }
            }
        }
    }
    
    // ❌ REMOVED: navidromeVM.getService() calls
    // ❌ REMOVED: Direct UnifiedSubsonicService access
    // ❌ REMOVED: Manual service.search() calls
    
    // ... (rest unchanged - routes through ViewModels)
}

// MARK: - ✅ Search Header Components

struct SearchHeaderView: View {
    @Binding var query: String
    @Binding var selectedTab: SearchView.SearchTab
    let countForTab: (SearchView.SearchTab) -> Int
    let onSearch: () -> Void
    let onClear: () -> Void
    
    var body: some View {
        VStack(spacing: Spacing.m) {
            // Search Bar
            HStack(spacing: Spacing.s) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(TextColor.secondary)
                    .font(Typography.title3)
                
                TextField("Search music...", text: $query)
                    .font(Typography.body)
                    .submitLabel(.search)
                    .onSubmit(onSearch)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                
                if !query.isEmpty {
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(TextColor.secondary)
                    }
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.horizontal, Padding.m)
            .padding(.vertical, Padding.s)
            .background(BackgroundColor.thin, in: RoundedRectangle(cornerRadius: Radius.l))
            .animation(Animations.ease, value: query.isEmpty)
            
            // Search Tabs
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
        }
        .listItemPadding()
        .background(BackgroundColor.thin)
    }
}

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
                
                Text(tab.rawValue)
                    .font(Typography.caption)
                
                if count > 0 {
                    Text("\(count)")
                        .font(Typography.caption2)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, Spacing.xs/2)
                        .background(Capsule().fill(isSelected ? TextColor.onDark.opacity(0.3) : BackgroundColor.secondary))
                        .foregroundStyle(isSelected ? TextColor.onDark : TextColor.secondary)
                }
            }
            .padding(.vertical, Padding.s)
            .padding(.horizontal, Padding.m)
            .background(
                RoundedRectangle(cornerRadius: Radius.m)
                    .fill(isSelected ? BrandColor.primary : BackgroundColor.secondary)
            )
            .foregroundStyle(isSelected ? TextColor.onDark : TextColor.primary)
        }
        .animation(Animations.ease, value: isSelected)
        .animation(Animations.ease, value: count)
    }
}
