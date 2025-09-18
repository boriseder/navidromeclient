//
//  UnifiedContainer.swift - FIXED: All Compiler Errors
//  NavidromeClient
//
//  ✅ FIXED: Equatable protocol conformance
//  ✅ FIXED: Generic type constraints
//  ✅ FIXED: Album initializer parameters
//

import SwiftUI

// MARK: - ✅ FIXED: UnifiedContainer Implementation

struct UnifiedContainer<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let layout: ContainerLayout
    let spacing: CGFloat
    let onItemTap: (Item) -> Void
    let onLoadMore: ((Item) -> Void)?
    let itemBuilder: (Item, Int) -> Content
    
    init(
        items: [Item],
        layout: ContainerLayout = .list,
        spacing: CGFloat = DSLayout.elementGap,
        onItemTap: @escaping (Item) -> Void = { _ in },
        onLoadMore: ((Item) -> Void)? = nil,
        @ViewBuilder itemBuilder: @escaping (Item, Int) -> Content
    ) {
        self.items = items
        self.layout = layout
        self.spacing = spacing
        self.onItemTap = onItemTap
        self.onLoadMore = onLoadMore
        self.itemBuilder = itemBuilder
    }
    
    var body: some View {
        Group {
            switch layout {
            case .list:
                listLayout
            case .grid(let columns):
                gridLayout(columns: columns)
            case .horizontal:
                horizontalLayout
            }
        }
        .screenPadding()
    }
    
    // MARK: - Layout Implementations
    
    @ViewBuilder
    private var listLayout: some View {
        LazyVStack(spacing: spacing) {
            itemsWithLoadMore()
        }
    }
    
    @ViewBuilder
    private func gridLayout(columns: [GridItem]) -> some View {
        LazyVGrid(columns: columns, spacing: spacing) {
            itemsWithLoadMore()
        }
    }
    
    @ViewBuilder
    private var horizontalLayout: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: spacing) {
                itemsWithoutLoadMore()
            }
            .padding(.horizontal, DSLayout.screenPadding)
        }
    }
    
    // MARK: - Item Builders
    
    @ViewBuilder
    private func itemsWithLoadMore() -> some View {
        ForEach(items.indices, id: \.self) { index in
            let item = items[index]
            
            Button(action: { onItemTap(item) }) {
                itemBuilder(item, index)
            }
            .buttonStyle(.plain)
            .onAppear {
                triggerLoadMoreIfNeeded(at: index, for: item)
            }
        }
    }
    
    @ViewBuilder
    private func itemsWithoutLoadMore() -> some View {
        ForEach(items.indices, id: \.self) { index in
            let item = items[index]
            
            Button(action: { onItemTap(item) }) {
                itemBuilder(item, index)
            }
            .buttonStyle(.plain)
        }
    }
    
    private func triggerLoadMoreIfNeeded(at index: Int, for item: Item) {
        guard let onLoadMore = onLoadMore else { return }
        
        let triggerIndex = max(0, items.count - 5)
        if index >= triggerIndex {
            print("🔄 UnifiedContainer: Triggering load more at index \(index)/\(items.count)")
            onLoadMore(item)
        }
    }
}

// MARK: - ✅ FIXED: Layout Configuration with Equatable

enum ContainerLayout: Equatable {
    case list
    case grid([GridItem])
    case horizontal
    
    // ✅ FIXED: Equatable implementation for GridItem arrays
    static func == (lhs: ContainerLayout, rhs: ContainerLayout) -> Bool {
        switch (lhs, rhs) {
        case (.list, .list), (.horizontal, .horizontal):
            return true
        case (.grid(let lhsItems), .grid(let rhsItems)):
            return lhsItems.count == rhsItems.count
        default:
            return false
        }
    }
    
    // Convenience constructors
    static let twoColumnGrid = ContainerLayout.grid(GridColumns.two)
    static let threeColumnGrid = ContainerLayout.grid(GridColumns.three)
    static let fourColumnGrid = ContainerLayout.grid(GridColumns.four)
}

