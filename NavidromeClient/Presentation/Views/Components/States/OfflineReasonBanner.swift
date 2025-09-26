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

// Add extensions for UI properties
extension ContentLoadingStrategy.OfflineReason {
    var icon: String {
        switch self {
        case .noNetwork: return "wifi.slash"
        case .serverUnreachable: return "exclamationmark.triangle"
        case .userChoice: return "icloud.slash"
        }
    }
    
    var color: Color {
        switch self {
        case .noNetwork: return DSColor.error
        case .serverUnreachable: return DSColor.warning
        case .userChoice: return DSColor.info
        }
    }
    
    var message: String {
        switch self {
        case .noNetwork: return "No internet connection - showing downloaded content"
        case .serverUnreachable: return "Server unreachable - showing downloaded content"
        case .userChoice: return "Offline mode active - showing downloaded content"
        }
    }
    
    var canGoOnline: Bool {
        switch self {
        case .noNetwork, .serverUnreachable: return false
        case .userChoice: return true
        }
    }
    
    var actionTitle: String {
        switch self {
        case .userChoice: return "Go Online"
        default: return ""
        }
    }
    
    func performAction(offlineManager: OfflineManager) {
        switch self {
        case .userChoice:
            offlineManager.switchToOnlineMode()
        default:
            break
        }
    }
}
