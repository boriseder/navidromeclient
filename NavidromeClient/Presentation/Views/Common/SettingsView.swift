//
//  SettingsView.swift - CLEANED: Pure Service Architecture
//  NavidromeClient
//
//   ELIMINATED: All legacy service patterns and direct service extraction
//   CLEAN: Routes through ViewModels and AppConfig only
//   REMOVED: All problematic dynamic members and missing components
//

import SwiftUI

// MARK: - SettingsView
struct SettingsView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var songManager: SongManager
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var coverArtManager: CoverArtManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @Environment(\.dismiss) private var dismiss

    @State private var showingFactoryResetConfirmation = false
    @State private var isPerformingReset = false

    var body: some View {
        NavigationStack {
            List {
                GeneralSettingsSection
                NavidromeSection
                if appConfig.isConfigured {
                    CacheSection
                    ServerDetailsSection
                    DangerZoneSection
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(appConfig.isConfigured ? "Settings" : "Initial Setup")
            .toolbarColorScheme(.light, for: .navigationBar) // helle Icons/Titel
            .toolbarBackground(.visible, for: .navigationBar)
            .disabled(isPerformingReset)
            .overlay { if isPerformingReset { FactoryResetOverlayView() } }
            .confirmationDialog(
                "Logout & Factory Reset",
                isPresented: $showingFactoryResetConfirmation
            ) {
                Button("Reset App", role: .destructive) {
                    Task { await performFactoryReset() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete ALL data including downloads, server settings and cache.")
            }
        }
    }

    // MARK: - Sections

    private var NavidromeSection: some View {
        Section {
            if let creds = AppConfig.shared.getCredentials() {
                SettingsRow(title: "Server:", value: creds.baseURL.absoluteString)
                SettingsRow(title: "User:", value: creds.username)
            }
            NavigationLink(destination: ServerEditView()) {
                Text("Edit Server")
            }
        } header: {
            Text("Navidrome Server Settings")
        } footer: {
            Text("Your (self-)hosted Navidrome server. Don't forget to add port (usually 4533).")
        }
        .task { await navidromeVM.testConnection() }
    }

    private var CacheSection: some View {
        Section {
            NavigationLink("Cache Settings") { CacheSettingsView() }
            SettingsRow(title: "Cover Art Cache", value: PersistentImageCache.shared.getCacheStats().diskSizeFormatted)
            SettingsRow(title: "Download Cache", value: downloadManager.totalDownloadSize())
        } header: {
            Text("Cache & Downloads")
        }
    }

    private var GeneralSettingsSection: some View {
        Group {
            Section(header: Text("Debug")) {
                NavigationLink(destination: CoverArtDebugView()) {
                    Label("Cover Art Debug", systemImage: "photo.artframe")
                }
                
                NavigationLink(destination: NetworkTestView()) {
                    Label("Network Test", systemImage: "network")
                }
            }
            Section(header: Text("Appearance")) {
                // Theme Picker
                Picker("Select Theme", selection: $appConfig.userBackgroundStyle) {
                    ForEach(UserBackgroundStyle.allCases, id: \.self) { option in
                        Text(option.rawValue.capitalized)
                            .tag(option)
                    }
                }
                .pickerStyle(.menu)
                
                // AccentColor Picke
                HStack {
                    Text("Accent Color")
                    Spacer()
                    Menu {
                        ForEach(UserAccentColor.allCases) { colorOption in
                            Button {
                                appConfig.userAccentColor = colorOption
                            } label: {
                                Label(colorOption.rawValue.capitalized,
                                      systemImage: "circle.fill")
                                if appConfig.userAccentColor == colorOption {
                                    Image(systemName: "checkmark")
                                }
                            }
                            .tint(colorOption.color)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "circle.fill")
                                .foregroundStyle(appConfig.userAccentColor.color)
                            Text(appConfig.userAccentColor.rawValue.capitalized)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

            }
                
            
        }
    }
    
    private var ServerDetailsSection: some View {
        Section {
            SettingsRow(title: "Status:", value: navidromeVM.connectionStatus ? "Connected" : "Disconnected")
            SettingsRow(title: "Network:", value: networkMonitor.connectionStatusDescription)
            if networkMonitor.canLoadOnlineContent {
                SettingsRow(title: "Quality Description:", value: navidromeVM.connectionQualityDescription)
                SettingsRow(title: "Response Time:", value: navidromeVM.connectionResponseTime)
                SettingsRow(title: "Server Health:", value: navidromeVM.connectionQualityDescription)
            }
        } header: {
            Text("Server Info")
        }
        .task { await navidromeVM.testConnection() }
    }

    private var DangerZoneSection: some View {
        Section {
            Button(role: .destructive) {
                showingFactoryResetConfirmation = true
            } label: {
                Label("Logout & Factory Reset", systemImage: "exclamationmark.triangle.fill")
            }
            .disabled(isPerformingReset)
        } header: {
            Text("Danger Zone")
        } footer: {
            Text("This will reset the app to its initial state. All local data will be lost.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions
    private func performFactoryReset() async {
        isPerformingReset = true
        defer { isPerformingReset = false }
        
        await appConfig.performFactoryReset()
        
        // FIXED: Direct service reset instead of notification
        await MainActor.run {
            // Reset ViewModels directly
            navidromeVM.reset()
            songManager.reset()
        }
        
        await MainActor.run { dismiss() }
    }
}

// MARK: - Helper Components

struct SettingsRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Factory Reset

struct FactoryResetOverlayView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.5).tint(.white)
                Text("Factory Reset in Progress...").foregroundStyle(.white)
                Text("Clearing all data and resetting app").foregroundStyle(.white.opacity(0.8))
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - CacheSettingsView - CLEANED
struct CacheSettingsView: View {
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var coverArtManager: CoverArtManager

    @State private var cacheStats = PersistentImageCache.shared.getCacheStats()
    @State private var showingClearConfirmation = false
    @State private var showingClearSuccess = false

    var body: some View {
        List {
            Section("Cover Art Cache") {
                CacheStatsRow(title: "Cached Images", value: "\(cacheStats.diskCount)", icon: "photo.stack")
                CacheStatsRow(title: "Cache Size", value: cacheStats.diskSizeFormatted, icon: "internaldrive")
                CacheStatsRow(title: "Usage", value: String(format: "%.1f%%", cacheStats.usagePercentage), icon: "chart.pie")

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
                    Label("Delete ALL Music", systemImage: "trash")
                }
            }
            
            Section("Performance") {
                let coverStats = coverArtManager.getCacheStats()
                CacheStatsRow(title: "Memory Images", value: "\(coverStats.memoryCount)", icon: "memorychip")
                CacheStatsRow(title: "Active Requests", value: "\(coverStats.activeRequests)", icon: "arrow.down.circle")
                
                Button("Clear Memory Cache") {
                    coverArtManager.clearMemoryCache()
                    updateCacheStats()
                }
            }
        }
        .navigationTitle("Cache Management")
        .confirmationDialog("Clear Cover Art Cache?", isPresented: $showingClearConfirmation) {
            Button("Clear Cache", role: .destructive) { clearCoverArtCache() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all cached cover art images.")
        }
        .alert("Cache Cleared", isPresented: $showingClearSuccess) {
            Button("OK") {}
        } message: {
            Text("Cover art cache has been successfully cleared.")
        }
        .task { updateCacheStats() }
        .refreshable { updateCacheStats() }
    }

    private func updateCacheStats() {
        cacheStats = PersistentImageCache.shared.getCacheStats()
    }
    
    private func clearCoverArtCache() {
        PersistentImageCache.shared.clearCache()
        coverArtManager.clearMemoryCache()
        updateCacheStats()
        showingClearSuccess = true
    }
}

struct CacheStatsRow: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon).frame(width: 20)
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}