// MARK: - ✅ REMOVED: Problematic Static Extensions

// Note: Removed static extensions that caused generic type issues
// Use direct UnifiedContainer initialization instead

// MARK: - ✅ FIXED: Migration Helpers as View Extensions

extension View {
    
    // ✅ Helper for migrating from GridContainer
    func migrateFromGridContainer<Item: Identifiable, Content: View>(
        items: [Item],
        columns: [GridItem] = GridColumns.two,
        spacing: CGFloat = DSLayout.sectionGap,
        onLoadMore: ((Item) -> Void)? = nil,
        @ViewBuilder itemBuilder: @escaping (Item, Int) -> Content
    ) -> some View {
        UnifiedContainer(
            items: items,
            layout: .grid(columns),
            spacing: spacing,
            onLoadMore: onLoadMore,
            itemBuilder: itemBuilder
        )
    }
    
    // ✅ Helper for migrating from ListContainer
    func migrateFromListContainer<Item: Identifiable, Content: View>(
        items: [Item],
        spacing: CGFloat = DSLayout.elementGap,
        onLoadMore: ((Item) -> Void)? = nil,
        @ViewBuilder itemBuilder: @escaping (Item, Int) -> Content
    ) -> some View {
        UnifiedContainer(
            items: items,
            layout: .list,
            spacing: spacing,
            onLoadMore: onLoadMore,
            itemBuilder: itemBuilder
        )
    }
}

// MARK: - ✅ FIXED: Preview Code (Removed problematic Album inits)

#if DEBUG
struct UnifiedContainer_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // List Layout
            UnifiedContainer(
                items: sampleItems,
                layout: .list
            ) { item, index in
                Text(item.name)
                    .padding()
            }
            .previewDisplayName("List Layout")
            
            // Grid Layout
            UnifiedContainer(
                items: sampleItems,
                layout: .twoColumnGrid
            ) { item, index in
                Text(item.name)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .previewDisplayName("Grid Layout")
            
            // Horizontal Layout
            UnifiedContainer(
                items: sampleItems,
                layout: .horizontal
            ) { item, index in
                Text(item.name)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(8)
            }
            .previewDisplayName("Horizontal Layout")
        }
    }
    
    // ✅ FIXED: Simple test data structure
    struct TestItem: Identifiable {
        let id = UUID()
        let name: String
    }
    
    static let sampleItems = [
        TestItem(name: "Item 1"),
        TestItem(name: "Item 2"),
        TestItem(name: "Item 3"),
        TestItem(name: "Item 4")
    ]
}
#endif

// MARK: - ✅ USAGE EXAMPLES (Corrected)

/*
KORREKTE MIGRATION:

// ✅ ALT (AlbumsView):
GridContainer(
    items: displayedAlbums,
    onItemTap: { _ in },
    onLoadMore: { _ in Task { await loadMore() } }
) { album, index in
    NavigationLink { AlbumDetailView(album: album) } label: {
        CardItemContainer(content: .album(album), index: index)
    }
}

// ✅ NEU (AlbumsView):
UnifiedContainer(
    items: displayedAlbums,
    layout: .twoColumnGrid,
    onLoadMore: { _ in Task { await loadMore() } }
) { album, index in
    NavigationLink { AlbumDetailView(album: album) } label: {
        CardItemContainer(content: .album(album), index: index)
    }
}

// ✅ ALT (ArtistsView):
ListContainer(
    items: displayedArtists,
    onItemTap: { _ in }
) { artist, index in
    NavigationLink(value: artist) {
        ListItemContainer(content: .artist(artist), index: index)
    }
}

// ✅ NEU (ArtistsView):
UnifiedContainer(
    items: displayedArtists,
    layout: .list
) { artist, index in
    NavigationLink(value: artist) {
        ListItemContainer(content: .artist(artist), index: index)
    }
}
*/
