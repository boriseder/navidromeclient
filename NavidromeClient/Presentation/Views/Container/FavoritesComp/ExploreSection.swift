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
                 
                 if showRefreshButton, let refreshAction = refreshAction {
                     Button {
                         Task {
                             isRefreshing = true
                             await refreshAction()
                             isRefreshing = false
                         }
                     } label: {
                         Image(systemName: "arrow.clockwise")
                             .font(DSText.sectionTitle)
                             .foregroundColor(accentColor)
                             .rotationEffect(isRefreshing ? .degrees(360) : .degrees(0))
                             .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                     }
                     .disabled(isRefreshing)
                 }
             }
             .screenPadding()
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
         .frame(height: 250) // feste Höhe für die Reihe
     }
}

