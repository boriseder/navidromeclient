//
//  NetworkTestView.swift
//  NavidromeClient
//
//  Created by Boris Eder on 14.09.25.
//
import SwiftUI

#if DEBUG
struct NetworkTestView: View {
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var offlineManager = OfflineManager.shared
    
    var body: some View {
        VStack(spacing: Spacing.l) {
            Text("Network Testing")
                .font(Typography.title)
            
            HStack {
                Circle()
                    .fill(networkMonitor.isConnected ? BrandColor.success : BrandColor.error)
                    .frame(width: Sizes.iconLarge, height: Sizes.iconLarge)
                
                Text(networkMonitor.isConnected ? "Online" : "Offline")
                    .font(Typography.headline)
            }
            
            Text("Connection: \(networkMonitor.connectionType)")
                .font(Typography.caption)
            
            Divider()
            
            VStack {
                Text("Offline Manager")
                    .font(Typography.headline)
                
                Text("Mode: \(offlineManager.isOfflineMode ? "Offline" : "Online")")
                Text("Offline Albums: \(offlineManager.offlineAlbums.count)")
                
                Button("Toggle Offline Mode") {
                    offlineManager.toggleOfflineMode()
                }
                .secondaryButtonStyle()
            }
            
            Spacer()
        }
        .padding(Padding.xl)
    }
}
#endif
