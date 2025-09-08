import SwiftUI

/// MusicBackgroundView zeigt einen verschwommenen Hintergrund.
/// - artist: optional, wenn ein bestimmter Artist für ArtistDetailView gesetzt wird.
/// - genre: optional, falls du später Genres unterstützen willst.
struct MusicBackgroundView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel

    let artist: Artist?
    let genre: Genre?
    let album: Album? // NEU

    @State private var coverImage: UIImage?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // 1️⃣ Fallback immer rendern → verhindert Layout-Zerschuss
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.systemGray6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                if let cover = coverImage {
                    Image(uiImage: cover)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .blur(radius: 50)
                        .opacity(0.5)
                        .ignoresSafeArea()
                } else {
                    LinearGradient(
                        colors: [Color(.systemBackground), Color(.systemGray6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                }
            }
            // Ladecover nur, wenn sich relevante Daten ändern
            .task(id: navidromeVM.artists) { await loadCover() }
            .onAppear { Task { await loadCover() } }
        }}

    @MainActor
    private func loadCover() async {
 

        
        // AlbumDetailView: direkt das Album-Cover
        if let album = album,
           let image = await navidromeVM.loadCoverArt(for: album.id) {
            coverImage = image
            return
        }

        // ArtistDetailView: bestimmter Artist → zufälliges Album
        if let artist = artist {
            await loadRandomAlbum(for: artist)
            return
        }
        
        // NEU: Falls keine Artists geladen sind, lade sie zuerst
        if navidromeVM.artists.isEmpty {
            print("🎨 Loading artists first...")
            await navidromeVM.loadArtists()
        }

        // ArtistView / GenreView: zufälliger Artist → Cover des Artists
        guard !navidromeVM.artists.isEmpty,
              let randomArtist = navidromeVM.artists.randomElement(),
              let coverId = randomArtist.coverArt,
              let image = await navidromeVM.loadCoverArt(for: coverId) else { return }
        coverImage = image
    }

    @MainActor
    private func loadRandomAlbum(for artist: Artist) async {
        do {
            let albums = try await navidromeVM.loadAlbums(context: .artist(artist))
            guard !albums.isEmpty,
                  let randomAlbum = albums.randomElement(),
                  let image = await navidromeVM.loadCoverArt(for: randomAlbum.id) else { return }
            coverImage = image
        } catch {
            print("Fehler beim Laden der Alben für Artist \(artist.name): \(error)")
        }
    }
}
