//
//  OfflineReasonBanner.swift
//  NavidromeClient
//
//  Created by Boris Eder on 26.09.25.
//
import SwiftUI

// New component for consistent offline messaging
struct OfflineReasonBanner: View {
    let reason: ContentLoadingStrategy.OfflineReason
    @EnvironmentObject private var offlineManager: OfflineManager
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    
    var body: some View {
        HStack(spacing: DSLayout.elementGap) {
            Image(systemName: reason.icon)
                .foregroundStyle(reason.color)
            
            Text(reason.message)
                .font(DSText.metadata)
                .foregroundStyle(reason.color)
            
            Spacer()
            
            if reason.canGoOnline {
                Button(reason.actionTitle) {
                    reason.performAction(offlineManager: offlineManager)
                }
                .font(DSText.metadata)
                .foregroundStyle(DSColor.accent)
            }
        }
        .listItemPadding()
        .background(
            reason.color.opacity(0.1),
            in: RoundedRectangle(cornerRadius: DSCorners.element)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSCorners.element)
                .stroke(reason.color.opacity(0.3), lineWidth: 1)
        )
    }
}

