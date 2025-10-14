import SwiftUI

struct AlbumDetailViewContent: View {
    let album: Album

    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var songManager: SongManager
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
                    Group {
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
                    }.padding(.top, DSLayout.largeGap * 3)
                }
                .padding(.bottom, DSLayout.miniPlayerHeight + DSLayout.contentGap)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadAlbumData()
            }
            .onReceive(NotificationCenter.default.publisher(for: .downloadCompleted)) { notification in
                if let albumId = notification.object as? String, albumId == album.id {
                    Task {
                        await loadAlbumData()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .downloadDeleted)) { notification in
                if let albumId = notification.object as? String, albumId == album.id {
                    Task {
                        await loadAlbumData()
                    }
                }
            }
        }
    }
    
    @MainActor
    private func loadAlbumData() async {
        let isNetworkOffline = !networkMonitor.shouldLoadOnlineContent
        let isDownloaded = downloadManager.isAlbumDownloaded(album.id)
        
        isOfflineAlbum = isNetworkOffline || isDownloaded
        
        songs = await songManager.loadSongs(for: album.id)
    }
}

