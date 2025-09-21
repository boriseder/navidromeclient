//
//  LibraryContainer.swift - FIXED: Navigation-free Container Architecture
//  NavidromeClient
//
//   FIXED: Entfernt NavigationContainer für Single NavigationStack
//   CLEAN: Proper separation of concerns
//   SUSTAINABLE: Each component has single responsibility
//

import SwiftUI

// MARK: - 0. REQUIRED: Extensions
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

// MARK: - 1. CONTENT-ONLY Container (NO Navigation)
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

// MARK: - 3. ✅ UPDATED: LibraryView (Navigation-free for single NavigationStack)
struct LibraryView<Content: View>: View {
    let isLoading: Bool
    let isEmpty: Bool
    let isOfflineMode: Bool
    let emptyStateType: EmptyStateView.EmptyStateType
    let content: () -> Content
    
    // ✅ SIMPLIFIED: Nur noch Content-relevante Parameter
    init(
        isLoading: Bool,
        isEmpty: Bool,
        isOfflineMode: Bool,
        emptyStateType: EmptyStateView.EmptyStateType,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isLoading = isLoading
        self.isEmpty = isEmpty
        self.isOfflineMode = isOfflineMode
        self.emptyStateType = emptyStateType
        self.content = content
    }
    
    var body: some View {
        // ✅ FIXED: Kein NavigationStack mehr - nutzt äußeren NavigationStack
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

// MARK: - 4. ✅ ENHANCED: StandaloneLibraryView (for modal presentations)
struct StandaloneLibraryView<Content: View>: View {
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
    
    init(
        title: String,
        isLoading: Bool,
        isEmpty: Bool,
        isOfflineMode: Bool,
        emptyStateType: EmptyStateView.EmptyStateType,
        onRefresh: (() async -> Void)? = nil,
        searchText: Binding<String>? = nil,
        searchPrompt: String? = nil,
        toolbarConfig: ToolbarConfiguration? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.isLoading = isLoading
        self.isEmpty = isEmpty
        self.isOfflineMode = isOfflineMode
        self.emptyStateType = emptyStateType
        self.onRefresh = onRefresh
        self.searchText = searchText
        self.searchPrompt = searchPrompt
        self.toolbarConfig = toolbarConfig
        self.content = content
    }
    
    var body: some View {
        // ✅ STANDALONE: Für Sheets/Modal presentations die eigenen NavigationStack brauchen
        NavigationStack {
            ContentContainer(
                isLoading: isLoading,
                isEmpty: isEmpty,
                isOfflineMode: isOfflineMode,
                emptyStateType: emptyStateType,
                content: content
            )
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
            .conditionalSearchable(searchText: searchText, prompt: searchPrompt)
            .refreshable {
                await onRefresh?()
            }
            .conditionalToolbar(toolbarConfig)
        }
    }
}

// MARK: - 5. ✅ MIGRATION: Helper Extensions
extension View {
    
    /// ✅ NEW: For views within MainTabView (no NavigationStack)
    func libraryView(
        isLoading: Bool,
        isEmpty: Bool,
        isOfflineMode: Bool,
        emptyStateType: EmptyStateView.EmptyStateType
    ) -> some View {
        LibraryView(
            isLoading: isLoading,
            isEmpty: isEmpty,
            isOfflineMode: isOfflineMode,
            emptyStateType: emptyStateType
        ) {
            self
        }
    }
    
    /// ✅ FOR: Modal presentations that need their own NavigationStack
    func standaloneLibrary(
        title: String,
        isLoading: Bool,
        isEmpty: Bool,
        isOfflineMode: Bool,
        emptyStateType: EmptyStateView.EmptyStateType,
        onRefresh: (() async -> Void)? = nil,
        searchText: Binding<String>? = nil,
        searchPrompt: String? = nil,
        toolbarConfig: ToolbarConfiguration? = nil
    ) -> some View {
        StandaloneLibraryView(
            title: title,
            isLoading: isLoading,
            isEmpty: isEmpty,
            isOfflineMode: isOfflineMode,
            emptyStateType: emptyStateType,
            onRefresh: onRefresh,
            searchText: searchText,
            searchPrompt: searchPrompt,
            toolbarConfig: toolbarConfig
        ) {
            self
        }
    }
}

