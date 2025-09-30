//
//  ArtistsViewContent.swift - UPDATED: Unified State System
//  NavidromeClient
//
//   UNIFIED: Single ContentLoadingStrategy for consistent state
//   CLEAN: Simplified toolbar and state management
//   FIXED: Proper refresh method names and error handling
//

import SwiftUI

struct ArtistsViewContent: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var coverArtManager: CoverArtManager
    @EnvironmentObject var musicLibraryManager: MusicLibraryManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var downloadManager: DownloadManager
    
    @State private var searchText = ""
    @StateObject private var debouncer = Debouncer()
    
    // MARK: - UNIFIED: Single State Logic
    
    private var displayedArtists: [Artist] {
        switch networkMonitor.contentLoadingStrategy {
        case .online:
            return filterArtists(musicLibraryManager.artists)
        case .offlineOnly:
            return filterArtists(offlineManager.offlineArtists)
        }
    }
    
    private var currentState: ViewState? {
        if appConfig.isInitializingServices {
            return .loading("Setting up your music library")
        } else if musicLibraryManager.isLoading && displayedArtists.isEmpty {
            return .loading("Loading artists")
        } else if displayedArtists.isEmpty && musicLibraryManager.hasLoadedInitialData {
            return .empty(type: .artists)
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
            .navigationTitle("Artists")
            .navigationBarTitleDisplayMode(.automatic)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .searchable(text: $searchText, prompt: "Search artists...")
            .refreshable {
                guard networkMonitor.contentLoadingStrategy.shouldLoadOnlineContent else { return }
                await refreshAllData()
            }
            .onChange(of: searchText) { _, _ in
                handleSearchTextChange()
            }
            // Background idle preloading instead of immediate
            .task(priority: .background) {
                if !displayedArtists.isEmpty {
                    coverArtManager.preloadArtistsWhenIdle(Array(displayedArtists.prefix(20)), size: 120)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "person.crop.circle.fill")
                    }
                }
            }
            .navigationDestination(for: Artist.self) { artist in
                AlbumCollectionView(context: .byArtist(artist))
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
                    ForEach(displayedArtists.indices, id: \.self) { index in
                        let artist = displayedArtists[index]
                        
                        NavigationLink(value: artist) {
                            ArtistRowView(artist: artist, index: index)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, DSLayout.miniPlayerHeight)
            }
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, DSLayout.screenPadding)
    }
    
    // MARK: - Business Logic
    
    private func filterArtists(_ artists: [Artist]) -> [Artist] {
        let filteredArtists: [Artist]
        
        if searchText.isEmpty {
            filteredArtists = artists
        } else {
            filteredArtists = artists.filter { artist in
                artist.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filteredArtists.sorted(by: { $0.name < $1.name })
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

// MARK: - Artist Row View

struct ArtistRowView: View {
    let artist: Artist
    let index: Int
    
    @EnvironmentObject var coverArtManager: CoverArtManager
    
    var body: some View {
        HStack(spacing: DSLayout.contentGap) {
            // Artist Image
            ArtistImageView(artist: artist, index: index, size: DSLayout.smallAvatar)
                .padding(.leading, DSLayout.elementGap)
            
            // Artist Info
            VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                Text(artist.name)
                    .font(DSText.emphasized)
                    .foregroundStyle(DSColor.primary)
                    .lineLimit(1)
                
                HStack(spacing: DSLayout.elementGap) {
                    HStack(spacing: DSLayout.tightGap) {
                        Image(systemName: "music.mic")
                            .font(DSText.metadata)
                            .foregroundStyle(DSColor.secondary)
                        
                        if let count = artist.albumCount {
                            Text("\(count) Album\(count != 1 ? "s" : "")")
                                .font(DSText.metadata)
                                .foregroundStyle(DSColor.secondary)
                        } else {
                            Text("Artist")
                                .font(DSText.metadata)
                                .foregroundStyle(DSColor.secondary)
                        }
                    }
                    
                    // Show offline indicator if available offline
                    if isAvailableOffline {
                        HStack(spacing: DSLayout.tightGap) {
                            Text("•")
                                .font(DSText.metadata)
                                .foregroundStyle(DSColor.secondary)
                            
                            Image(systemName: "arrow.down.circle.fill")
                                .font(DSText.metadata)
                                .foregroundStyle(DSColor.success)
                            
                            Text("Downloaded")
                                .font(DSText.metadata)
                                .foregroundStyle(DSColor.success)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Album count badge
            if let albumCount = artist.albumCount, albumCount > 0 {
                Text("\(albumCount)")
                    .font(DSText.metadata.weight(.semibold))
                    .foregroundStyle(DSColor.accent)
                    .padding(.horizontal, DSLayout.elementPadding)
                    .padding(.vertical, DSLayout.tightPadding)
                    .background(
                        Capsule()
                            .fill(DSColor.accent.opacity(0.1))
                            .overlay(
                                Capsule()
                                    .stroke(DSColor.accent.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
            
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
    
    private var isAvailableOffline: Bool {
        OfflineManager.shared.isArtistAvailableOffline(artist.name)
    }
}
