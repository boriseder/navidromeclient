//
//  UnifiedContainers.swift - Complete Container System
//  NavidromeClient
//
//  ✅ PHASE 1: Foundation for all view containers
//  ✅ SUSTAINABLE: Built on existing architecture
//  ✅ BACKWARD COMPATIBLE: Uses existing components
//

import SwiftUI

// MARK: - 1. Library View Container (Primary Use Case)
struct LibraryContainer<Content: View>: View {
    let title: String
    let isLoading: Bool
    let isEmpty: Bool
    let isOfflineMode: Bool
    let onRefresh: (() async -> Void)?
    let emptyStateType: EmptyStateView.EmptyStateType
    let searchText: Binding<String>?
    let searchPrompt: String?
    let content: () -> Content
    
    // Simplified initializer for most cases
    init(
        title: String,
        isLoading: Bool,
        isEmpty: Bool,
        isOfflineMode: Bool = false,
        onRefresh: (() async -> Void)? = nil,
        emptyStateType: EmptyStateView.EmptyStateType,
        searchText: Binding<String>? = nil,
        searchPrompt: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.isLoading = isLoading
        self.isEmpty = isEmpty
        self.isOfflineMode = isOfflineMode
        self.onRefresh = onRefresh
        self.emptyStateType = emptyStateType
        self.searchText = searchText
        self.searchPrompt = searchPrompt
        self.content = content
    }
    
    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.large)
                .conditionalSearchable(searchText: searchText, prompt: searchPrompt)
                .refreshable {
                    await onRefresh?()
                }
                .accountToolbar() // Keep existing toolbar for Phase 1
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
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





