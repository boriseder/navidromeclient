import SwiftUI

struct AlbumDetailViewContent: View {
    let album: Album
    @State private var scrollOffset: CGFloat = 0

    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var coverArtManager: CoverArtManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    
    @State private var songs: [Song] = []
    @State private var isOfflineAlbum = false
        
    private var currentState: ViewState? {
        if songs.isEmpty {
            return .empty(type: .songs)
        }
        return nil
    }

    var body: some View {
        ZStack {
            DynamicMusicBackground()
            
            ScrollView {
                VStack(spacing: DSLayout.screenGap) {
                    AlbumHeaderView(
                        album: album,
                        songs: songs,
                        isOfflineAlbum: isOfflineAlbum
                    )
                    
                    if !networkMonitor.shouldLoadOnlineContent || isOfflineAlbum {
                        HStack {
                            if downloadManager.isAlbumDownloaded(album.id) {
                                OfflineStatusBadge(album: album)
                            } else {
                                NetworkStatusIndicator(showText: true)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, DSLayout.screenPadding)
                    }
                    
                    // UNIFIED: Single component handles empty state
                    if let state = currentState {
                        UnifiedStateView(
                            state: state,
                            primaryAction: StateAction("Refresh") {
                                Task {
                                    await loadAlbumData()
                                }
                            }
                        )
                        .padding(.horizontal, DSLayout.screenPadding)
                    } else {
                        AlbumSongsListView(
                            songs: songs,
                            album: album
                        )
                    }
                }
                .padding(.bottom, DSLayout.miniPlayerHeight + DSLayout.contentGap)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadAlbumData()
            }
        }
    }
    
    @MainActor
    private func loadAlbumData() async {
        isOfflineAlbum = !networkMonitor.shouldLoadOnlineContent
        songs = await navidromeVM.loadSongs(for: album.id)
    }
}
