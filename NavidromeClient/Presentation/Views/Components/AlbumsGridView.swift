//
//  AlbumGridView.swift - Enhanced with Design System
//  NavidromeClient
//
//  ✅ ENHANCED: Vollständige Anwendung des Design Systems
//

import SwiftUI

// MARK: - Reusable Album Grid View (Enhanced with DS)
struct AlbumGridView: View {
    let albums: [Album]
    
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    
    var body: some View {
        ScrollView {
            albumsGrid
                .screenPadding()
                .padding(.bottom, 100) // Approx. DS applied - könnte Sizes.miniPlayer + Padding.s sein
        }
    }
    
    private var albumsGrid: some View {
        LazyVGrid(columns: GridColumns.two, spacing: Spacing.l) {
            ForEach(albums, id: \.id) { album in
                NavigationLink {
                    AlbumDetailView(album: album)
                } label: {
                    AlbumCard(album: album, accentColor: .primary)
                }
            }
        }
    }
}
