//
//  CleanContainerArchitecture.swift
//  NavidromeClient
//
//  ✅ CLEAN: Proper separation of concerns
//  ✅ SUSTAINABLE: Each component has single responsibility
//

import SwiftUI

// MARK: - 0. ✅ REQUIRED: Extensions
extension View {
    @ViewBuilder
    func conditionalSearchable(searchText: Binding<String>?, prompt: String?) -> some View {
        if let searchText = searchText {
            self.searchable(
                text: searchText,
                placement: .automatic,
                prompt: prompt ?? "Search..."
            )
        } else {
            self
        }
    }
    
    @ViewBuilder
    func conditionalToolbar(_ config: ToolbarConfiguration?) -> some View {
        if let config = config {
            self.unifiedToolbar(config)
        } else {
            self
        }
    }
}

// MARK: - 1. ✅ FIXED: ContentContainer (NO Navigation)
struct ContentContainer<Content: View>: View {
    let isLoading: Bool
    let isEmpty: Bool
    let isOfflineMode: Bool
    let emptyStateType: EmptyStateView.EmptyStateType
    let content: () -> Content
    
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
                        
                        content()
                    }
                    .padding(.bottom, DSLayout.miniPlayerHeight)
                }
            }
        }
    }
}

// MARK: - 2. ✅ FIXED: NavigationContainer (Navigation + Toolbar)
struct NavigationContainer<Content: View>: View {
    let title: String
    let displayMode: NavigationBarItem.TitleDisplayMode
    let onRefresh: (() async -> Void)?
    let searchText: Binding<String>?
    let searchPrompt: String?
    let toolbarConfig: ToolbarConfiguration?
    let content: () -> Content
    
    init(
        title: String,
        displayMode: NavigationBarItem.TitleDisplayMode = .large,
        onRefresh: (() async -> Void)? = nil,
        searchText: Binding<String>? = nil,
        searchPrompt: String? = nil,
        toolbarConfig: ToolbarConfiguration? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.displayMode = displayMode
        self.onRefresh = onRefresh
        self.searchText = searchText
        self.searchPrompt = searchPrompt
        self.toolbarConfig = toolbarConfig
        self.content = content
    }
    
    var body: some View {
        NavigationStack {
            content()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(displayMode)
                .conditionalSearchable(searchText: searchText, prompt: searchPrompt)
                .refreshable {
                    await onRefresh?()
                }
                .conditionalToolbar(toolbarConfig)
        }
    }
}

// MARK: - 3. ✅ CLEAN: LibraryView Composition
struct LibraryView<Content: View>: View {
    let title: String
    let isLoading: Bool
    let isEmpty: Bool
    let isOfflineMode: Bool
    let emptyStateType: EmptyStateView.EmptyStateType
    let onRefresh: (() async -> Void)?
    let searchText: Binding<String>?
    let searchPrompt: String?
    let toolbarConfig: ToolbarConfiguration?
    let content: () -> Content
    
    var body: some View {
        NavigationContainer(
            title: title,
            onRefresh: onRefresh,
            searchText: searchText,
            searchPrompt: searchPrompt,
            toolbarConfig: toolbarConfig
        ) {
            ContentContainer(
                isLoading: isLoading,
                isEmpty: isEmpty,
                isOfflineMode: isOfflineMode,
                emptyStateType: emptyStateType,
                content: content
            )
        }
    }
}

// MARK: - 4. ✅ CLEAN: AlbumsView Implementation
/*
// In AlbumsView.swift - CLEAN IMPLEMENTATION:

var body: some View {
    LibraryView(
        title: "Albums",
        isLoading: shouldShowLoading,
        isEmpty: isEmpty && !shouldShowLoading,
        isOfflineMode: isOfflineMode,
        emptyStateType: .albums,
        onRefresh: { await refreshAllData() },
        searchText: $searchText,
        searchPrompt: "Search albums...",
        toolbarConfig: .libraryWithSort(
            title: "Albums",
            isOffline: isOfflineMode,
            currentSort: selectedAlbumSort,
            sortOptions: ContentService.AlbumSortType.allCases,
            onRefresh: { await refreshAllData() },
            onToggleOffline: { toggleOfflineMode() },
            onSort: { sortType in
                Task { await loadAlbums(sortBy: sortType) }
            }
        )
    ) {
        AlbumsGridContent()
    }
    .onChange(of: searchText) { _, _ in
        handleSearchTextChange()
    }
    .task(id: displayedAlbums.count) {
        await preloadAlbumImages()
    }
}
*/

// MARK: - 5. ✅ ARCHITECTURE BENEFITS

/*
✅ SINGLE RESPONSIBILITY:
- ContentContainer: Nur Loading/Empty/Content States
- NavigationContainer: Nur Navigation/Toolbar/Search
- LibraryView: Composition der beiden

✅ REUSABLE:
- ContentContainer für Non-Navigation Views
- NavigationContainer für andere Navigation Patterns
- LibraryView für alle Library-ähnlichen Views

✅ TESTABLE:
- Jede Komponente isoliert testbar
- Keine versteckten Dependencies

✅ MAINTAINABLE:
- Änderungen an Navigation = nur NavigationContainer
- Änderungen an Content States = nur ContentContainer
- Toolbar-Logic bleibt in NavigationContainer wo sie hingehört

✅ SCALABLE:
- Neue Container-Types einfach hinzufügbar
- Bestehende Patterns wiederverwendbar
- Keine Breaking Changes für bestehende Views
*/
