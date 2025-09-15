//
//  ArtistDetailViewModel.swift - UPDATED for CoverArtManager
//  NavidromeClient
//
//  ✅ UPDATED: Uses unified CoverArtManager instead of ReactiveCoverArtService
//  ✅ SIMPLIFIED: Direct image loading without complex state management
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
    
    // ✅ UPDATED: Uses unified CoverArtManager
    private(set) var coverArtManager: CoverArtManager?
    
    func title(for context: ArtistDetailContext) -> String {
        switch context {
        case .artist(let artist): return artist.name
        case .genre(let genre): return genre.value
        }
    }
    
    // ✅ UPDATED: Simplified method signature with CoverArtManager
    func loadContent(
        context: ArtistDetailContext,
        navidromeVM: NavidromeViewModel,
        coverArtManager: CoverArtManager,
        isOfflineMode: Bool,
        offlineManager: OfflineManager
    ) async {
        self.coverArtManager = coverArtManager
        
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
                await self.loadArtistImage(context: context, coverArtManager: coverArtManager)
            }
        }
        
        isLoading = false
    }
    
    // ✅ UPDATED: Uses CoverArtManager directly
    func loadArtistImage(context: ArtistDetailContext, coverArtManager: CoverArtManager) async {
        if case .artist(let artist) = context {
            // ✅ SINGLE LINE: Clean, unified API
            artistImage = await coverArtManager.loadArtistImage(artist: artist, size: 300)
        }
    }
    
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
    
    // ✅ UPDATED: Uses CoverArtManager directly
    func loadAlbumCover(for album: Album, navidromeVM: NavidromeViewModel) async {
        guard albumCovers[album.id] == nil else { return }
        guard let coverArtManager = coverArtManager else { return }
        
        // ✅ SINGLE LINE: Clean, unified API
        let cover = await coverArtManager.loadAlbumImage(album: album, size: 200)
        
        if let cover = cover {
            self.albumCovers[album.id] = cover
        }
    }
    
    // Legacy compatibility method
    func loadContent(context: ArtistDetailContext, navidromeVM: NavidromeViewModel, coverArtService: CoverArtManager) async {
        await loadContent(
            context: context,
            navidromeVM: navidromeVM,
            coverArtManager: coverArtService,
            isOfflineMode: false,
            offlineManager: OfflineManager.shared
        )
    }
}
