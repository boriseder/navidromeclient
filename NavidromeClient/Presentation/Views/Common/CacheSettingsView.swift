import SwiftUI

struct CacheSettingsView: View {
    // ALLE zu @EnvironmentObject geändert
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    
    @State private var cacheStats = PersistentImageCache.CacheStats(
        memoryCount: 0, diskCount: 0, diskSize: 0, maxSize: 0
    )
    @State private var showingClearConfirmation = false
    @State private var showingClearSuccess = false
    
    var body: some View {
        List {
            Section("Cover Art Cache") {
                VStack(spacing: 12) {
                    CacheStatsRow(
                        title: "Cached Images",
                        value: "\(cacheStats.diskCount)",
                        icon: "photo.stack"
                    )
                    
                    CacheStatsRow(
                        title: "Cache Size",
                        value: cacheStats.diskSizeFormatted,
                        icon: "internaldrive"
                    )
                    
                    CacheStatsRow(
                        title: "Usage",
                        value: String(format: "%.1f%%", cacheStats.usagePercentage),
                        icon: "chart.pie"
                    )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Storage Usage")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(cacheStats.maxSizeFormatted)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        ProgressView(value: cacheStats.usagePercentage, total: 100)
                            .progressViewStyle(LinearProgressViewStyle(tint: progressColor))
                    }
                }
                .padding(.vertical, 8)
                
                Button(role: .destructive) {
                    showingClearConfirmation = true
                } label: {
                    Label("Clear Cover Art Cache", systemImage: "trash")
                }
            }
            
            Section("Download Cache") {
                HStack {
                    Text("Downloaded Music")
                    Spacer()
                    Text(downloadManager.totalDownloadSize())
                        .foregroundStyle(.secondary)
                }
                
                Button(role: .destructive) {
                    downloadManager.deleteAllDownloads()
                } label: {
                    Label("Delete All Downloads", systemImage: "trash")
                }
            }
            
            Section("Advanced") {
                Button {
                    Task {
                        await PersistentImageCache.shared.performMaintenanceCleanup()
                        updateCacheStats()
                    }
                } label: {
                    Label("Optimize Cache", systemImage: "gearshape.2")
                }
                
                Button {
                    Task {
                        await preloadCurrentAlbums()
                        updateCacheStats()
                    }
                } label: {
                    Label("Preload Current Albums", systemImage: "square.and.arrow.down")
                }
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cache automatically manages storage and removes old images when space is needed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("• Images expire after 30 days")
                    Text("• Maximum cache size: 100 MB")
                    Text("• Automatic cleanup on app start")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Cache Management")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            updateCacheStats()
        }
        .refreshable {
            updateCacheStats()
        }
        .confirmationDialog(
            "Clear Cover Art Cache?",
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear Cache", role: .destructive) {
                clearCoverArtCache()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove all cached cover art images.")
        }
        .alert("Cache Cleared", isPresented: $showingClearSuccess) {
            Button("OK") { }
        } message: {
            Text("Cover art cache has been successfully cleared.")
        }
    }
    
    private var progressColor: Color {
        switch cacheStats.usagePercentage {
        case 0..<60: return .green
        case 60..<80: return .yellow
        default: return .red
        }
    }
    
    private func updateCacheStats() {
        cacheStats = PersistentImageCache.shared.getCacheStats()
    }
    
    private func clearCoverArtCache() {
        PersistentImageCache.shared.clearCache()
        updateCacheStats()
        showingClearSuccess = true
    }
    
    private func preloadCurrentAlbums() async {
        guard let service = navidromeVM.getService() else { return }
        await service.preloadCoverArt(for: navidromeVM.albums, size: 200)
    }
}

// MARK: - Cache Stats Row
struct CacheStatsRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 20)
            
            Text(title)
                .foregroundStyle(.primary)
            
            Spacer()
            
            Text(value)
                .foregroundStyle(.secondary)
                .fontWeight(.medium)
        }
    }
}
