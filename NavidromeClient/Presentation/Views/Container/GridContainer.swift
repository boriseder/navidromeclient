//
//  GridContainer.swift
//  NavidromeClient
//
//  Created by Boris Eder on 18.09.25.
//
import SwiftUI

// MARK: - 3. Grid Container (FIXED: Load More Logic)
struct GridContainer<Item>: View where Item: Identifiable {
    let items: [Item]
    let columns: [GridItem]
    let spacing: CGFloat
    let onItemTap: (Item) -> Void
    let onLoadMore: ((Item) -> Void)?
    let itemBuilder: (Item, Int) -> AnyView
    
    init(
        items: [Item],
        columns: [GridItem] = GridColumns.two,
        spacing: CGFloat = DSLayout.sectionGap,
        onItemTap: @escaping (Item) -> Void,
        onLoadMore: ((Item) -> Void)? = nil,
        @ViewBuilder itemBuilder: @escaping (Item, Int) -> some View
    ) {
        self.items = items
        self.columns = columns
        self.spacing = spacing
        self.onItemTap = onItemTap
        self.onLoadMore = onLoadMore
        self.itemBuilder = { item, index in AnyView(itemBuilder(item, index)) }
    }
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]
                
                Button(action: { onItemTap(item) }) {
                    itemBuilder(item, index)
                }
                .buttonStyle(PlainButtonStyle())
                .onAppear {
                    // ✅ CRITICAL FIX: Load more when reaching near the end
                    let triggerIndex = max(0, items.count - 5)
                    if index >= triggerIndex && onLoadMore != nil {
                        print("🔄 GridContainer: Triggering load more at index \(index)/\(items.count)")
                        onLoadMore?(item)
                    }
                }
            }
        }
        .screenPadding()
    }
}
