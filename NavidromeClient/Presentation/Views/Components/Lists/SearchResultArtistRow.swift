//
//  SearchResultArtistRow.swift
//  NavidromeClient
//
//  Created by Boris Eder on 21.09.25.
//

import SwiftUI

struct SearchResultArtistRow: View {
    let artist: Artist
    let index: Int // For staggered loading
    
    //  UPDATED: Uses CoverArtManager instead of ReactiveCoverArtService
    @EnvironmentObject var coverArtManager: CoverArtManager
    
    var body: some View {
        NavigationLink(destination: AlbumCollectionView(context: .artist(artist))) {
            HStack(spacing: DSLayout.contentGap) {
                ArtistImageView(artist: artist, index: index)
                ArtistInfoView(artist: artist)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(DSText.metadata.weight(.semibold))
                    .foregroundStyle(DSColor.tertiary)
            }
            .listItemPadding()
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}

extension SearchResultArtistRow {
    /// Convenience initializer without index for simple usage
    init(artist: Artist) {
        self.artist = artist
        self.index = 0
    }
}
