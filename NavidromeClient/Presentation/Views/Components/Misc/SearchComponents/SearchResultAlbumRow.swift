//
//  SearchResultAlbumRow.swift
//  NavidromeClient
//
//  Created by Boris Eder on 21.09.25.
//
import SwiftUI

struct SearchResultAlbumRow: View {
    let album: Album
    let index: Int // For staggered loading
    
    //  UPDATED: Uses CoverArtManager instead of ReactiveCoverArtService
    @EnvironmentObject var coverArtManager: CoverArtManager
    
    var body: some View {
        NavigationLink(destination: AlbumDetailViewContent(album: album)) {
            HStack(spacing: DSLayout.contentGap) {
                //  REACTIVE: Uses centralized state
                AlbumImageView(album: album, index: index)
                AlbumInfoView(album: album)
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

extension SearchResultAlbumRow {
    /// Convenience initializer without index for simple usage
    init(album: Album) {
        self.album = album
        self.index = 0
    }
}
