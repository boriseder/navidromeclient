//
//  GenreViewContent.swift - UPDATED: Unified State System
//  NavidromeClient
//
//   UNIFIED: Single ContentLoadingStrategy for consistent state
//   CLEAN: Simplified toolbar and state management
//   FIXED: Proper refresh method names and error handling
//

import SwiftUI

struct GenreViewContent: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var musicLibraryManager: MusicLibraryManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    
    @State private var searchText = ""
    @StateObject private var debouncer = Debouncer()
    
    // MARK: - UNIFIED: Single State Logic
    
    private var displayedGenres: [Genre] {
        switch networkMonitor.contentLoadingStrategy {
        case .online:
            return filterGenres(musicLibraryManager.genres)
        case .offlineOnly:
            return filterGenres(offlineManager.offlineGenres)
        }
    }
    
    private var currentState: ViewState? {
        if appConfig.isInitializingServices {
            return .loading("Setting up your music library")
        } else if musicLibraryManager.isLoading && displayedGenres.isEmpty {
            return .loading("Loading genres")
        } else if displayedGenres.isEmpty && musicLibraryManager.hasLoadedInitialData {
            return .empty(type: .genres)
        }
        return nil
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                DynamicMusicBackground()

                // UNIFIED: Single component handles all states
                if let state = currentState {
                    UnifiedStateView(
                        state: state,
                        primaryAction: StateAction("Refresh") {
                            Task { await refreshAllData() }
                        }
                    )
                } else {
                    contentView
                }
            }
            .navigationTitle("Genres")
            .navigationBarTitleDisplayMode(.automatic)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .searchable(text: $searchText, prompt: "Search genres...")
            .refreshable {
                guard networkMonitor.contentLoadingStrategy.shouldLoadOnlineContent else { return }
                await refreshAllData()
            }
            .onChange(of: searchText) { _, _ in
                handleSearchTextChange()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.primary)
                    }
                }
            }
            .navigationDestination(for: Genre.self) { genre in
                AlbumCollectionView(context: .byGenre(genre))
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DSLayout.elementGap) {
                // Show offline banner when using offline content
                if case .offlineOnly(let reason) = networkMonitor.contentLoadingStrategy {
                    OfflineReasonBanner(reason: reason)
                        .padding(.horizontal, DSLayout.screenPadding)
                }
                
                LazyVStack(spacing: DSLayout.elementGap) {
                    ForEach(displayedGenres.indices, id: \.self) { index in
                        let genre = displayedGenres[index]
                        
                        NavigationLink(value: genre) {
                            GenreRowView(genre: genre, index: index)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, DSLayout.miniPlayerHeight)
            }
        }
        .padding(.horizontal, DSLayout.screenPadding)
    }
    
    // MARK: - Business Logic
    
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

    private func refreshAllData() async {
        await musicLibraryManager.refreshAllData()
    }
    
    private func handleSearchTextChange() {
        debouncer.debounce {
            // Search filtering happens automatically via computed property
        }
    }
}

// MARK: - Genre Row View

struct GenreRowView: View {
    let genre: Genre
    let index: Int
    
    var body: some View {
        HStack(spacing: DSLayout.contentGap) {
            // Genre Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                genreColor.opacity(0.3),
                                genreColor.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: DSLayout.smallAvatar, height: DSLayout.smallAvatar)
                    .overlay(
                        Circle()
                            .stroke(genreColor.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: genreColor.opacity(0.1), radius: 4, x: 0, y: 2)
                
                Image(systemName: "music.note.list")
                    .font(.system(size: DSLayout.icon))
                    .foregroundStyle(genreColor)
            }
            .padding(.leading, DSLayout.elementGap)
            
            // Genre Info
            VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                Text(genre.value)
                    .font(DSText.emphasized)
                    .foregroundStyle(DSColor.primary)
                    .lineLimit(1)
                
                HStack(spacing: DSLayout.elementGap) {
                    HStack(spacing: DSLayout.tightGap) {
                        Image(systemName: "record.circle")
                            .font(DSText.metadata)
                            .foregroundStyle(DSColor.secondary)
                        
                        Text("\(genre.albumCount) Album\(genre.albumCount != 1 ? "s" : "")")
                            .font(DSText.metadata)
                            .foregroundStyle(DSColor.secondary)
                    }
                    
                    if genre.songCount > 0 {
                        HStack(spacing: DSLayout.tightGap) {
                            Text("•")
                                .font(DSText.metadata)
                                .foregroundStyle(DSColor.secondary)
                            
                            Image(systemName: "music.note")
                                .font(DSText.metadata)
                                .foregroundStyle(DSColor.secondary)
                            
                            Text("\(genre.songCount) Song\(genre.songCount != 1 ? "s" : "")")
                                .font(DSText.metadata)
                                .foregroundStyle(DSColor.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(DSText.metadata.weight(.semibold))
                .foregroundStyle(DSColor.tertiary)
                .padding(.trailing, DSLayout.elementGap)
        }
        .padding(.vertical, DSLayout.elementPadding)
        .background(
            RoundedRectangle(cornerRadius: DSCorners.element)
                .fill(DSMaterial.background)
                .overlay(
                    RoundedRectangle(cornerRadius: DSCorners.element)
                        .stroke(DSColor.quaternary.opacity(0.3), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // Generate consistent color based on genre name
    private var genreColor: Color {
        let colors: [Color] = [
            DSColor.accent, .blue, .green, .orange, .purple, .pink, .red, .yellow, .cyan, .mint
        ]
        let hash = abs(genre.value.hashValue)
        return colors[hash % colors.count]
    }
}

