import Foundation
import SwiftUI

@MainActor
class ArtistDetailViewModel: ObservableObject {
    @Published var albums: [Album] = []
    @Published var albumCovers: [String: UIImage] = [:]
    @Published var artistImage: UIImage?
    @Published var isLoading = false
    @Published var isLoadingSongs = false
    
    func title(for context: ArtistDetailContext) -> String {
        switch context {
        case .artist(let artist): return artist.name
        case .genre(let genre): return genre.value
        }
    }
    
    func loadContent(context: ArtistDetailContext, navidromeVM: NavidromeViewModel) async {
        isLoading = true
        
        // Führe Tasks parallel aus
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadAlbums(context: context, navidromeVM: navidromeVM) }
            group.addTask { await self.loadArtistImage(context: context, navidromeVM: navidromeVM) }
        }
        
        isLoading = false
    }
    
    private func loadAlbums(context: ArtistDetailContext, navidromeVM: NavidromeViewModel) async {
        do {
            let loadedAlbums = try await navidromeVM.loadAlbums(context: context)
            albums = loadedAlbums
        } catch {
            albums = []
        }
    }
    
    private func loadArtistImage(context: ArtistDetailContext, navidromeVM: NavidromeViewModel) async {
        if case .artist(let artist) = context,
           let coverId = artist.coverArt {
            let image = await navidromeVM.loadCoverArt(for: coverId)
            artistImage = image
        }
    }
    
    func loadAlbumCover(for album: Album, navidromeVM: NavidromeViewModel) async {
        guard albumCovers[album.id] == nil else { return }
        
        let cover = await navidromeVM.loadCoverArt(for: album.id)
        albumCovers[album.id] = cover
    }
}
