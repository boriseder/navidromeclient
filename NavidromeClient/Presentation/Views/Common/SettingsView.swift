//
//  SettingsView.swift - CLEANED VERSION
//  NavidromeClient
//
//  ✅ REMOVED: All logout logic moved to AppConfig
//  ✅ SIMPLIFIED: Just calls appConfig.performFactoryReset()
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var coverArtService: CoverArtManager
    @Environment(\.dismiss) private var dismiss

    @State private var showingSaveSuccess = false
    @State private var showingError = false
    @State private var showingFactoryResetConfirmation = false
    @State private var errorMessage = ""
    @State private var isPerformingReset = false

    var body: some View {
        NavigationStack {
            List {
                if !appConfig.isConfigured {
                    navidromeSection
                }

                if appConfig.isConfigured {
                    serverInfoSection
                    downloadSection
                    cacheSection
                    serverDetailsSection
                    dangerZoneSection
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(appConfig.isConfigured ? "Settings" : "Initial setup")
            .navigationBarTitleDisplayMode(.inline)
            .disabled(isPerformingReset)
            .overlay {
                if isPerformingReset {
                    FactoryResetOverlayView()
                }
            }
            .confirmationDialog(
                "Logout & Factory Reset",
                isPresented: $showingFactoryResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset App to Factory Settings", role: .destructive) {
                    Task {
                        await performFactoryReset()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete ALL data including downloaded music, server settings, and cached content. The app will return to initial setup state.")
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var navidromeSection: some View {
        Section("Navidrome") {
            NavigationLink("Edit server") {
                ServerEditView()
            }
            .font(Typography.body)
        }
    }

    @ViewBuilder
    private var serverInfoSection: some View {
        Section("Navidrome") {
            if let creds = AppConfig.shared.getCredentials() {
                let portPart = creds.baseURL.port.map { ":\($0)" } ?? ""

                SettingsRow(
                    title: "Server:",
                    value: "\(creds.baseURL.scheme ?? "http")://\(creds.baseURL.host ?? "-")\(portPart)"
                )

                SettingsRow(
                    title: "User:",
                    value: creds.username
                )
            }
            
            NavigationLink("Edit server") {
                ServerEditView()
            }
            .font(Typography.body)
        }
        .task {
            await navidromeVM.testConnection()
        }
    }

    @ViewBuilder
    private var downloadSection: some View {
        Section("Download") {
            SettingsRow(
                title: "Downloaded music",
                value: downloadManager.totalDownloadSize()
            )

            Button(role: .destructive) {
                downloadManager.deleteAllDownloads()
            } label: {
                Label("Delete all downloads", systemImage: "trash")
                    .font(Typography.body)
            }
            .disabled(isPerformingReset)
        }
    }

    @ViewBuilder
    private var cacheSection: some View {
        Section("Cache Management") {
            NavigationLink("Cache Settings") {
                CacheSettingsView()
            }
            .font(Typography.body)
            
            SettingsRow(
                title: "Cover Art Cache",
                value: getCoverCacheSize()
            )
            
            SettingsRow(
                title: "Download Cache",
                value: downloadManager.totalDownloadSize()
            )
        }
    }

    @ViewBuilder
    private var serverDetailsSection: some View {
        Section("Server info") {
            SettingsRow(
                title: "Type:",
                value: navidromeVM.serverType ?? "-"
            )

            SettingsRow(
                title: "Navidrome-Version:",
                value: navidromeVM.serverVersion ?? "-"
            )

            SettingsRow(
                title: "Subsonic-Version:",
                value: navidromeVM.subsonicVersion ?? "-"
            )

            HStack {
                Text("OpenSubsonic:")
                    .font(Typography.body)
                    .foregroundStyle(TextColor.primary)
                Spacer()
                if let open = navidromeVM.openSubsonic {
                    Text(open ? "Yes" : "No")
                        .font(Typography.body)
                        .foregroundStyle(TextColor.secondary)
                } else {
                    Text("-")
                        .font(Typography.body)
                        .foregroundStyle(TextColor.secondary)
                }
            }
        }
        .task {
            await navidromeVM.testConnection()
        }
    }

    @ViewBuilder
    private var dangerZoneSection: some View {
        Section {
            Button(role: .destructive) {
                showingFactoryResetConfirmation = true
            } label: {
                HStack {
                    if isPerformingReset {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Resetting...")
                    } else {
                        Label("Factory Reset", systemImage: "exclamationmark.triangle.fill")
                    }
                }
                .font(Typography.body)
            }
            .disabled(isPerformingReset)
        } header: {
            Text("Danger Zone")
        } footer: {
            Text("This will completely reset the app to its initial state. All downloaded music, server settings, and cached data will be permanently deleted.")
                .font(Typography.caption)
                .foregroundStyle(TextColor.secondary)
        }
    }

    // MARK: - Factory Reset Method

    private func performFactoryReset() async {
        isPerformingReset = true
        defer { isPerformingReset = false }
        
        await appConfig.performFactoryReset()
        
        await MainActor.run {
            dismiss()
        }
    }

    // MARK: - Helper Methods
    private func getCoverCacheSize() -> String {
        let stats = PersistentImageCache.shared.getCacheStats()
        return stats.diskSizeFormatted
    }
}

// MARK: - Factory Reset Overlay
struct FactoryResetOverlayView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: Spacing.l) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text("Factory Reset in Progress...")
                    .font(Typography.headline)
                    .foregroundStyle(.white)
                
                Text("Clearing all data and resetting app")
                    .font(Typography.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(Padding.xl)
            .background(BackgroundColor.thick, in: RoundedRectangle(cornerRadius: Radius.l))
            .largeShadow()
        }
    }
}

// MARK: - Settings Row Component
struct SettingsRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(Typography.body)
                .foregroundStyle(TextColor.primary)
            Spacer()
            Text(value)
                .font(Typography.body)
                .foregroundStyle(TextColor.secondary)
                .multilineTextAlignment(.trailing)
                .textCase(nil)
        }
    }
}
// MARK: - ServerEditView (CLEANED - No Logout)
struct ServerEditView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var coverArtService: CoverArtManager
    @Environment(\.dismiss) private var dismiss

    @State private var showingSaveSuccess = false
    @State private var showingError = false
    @State private var showingOfflineWarning = false
    @State private var errorMessage = ""

    var body: some View {
        Form {
            // ✅ Offline Mode Warning (unchanged)
            if offlineManager.isOfflineMode || !networkMonitor.canLoadOnlineContent {
                Section {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        HStack {
                            Image(systemName: "wifi.slash")
                                .foregroundStyle(BrandColor.warning)
                            Text("Offline Mode Active")
                                .font(Typography.headline)
                                .foregroundStyle(BrandColor.warning)
                        }
                        
                        Text("To test server connection, please switch to online mode first.")
                            .font(Typography.subheadline)
                            .foregroundStyle(TextColor.secondary)
                        
                        Button("Switch to Online Mode") {
                            offlineManager.switchToOnlineMode()
                        }
                        .secondaryButtonStyle()
                    }
                    .listItemPadding()
                    .background(BrandColor.warning.opacity(0.1), in: RoundedRectangle(cornerRadius: Radius.s))
                }
            }

            Section("Server & Login") {
                Picker("Protocol", selection: $navidromeVM.scheme) {
                    Text("http").tag("http")
                    Text("https").tag("https")
                }
                .pickerStyle(.segmented)

                TextField("Host", text: $navidromeVM.host)
                    .textInputAutocapitalization(.none)
                    .disableAutocorrection(true)

                TextField("Port", text: $navidromeVM.port)
                    .keyboardType(.numberPad)

                TextField("Username", text: $navidromeVM.username)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                
                SecureField("Password", text: $navidromeVM.password)

                ConnectionStatusView(navidromeVM: navidromeVM)

                Button("Test connection") {
                    Task { await testConnectionWithOfflineCheck() }
                }
                .disabled(
                    navidromeVM.isLoading ||
                    navidromeVM.host.isEmpty ||
                    navidromeVM.username.isEmpty ||
                    navidromeVM.password.isEmpty ||
                    (offlineManager.isOfflineMode && !networkMonitor.canLoadOnlineContent)
                )
            }

            Section {
                Button("Save & Continue") {
                    Task {
                        await saveCredentialsAndReload()
                    }
                }
                .disabled(navidromeVM.isLoading || !navidromeVM.connectionStatus)
            }
            
            if navidromeVM.connectionStatus {
                ConnectionDetailsSection(navidromeVM: navidromeVM)
            }
        }
        .navigationTitle(appConfig.isConfigured ? "Edit server" : "Initial setup")
        .onAppear {
            if !navidromeVM.host.isEmpty && !navidromeVM.username.isEmpty && !navidromeVM.password.isEmpty {
                Task { await testConnectionWithOfflineCheck() }
            }
        }
        .alert("Success", isPresented: $showingSaveSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Configuration saved successfully")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Switch to Online Mode?", isPresented: $showingOfflineWarning) {
            Button("Switch to Online") {
                offlineManager.switchToOnlineMode()
                Task { await navidromeVM.testConnection() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You need to be in online mode to test the server connection.")
        }
    }
    
    // ✅ Server connection methods (unchanged)
    private func testConnectionWithOfflineCheck() async {
        if offlineManager.isOfflineMode || !networkMonitor.canLoadOnlineContent {
            showingOfflineWarning = true
            return
        }
        
        await navidromeVM.testConnection()
    }

    private func saveCredentialsAndReload() async {
        let success = await navidromeVM.saveCredentials()
        if success {
            if let service = navidromeVM.getService() {
                await MainActor.run {
                    playerVM.updateService(service)
                    coverArtService.configure(service: service)
                    networkMonitor.setService(service)
                }
            }

            await MainActor.run {
                dismiss()
            }

            if !appConfig.isConfigured {
                await MainActor.run {
                    appConfig.isConfigured = true
                }
                showingSaveSuccess = true
            }
            
            await navidromeVM.loadInitialDataIfNeeded()
            
        } else {
            errorMessage = navidromeVM.errorMessage ?? "Fehler beim Speichern"
            showingError = true
        }
    }
}

