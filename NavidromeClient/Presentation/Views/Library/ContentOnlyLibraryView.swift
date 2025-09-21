//
//  ContentOnlyLibraryView.swift
//  NavidromeClient
//
//  Created by Boris Eder on 21.09.25.
//
import SwiftUI

struct ContentOnlyLibraryView<Content: View>: View {
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
