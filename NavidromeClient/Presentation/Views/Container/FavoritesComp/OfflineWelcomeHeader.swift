//
//  OfflineWelcomeHeader.swift
//  NavidromeClient
//
//  Created by Boris Eder on 21.09.25.
//
import SwiftUI

struct OfflineWelcomeHeader: View {
    let downloadedAlbums: Int
    let isConnected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.elementGap) {
            HStack {
                VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                    Text("Offline Music")
                        .font(DSText.sectionTitle)
                        .foregroundColor(DSColor.primary)
                    
                    Text(statusText)
                        .font(DSText.body)
                        .foregroundColor(DSColor.secondary)
                }
                
                Spacer()
                
                VStack(spacing: DSLayout.tightGap) {
                    Image(systemName: isConnected ? "wifi" : "wifi.slash")
                        .font(DSText.sectionTitle)
                        .foregroundColor(isConnected ? DSColor.success : DSColor.warning)
                    
                    Text(isConnected ? "Online" : "Offline")
                        .font(DSText.body)
                        .foregroundColor(isConnected ? DSColor.success : DSColor.warning)
                }
            }
        }
    }
    
    private var statusText: String {
        if downloadedAlbums == 0 {
            return "No downloaded music available"
        } else {
            return "\(downloadedAlbums) album\(downloadedAlbums != 1 ? "s" : "") available"
        }
    }
}