// MARK: - Helper Components (unchanged)
struct ConnectionStatusView: View {
    @ObservedObject var navidromeVM: NavidromeViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Connection:")
                Spacer()
                
                if navidromeVM.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: navidromeVM.connectionStatus ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(navidromeVM.connectionStatus ? .green : .red)
                }
                
                if navidromeVM.isLoading {
                    Text("Testing...")
                        .foregroundColor(.blue)
                } else {
                    Text(navidromeVM.connectionStatus ? "Success" : "Error")
                        .foregroundColor(navidromeVM.connectionStatus ? .green : .red)
                }
            }
            
            if !navidromeVM.connectionStatus, let error = navidromeVM.errorMessage, !navidromeVM.isLoading {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 4)
                    .multilineTextAlignment(.leading)
            }
            
            if navidromeVM.connectionStatus, let serverType = navidromeVM.serverType {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Server: \(serverType)")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    if let version = navidromeVM.serverVersion {
                        Text("Version: \(version)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}

struct ConnectionDetailsSection: View {
    @ObservedObject var navidromeVM: NavidromeViewModel
    
    var body: some View {
        Section("Connection Details") {
            if let subsonicVersion = navidromeVM.subsonicVersion {
                HStack {
                    Text("Subsonic API:")
                    Spacer()
                    Text(subsonicVersion)
                        .foregroundStyle(.secondary)
                }
            }
            
            if let openSubsonic = navidromeVM.openSubsonic {
                HStack {
                    Text("OpenSubsonic:")
                    Spacer()
                    Text(openSubsonic ? "Yes" : "No")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Cache Settings View (Complete Implementation)
struct CacheSettingsView: View {
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
