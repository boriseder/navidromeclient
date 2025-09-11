import SwiftUI

// MARK: - Simplified Status Header (ohne Sort-Button)
struct AlbumsStatusHeader: View {
    let isOnline: Bool
    let isOfflineMode: Bool
    let albumCount: Int
    let onOfflineToggle: () -> Void
    
    var body: some View {
        HStack {
            // Network Status
            HStack(spacing: 6) {
                Image(systemName: isOnline ? "wifi" : "wifi.slash")
                    .foregroundStyle(isOnline ? .green : .red)
                    .font(.caption)
                
                Text(isOnline ? "Online" : "Offline")
                    .font(.caption)
                    .foregroundStyle(isOnline ? .green : .red)
            }
            
            Spacer()
            
            // Album Count
            Text("\(albumCount) Albums")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            // Offline Mode Toggle (nur wenn online)
            if isOnline {
                Button(action: onOfflineToggle) {
                    HStack(spacing: 4) {
                        Image(systemName: isOfflineMode ? "icloud.slash" : "icloud")
                            .font(.caption)
                        Text(isOfflineMode ? "Offline" : "All")
                            .font(.caption)
                    }
                    .foregroundStyle(isOfflineMode ? .orange : .blue)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
