//
//  ArtistDetailViewModel.swift - FIXED VERSION
//  NavidromeClient
//
//  ✅ FIXES:
//  - Removed bypass call to navidromeVM.loadCoverArt()
//  - Now uses ReactiveCoverArtService.loadImage() async method
//  - Fixed @Published property access from async context
//  - Fixed dictionary literal syntax
//

import Foundation
import SwiftUI

@MainActor
class ArtistDetailViewModel: ObservableObject {
    @Published var albums: [Album] = []
    @Published var albumCovers: [String: UIImage] = [:] // ✅ FIX: Correct empty dict syntax
    @Published var artistImage: UIImage?
    @Published var isLoading = false
    @Published var isLoadingSongs = false
    
    // ✅ FIX: Add reference to ReactiveCoverArtService
    private weak var coverArtService: ReactiveCoverArtService?
    
    func title(for context: ArtistDetailContext) -> String {
        switch context {
        case .artist(let artist): return artist.name
        case .genre(let genre): return genre.value
        }
    }
    
    // ✅ FIX: Enhanced loadContent method
    func loadContent(context: ArtistDetailContext, navidromeVM: NavidromeViewModel, coverArtService: ReactiveCoverArtService) async {
        self.coverArtService = coverArtService // Store reference
        
        isLoading = true
        
        // Führe Tasks parallel aus
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadAlbums(context: context, navidromeVM: navidromeVM) }
            group.addTask { await self.loadArtistImage(context: context, coverArtService: coverArtService) }
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
    
    // ✅ FIX: Updated loadArtistImage method
    private func loadArtistImage(context: ArtistDetailContext, coverArtService: ReactiveCoverArtService) async {
        if case .artist(let artist) = context,
           let coverId = artist.coverArt {
            
            // OLD BYPASS CODE (removed):
            // let image = await navidromeVM.loadCoverArt(for: coverId)
            
            // ✅ NEW: Use ReactiveCoverArtService async API
            let image = await coverArtService.loadImage(for: coverId, size: 300)
            artistImage = image
        }
    }
    
    // ✅ FIX: Updated loadAlbumCover method with proper MainActor handling
    func loadAlbumCover(for album: Album, navidromeVM: NavidromeViewModel) async {
        guard albumCovers[album.id] == nil else { return }
        
        // OLD BYPASS CODE (removed):
        // let cover = await navidromeVM.loadCoverArt(for: album.id)
        
        // ✅ NEW: Use ReactiveCoverArtService async API
        guard let coverArtService = coverArtService else { return }
        let cover = await coverArtService.loadAlbumCover(album, size: 200)
        
        // ✅ FIX: Since we're already @MainActor, direct assignment should work
        if let cover = cover {
            self.albumCovers[album.id] = cover
        }
    }
}
