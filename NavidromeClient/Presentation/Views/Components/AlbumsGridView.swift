import SwiftUI

// MARK: - Reusable Album Grid View
struct AlbumGridView: View {
    let albums: [Album]
    
    // ALLE zu @EnvironmentObject geändert
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    
    var body: some View {
        ScrollView {
            albumsGrid
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
        }
    }
    
    private var albumsGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 2)
        
        return LazyVGrid(columns: columns, spacing: 20) {
            ForEach(albums, id: \.id) { album in
                NavigationLink {
                    AlbumDetailView(album: album)
                } label: {
                    AlbumCard(album: album, accentColor: .black)
                }
            }
        }
    }
}
