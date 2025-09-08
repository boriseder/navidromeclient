/*

import SwiftUI

struct RandomArtistBackgroundView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @State private var coverImage: UIImage?

    var body: some View {
        AlbumBackgroundView(cover: coverImage)
            .onChange(of: navidromeVM.artists) { _ in
                Task {
                    await loadRandomArtistCover()
                }
            }
    }

    private func loadRandomArtistCover() async {
        // Warten bis Artists geladen sind
        guard !navidromeVM.artists.isEmpty else { return }

        // Zufälligen Artist wählen
        let artist = navidromeVM.artists.randomElement()!

        // Cover des Artists laden, falls vorhanden
        if let coverId = artist.coverArt {
            if let image = await navidromeVM.loadCoverArt(for: coverId) {
                coverImage = image
            }
        }
        guard let coverId = artist.coverArt else {
            print("Artist \(artist.name) hat kein Cover")
            return
        }
    }
}


*/
