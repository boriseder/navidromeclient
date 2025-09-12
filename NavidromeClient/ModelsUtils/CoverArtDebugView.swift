import SwiftUI

struct CoverArtDebugView: View {
    @StateObject private var monitor = CoverArtPerformanceMonitor.shared
    @EnvironmentObject var coverArtService: ReactiveCoverArtService
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Cover Art Performance")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Total Requests:")
                    Spacer()
                    Text("\(monitor.stats.totalRequests)")
                }
                
                HStack {
                    Text("Cache Hits:")
                    Spacer()
                    Text("\(monitor.stats.cacheHits)")
                }
                
                HStack {
                    Text("Cache Hit Rate:")
                    Spacer()
                    Text(String(format: "%.1f%%", monitor.stats.cacheHitRate))
                        .foregroundColor(monitor.stats.cacheHitRate > 80 ? .green : .orange)
                }
                
                HStack {
                    Text("Duplicate Requests:")
                    Spacer()
                    Text("\(monitor.stats.duplicateRequests)")
                        .foregroundColor(monitor.stats.duplicateRequests > 5 ? .red : .green)
                }
                
                let cacheStats = coverArtService.getCacheStats()
                HStack {
                    Text("Memory Cache:")
                    Spacer()
                    Text("\(cacheStats.memory) images")
                }
                
                HStack {
                    Text("Disk Cache:")
                    Spacer()
                    Text("\(cacheStats.persistent) images")
                }
            }
            
            Button("Reset Stats") {
                monitor.reset()
            }
            .buttonStyle(.bordered)
            
            Button("Clear Memory Cache") {
                coverArtService.clearMemoryCache()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding()
    }
}
