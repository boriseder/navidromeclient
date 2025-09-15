//
//  ArtistDetailViewModel.swift - Complete Implementation with Offline Support
//

import Foundation
import SwiftUI

@MainActor
class ArtistDetailViewModel: ObservableObject {
    @Published var albums: [Album] = []
    @Published var albumCovers: [String: UIImage] = [:]
    @Published var artistImage: UIImage?
    @Published var isLoading = false
    @Published var isLoadingSongs = false
    
    // ✅ FIX: Make coverArtService accessible
    private(set) var coverArtService: ReactiveCoverArtService?
    
    func title(for context: ArtistDetailContext) -> String {
        switch context {
        case .artist(let artist): return artist.name
        case .genre(let genre): return genre.value
        }
    }
    
    // ✅ FIX: Updated loadContent method signature
    func loadContent(
        context: ArtistDetailContext,
        navidromeVM: NavidromeViewModel,
        coverArtService: ReactiveCoverArtService,
        isOfflineMode: Bool,
        offlineManager: OfflineManager
    ) async {
        self.coverArtService = coverArtService
        
        isLoading = true
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.loadAlbums(
                    context: context,
                    navidromeVM: navidromeVM,
                    isOfflineMode: isOfflineMode,
                    offlineManager: offlineManager
                )
            }
            group.addTask {
                await self.loadArtistImage(context: context, coverArtService: coverArtService)
            }
        }
        
        isLoading = false
    }
    
    // ✅ FIX: Make loadArtistImage accessible
    func loadArtistImage(context: ArtistDetailContext, coverArtService: ReactiveCoverArtService) async {
        if case .artist(let artist) = context,
           let coverId = artist.coverArt {
            
            let image = await coverArtService.loadImage(for: coverId, size: 300)
            artistImage = image
        }
    }
    
    // ✅ FIX: Updated loadAlbums method
    func loadAlbums(
        context: ArtistDetailContext,
        navidromeVM: NavidromeViewModel,
        isOfflineMode: Bool,
        offlineManager: OfflineManager
    ) async {
        if isOfflineMode {
            // Load from offline manager
            switch context {
            case .artist(let artist):
                albums = offlineManager.getOfflineAlbums(for: artist)
            case .genre(let genre):
                albums = offlineManager.getOfflineAlbums(for: genre)
            }
        } else {
            // Load from online service with offline fallback
            do {
                let onlineAlbums = try await navidromeVM.loadAlbums(context: context)
                albums = onlineAlbums
            } catch {
                print("⚠️ Online album loading failed, falling back to offline")
                // Fallback to offline
                switch context {
                case .artist(let artist):
                    albums = offlineManager.getOfflineAlbums(for: artist)
                case .genre(let genre):
                    albums = offlineManager.getOfflineAlbums(for: genre)
                }
            }
        }
    }
    
    // ✅ FIX: Updated loadAlbumCover method
    func loadAlbumCover(for album: Album, navidromeVM: NavidromeViewModel) async {
        guard albumCovers[album.id] == nil else { return }
        
        guard let coverArtService = coverArtService else { return }
        let cover = await coverArtService.loadAlbumCover(album, size: 200)
        
        if let cover = cover {
            self.albumCovers[album.id] = cover
        }
    }
    
    // Original loadContent method for compatibility
    func loadContent(context: ArtistDetailContext, navidromeVM: NavidromeViewModel, coverArtService: ReactiveCoverArtService) async {
        await loadContent(
            context: context,
            navidromeVM: navidromeVM,
            coverArtService: coverArtService,
            isOfflineMode: false,
            offlineManager: OfflineManager.shared
        )
    }
}
