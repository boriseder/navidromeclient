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
    @EnvironmentObject var theme: ThemeManager

    @State private var searchText = ""
    @StateObject private var debouncer = Debouncer()
    
    // MARK: - UNIFIED: Single State Logic
    
    private var displayedArtists: [Artist] {
        let artists: [Artist]
        
        switch networkMonitor.contentLoadingStrategy {
        case .online:
            artists = filterArtists(musicLibraryManager.artists)
        case .offlineOnly:
            artists = filterArtists(offlineManager.offlineArtists)
        case .setupRequired:
            artists = []
        }
        
        return artists
    }
    

    var body: some View {
        NavigationStack {
            ZStack {
                
                if theme.backgroundStyle == .dynamic {
                    DynamicMusicBackground()
                }
                
                contentView
            }
            .navigationTitle("Artists")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Artist.self) { artist in
                AlbumCollectionView(context: .byArtist(artist))
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarColorScheme(
                theme.colorScheme,
                for: .navigationBar
            )
            .searchable(text: $searchText, prompt: "Search artists...")
            .refreshable {
                guard networkMonitor.contentLoadingStrategy.shouldLoadOnlineContent else { return }
                await refreshAllData()
            }
            .onChange(of: searchText) { _, _ in
                handleSearchTextChange()
            }
            // Background idle preloading instead of immediate
            .onAppear {
                if !displayedArtists.isEmpty {
                    coverArtManager.preloadArtistsWhenIdle(Array(displayedArtists.prefix(20)), context: .artistList)
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

        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DSLayout.elementGap) {
                
                LazyVStack(spacing: 2) {
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
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        HStack(spacing: DSLayout.elementGap) {
            // Artist Image
            ArtistImageView(artist: artist, index: index, context: .artistList)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(.black.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                .padding(.vertical, DSLayout.tightPadding)
                .padding(.leading, DSLayout.tightPadding)
            
            Text(artist.name)
                .font(DSText.emphasized)
                .foregroundStyle(DSColor.onDark)
                .lineLimit(1)
        
            Spacer()
            
            if let count = artist.albumCount {
                
                // Show offline indicator if available offline
                if isAvailableOffline {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(DSText.fine)
                        .foregroundStyle(DSColor.onDark)
                } else {
                    Image(systemName: "record.circle")
                        .font(DSText.fine)
                        .foregroundStyle(DSColor.onDark)
                }
                
                Text("\(count) Album\(count != 1 ? "s" : "")")
                    .font(DSText.fine)
                    .foregroundStyle(DSColor.onDark)
                    .padding(.trailing, DSLayout.contentPadding)
            }
        }
        .background(theme.backgroundContrastColor.opacity(0.12)
)
    }
    
    private var isAvailableOffline: Bool {
        OfflineManager.shared.isArtistAvailableOffline(artist.name)
    }
}
