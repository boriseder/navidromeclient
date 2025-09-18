//
//  DetailContainer.swift
//  NavidromeClient
//
//  Created by Boris Eder on 18.09.25.
//
/*
import SwiftUI

// MARK: - 2. Detail View Container
struct DetailContainer<Header: View, Content: View>: View {
    let title: String
    let onRefresh: (() async -> Void)?
    let header: () -> Header
    let content: () -> Content
    
    init(
        title: String,
        onRefresh: (() async -> Void)? = nil,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.onRefresh = onRefresh
        self.header = header
        self.content = content
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: DSLayout.screenGap) {
                header()
                    .screenPadding()
                
                content()
            }
            .screenPadding()
            .padding(.bottom, DSLayout.miniPlayerHeight)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await onRefresh?()
        }
        .accountToolbar() // Keep existing toolbar for Phase 1
    }
}
*/
