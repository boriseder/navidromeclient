//
//  AlbumSection.swift
//  NavidromeClient
//
//  Created by Boris Eder on 21.09.25.
//

import SwiftUI

struct ExploreSectionMigrated: View {
    let title: String
    let albums: [Album]
    let icon: String
    let accentColor: Color
    var showRefreshButton: Bool = false
    var refreshAction: (() async -> Void)? = nil
    
    @State private var isRefreshing = false
    
    var body: some View {
        VStack {
            // Section Header
            HStack {
                Label(title, systemImage: icon)
                    .font(DSText.prominent)
                    .foregroundColor(DSColor.primary)
                
                Spacer()
                // refresh button...
            }
            .padding(.horizontal, DSLayout.screenPadding)
            
            UnifiedLibraryContainer(
                items: albums,
                isLoading: false,
                isEmpty: false,
                isOfflineMode: false,
                emptyStateType: .albums,
                layout: .horizontal
            ) { album, index in
                NavigationLink(value: album) {
                    CardItemContainer(content: .album(album), index: index)
                }
            }
        }
    }
}
