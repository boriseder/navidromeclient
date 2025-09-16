//
//  CoverArtDebugView.swift
//  NavidromeClient
//
//  Created by Boris Eder on 16.09.25.
//
import SwiftUI

struct CoverArtDebugView: View {
    @EnvironmentObject var coverArtManager: CoverArtManager
    
    var body: some View {
        let stats = coverArtManager.getCacheStats()
        let health = coverArtManager.getHealthStatus()
        
        VStack(spacing: 16) {
            Text("Cover Art Performance")
                .font(.headline)
            
            // ✅ FIXED: Use correct property names
            VStack(alignment: .leading, spacing: 8) {
                Text("Health: \(health.statusDescription)")
                    .foregroundColor(health.isHealthy ? .green : .orange)
                
                Text("Cache Hit Rate: \(String(format: "%.1f", stats.performanceStats.cacheHitRate))%")
                Text("Average Load Time: \(String(format: "%.3f", stats.performanceStats.averageLoadTime))s")
                Text("Memory Images: \(stats.totalMemoryImages)")
                Text("Active Requests: \(stats.activeRequests)")
                Text("Errors: \(stats.errorCount)")
            }
            
            HStack {
                Button("Reset Stats") {
                    coverArtManager.resetPerformanceStats()
                }
                
                Button("Clear Cache") {
                    coverArtManager.clearMemoryCache()
                }
                
                Button("Print Diagnostics") {
                    coverArtManager.printDiagnostics()
                }
            }
        }
        .padding()
    }
}
