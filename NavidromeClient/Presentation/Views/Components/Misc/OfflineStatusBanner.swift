//
//  OfflineStatusBanner.swift
//  NavidromeClient
//
//  Created by Boris Eder on 17.09.25.
//
import SwiftUI

struct OfflineStatusBanner: View {
    @EnvironmentObject private var offlineManager: OfflineManager
    
    var body: some View {
        HStack(spacing: DSLayout.elementGap) {
            Image(systemName: "wifi.slash")
                .foregroundStyle(DSColor.warning)
            
            Text("Showing downloaded content only")
                .font(DSText.metadata)
                .foregroundStyle(DSColor.warning)
            
            Spacer()
            
            Button("Go Online") {
                offlineManager.switchToOnlineMode()
            }
            .font(DSText.metadata)
            .foregroundStyle(DSColor.accent)
        }
        .background(
            DSColor.warning.opacity(0.1),
            in: RoundedRectangle(cornerRadius: DSCorners.element)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSCorners.element)
                .stroke(DSColor.warning.opacity(0.3), lineWidth: 1)
        )
    }
}
