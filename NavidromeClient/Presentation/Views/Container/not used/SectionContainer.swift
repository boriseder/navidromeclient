//
//  SectionContainer.swift
//  NavidromeClient
//
//  Created by Boris Eder on 18.09.25.
//

/*
import SwiftUI

// MARK: - 5. Section Container (For Home/Explore horizontal scrolls)
struct SectionContainer<Item>: View where Item: Identifiable {
    let title: String
    let icon: String
    let accentColor: Color
    let items: [Item]
    let showRefreshButton: Bool
    let onItemTap: (Item) -> Void
    let onRefresh: (() async -> Void)?
    let itemBuilder: (Item, Int) -> AnyView
    
    @State private var isRefreshing = false
    
    init(
        title: String,
        icon: String,
        accentColor: Color,
        items: [Item],
        showRefreshButton: Bool = false,
        onItemTap: @escaping (Item) -> Void,
        onRefresh: (() async -> Void)? = nil,
        @ViewBuilder itemBuilder: @escaping (Item, Int) -> some View
    ) {
        self.title = title
        self.icon = icon
        self.accentColor = accentColor
        self.items = items
        self.showRefreshButton = showRefreshButton
        self.onItemTap = onItemTap
        self.onRefresh = onRefresh
        self.itemBuilder = { item, index in AnyView(itemBuilder(item, index)) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.contentGap) {
            // Section Header
            HStack {
                Label(title, systemImage: icon)
                    .font(DSText.prominent)
                    .foregroundColor(DSColor.primary)
                
                Spacer()
                
                if showRefreshButton, let onRefresh = onRefresh {
                    Button {
                        Task {
                            isRefreshing = true
                            await onRefresh()
                            isRefreshing = false
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(DSText.sectionTitle)
                            .foregroundColor(accentColor)
                            .rotationEffect(isRefreshing ? .degrees(360) : .degrees(0))
                            .animation(
                                isRefreshing ?
                                .linear(duration: 1).repeatForever(autoreverses: false) :
                                .default,
                                value: isRefreshing
                            )
                    }
                    .disabled(isRefreshing)
                }
            }
            .screenPadding()
            
            // Horizontal Scroll
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: DSLayout.contentGap) {
                    ForEach(items.indices, id: \.self) { index in
                        let item = items[index]
                        
                        Button(action: { onItemTap(item) }) {
                            itemBuilder(item, index)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, DSLayout.screenPadding)
            }
        }
    }
}
*/
