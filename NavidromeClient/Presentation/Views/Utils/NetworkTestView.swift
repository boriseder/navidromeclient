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
        VStack(spacing: DSLayout.sectionGap) {
            Text("Network Testing")
                .font(DSText.sectionTitle)
            
            HStack {
                Circle()
                    .fill(networkMonitor.isConnected ? DSColor.success : DSColor.error)
                    .frame(width: DSLayout.largeIcon, height: DSLayout.largeIcon)
                
                Text(networkMonitor.isConnected ? "Online" : "Offline")
                    .font(DSText.prominent)
            }
            
            Text("Connection: \(networkMonitor.connectionType)")
                .font(DSText.metadata)
            
            Divider()
            
            VStack {
                Text("Offline Manager")
                    .font(DSText.prominent)
                
                Text("Mode: \(offlineManager.isOfflineMode ? "Offline" : "Online")")
                Text("Offline Albums: \(offlineManager.offlineAlbums.count)")
                
                Button("Toggle Offline Mode") {
                    offlineManager.toggleOfflineMode()
                }
            }
            
            Spacer()
        }
        .padding(DSLayout.screenPadding)
    }
}
#endif
