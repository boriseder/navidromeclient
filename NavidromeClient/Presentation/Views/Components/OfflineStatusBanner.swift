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
        HStack(spacing: Spacing.s) {
            Image(systemName: "wifi.slash")
                .foregroundStyle(BrandColor.warning)
            
            Text("Showing downloaded content only")
                .font(Typography.caption)
                .foregroundStyle(BrandColor.warning)
            
            Spacer()
            
            Button("Go Online") {
                offlineManager.switchToOnlineMode()
            }
            .font(Typography.caption)
            .foregroundStyle(BrandColor.primary)
        }
        .listItemPadding()
        .background(
            BrandColor.warning.opacity(0.1),
            in: RoundedRectangle(cornerRadius: Radius.s)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.s)
                .stroke(BrandColor.warning.opacity(0.3), lineWidth: 1)
        )
    }
}
