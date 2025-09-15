//
//  ArtistsView.swift - FIXED (DRY)
//  NavidromeClient
//
//  ✅ FIXED: Removed ArtistsStatusHeader reference
//  ✅ USES: LibraryStatusHeader.artists() instead
//

import SwiftUI

struct ArtistsView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var coverArtService: ReactiveCoverArtService
    
    @State private var searchText = ""
      
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
                } else if filteredArtists.isEmpty {
                    ArtistsEmptyStateView(
                        isOnline: networkMonitor.canLoadOnlineContent,
                        isOfflineMode: offlineManager.isOfflineMode
                    )
                } else {
                    mainContent
                }
            }
            .navigationTitle("Artists")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $searchText, placement: .automatic, prompt: "Search artists...")
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
            .refreshable {
                await navidromeVM.refreshAllData()
            }
            .navigationDestination(for: Artist.self) { artist in
                ArtistDetailView(context: .artist(artist))
            }
            .accountToolbar()
        }
    }

    // Rest of the existing code remains the same...
    private var filteredArtists: [Artist] {
        let artists: [Artist]
        
        if networkMonitor.canLoadOnlineContent && !offlineManager.isOfflineMode {
            artists = navidromeVM.artists
        } else {
            artists = offlineManager.offlineArtists
        }
        
        if searchText.isEmpty {
            return artists.sorted(by: { $0.name < $1.name })
        } else {
            return artists
                .filter { $0.name.localizedCaseInsensitiveContains(searchText) }
                .sorted(by: { $0.name < $1.name })
        }
    }

    private var mainContent: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.s) {
                if !networkMonitor.canLoadOnlineContent || offlineManager.isOfflineMode {
                    LibraryStatusHeader.artists(
                        count: filteredArtists.count,
                        isOnline: networkMonitor.canLoadOnlineContent,
                        isOfflineMode: offlineManager.isOfflineMode
                    )
                }
                
                ForEach(filteredArtists.indices, id: \.self) { index in
                    let artist = filteredArtists[index]
                    NavigationLink(value: artist) {
                        ArtistCard(artist: artist, index: index)
                    }
                }
            }
            .screenPadding()
            .padding(.bottom, Sizes.miniPlayer)
        }
    }
}
