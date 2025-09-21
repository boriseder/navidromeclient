//
//  UnifiedLibraryContainer.swift - KONSOLIDIERT: Alle Container-Patterns
//  NavidromeClient
//
//   KONSOLIDIERT: UnifiedContainer + LibraryContainer in einer Komponente
//   CLEAN: Single Source of Truth für alle Container-Patterns
//   SUSTAINABLE: Reduzierte Komplexität ohne neue Abhängigkeiten
//

import SwiftUI

// MARK: - Unified Library Container (Konsolidiert)

struct UnifiedLibraryContainer<Item: Identifiable, Content: View>: View {
    // Data & State
    let items: [Item]
    let isLoading: Bool
    let isEmpty: Bool
    let isOfflineMode: Bool
    let emptyStateType: EmptyStateView.EmptyStateType
    
    // Layout
    let layout: ContainerLayout
    let spacing: CGFloat
    let onLoadMore: ((Item) -> Void)?
    
    // Interaction
    let onItemTap: (Item) -> Void
    let itemBuilder: (Item, Int) -> Content
    
    init(
        items: [Item],
        isLoading: Bool = false,
        isEmpty: Bool? = nil,
        isOfflineMode: Bool = false,
        emptyStateType: EmptyStateView.EmptyStateType,
        layout: ContainerLayout = .list,
        spacing: CGFloat = DSLayout.elementGap,
        onItemTap: @escaping (Item) -> Void = { _ in },
        onLoadMore: ((Item) -> Void)? = nil,
        @ViewBuilder itemBuilder: @escaping (Item, Int) -> Content
    ) {
        self.items = items
        self.isLoading = isLoading
        self.isEmpty = isEmpty ?? items.isEmpty
        self.isOfflineMode = isOfflineMode
        self.emptyStateType = emptyStateType
        self.layout = layout
        self.spacing = spacing
        self.onItemTap = onItemTap
        self.onLoadMore = onLoadMore
        self.itemBuilder = itemBuilder
    }
    
    var body: some View {
        Group {
            if isLoading {
                LoadingView()
            } else if isEmpty {
                EmptyStateView(type: emptyStateType)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if isOfflineMode {
                            OfflineStatusBanner()
                                .screenPadding()
                                .padding(.bottom, DSLayout.elementGap)
                        }
                        
                        layoutContent
                    }
                    .padding(.bottom, DSLayout.miniPlayerHeight)
                }
            }
        }
    }
    
    @ViewBuilder
    private var layoutContent: some View {
        switch layout {
        case .list:
            listLayout
        case .grid(let columns):
            gridLayout(columns: columns)
        case .horizontal:
            horizontalLayout
        }
    }
    
    // MARK: - Layout Implementations
    
    @ViewBuilder
    private var listLayout: some View {
        LazyVStack(spacing: spacing) {
            itemsWithLoadMore()
        }
        .screenPadding()
    }
    
    @ViewBuilder
    private func gridLayout(columns: [GridItem]) -> some View {
        LazyVGrid(columns: columns, spacing: spacing) {
            itemsWithLoadMore()
        }
        .screenPadding()
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
            print("🔄 UnifiedLibraryContainer: Triggering load more at index \(index)/\(items.count)")
            onLoadMore(item)
        }
    }
}

// MARK: - Layout Configuration (from UnifiedContainer)

enum ContainerLayout: Equatable {
    case list
    case grid([GridItem])
    case horizontal
    
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

// MARK: - Convenience Extensions

extension View {
    
    /// Content-only version (for views within NavigationStack)
    func unifiedLibraryContent<Item: Identifiable, Content: View>(
        items: [Item],
        isLoading: Bool = false,
        isEmpty: Bool? = nil,
        isOfflineMode: Bool = false,
        emptyStateType: EmptyStateView.EmptyStateType,
        layout: ContainerLayout = .list,
        spacing: CGFloat = DSLayout.elementGap,
        onLoadMore: ((Item) -> Void)? = nil,
        @ViewBuilder itemBuilder: @escaping (Item, Int) -> Content
    ) -> some View where Content: View {
        
        UnifiedLibraryContainer(
            items: items,
            isLoading: isLoading,
            isEmpty: isEmpty,
            isOfflineMode: isOfflineMode,
            emptyStateType: emptyStateType,
            layout: layout,
            spacing: spacing,
            onLoadMore: onLoadMore,
            itemBuilder: itemBuilder
        )
    }
}
