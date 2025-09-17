import SwiftUI

// MARK: - SettingsView
struct SettingsView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var coverArtService: CoverArtManager
    @Environment(\.dismiss) private var dismiss

    @State private var showingFactoryResetConfirmation = false
    @State private var isPerformingReset = false

    var body: some View {
        NavigationStack {
            List {
                NavidromeSection
                if appConfig.isConfigured {
                    CacheSection
                    ServerDetailsSection
                    DangerZoneSection
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(appConfig.isConfigured ? "Settings" : "Initial Setup")
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
            NavigationLink("Edit Server") { ServerEditView() }
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

    private var ServerDetailsSection: some View {
        Section {
            SettingsRow(title: "Status:", value: navidromeVM.connectionStatus ? "Connected" : "Disconnected")
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

struct ConnectionStatusView: View {
    @ObservedObject var navidromeVM: NavidromeViewModel

    var body: some View {
        HStack {
            Text("Connection:")
            Spacer()
            if navidromeVM.isLoading { ProgressView() }
            else {
                Image(systemName: navidromeVM.connectionStatus ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(navidromeVM.connectionStatus ? .green : .red)
            }
        }
    }
}

struct ConnectionDetailsSection: View {
    @ObservedObject var navidromeVM: NavidromeViewModel

    var body: some View {
        Section("Connection Details") {
            if let subsonicVersion = navidromeVM.subsonicVersion {
                HStack { Text("Subsonic API:"); Spacer(); Text(subsonicVersion).foregroundStyle(.secondary) }
            }
            if let openSubsonic = navidromeVM.openSubsonic {
                HStack { Text("OpenSubsonic:"); Spacer(); Text(openSubsonic ? "Yes" : "No").foregroundStyle(.secondary) }
            }
        }
    }
}

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


// MARK: - ServerEditView
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
            if offlineManager.isOfflineMode || !networkMonitor.canLoadOnlineContent {
                OfflineWarningSection
            }

            Section("Server & Login") {
                Picker("Protocol", selection: $navidromeVM.scheme) {
                    Text("http").tag("http")
                    Text("https").tag("https")
                }.pickerStyle(.segmented)

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

                Button("Test Connection") {
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
                    Task { await saveCredentialsAndReloadViaViewModels() }
                }
                .disabled(navidromeVM.isLoading || !navidromeVM.connectionStatus)
            }

            if navidromeVM.connectionStatus {
                ConnectionDetailsSection(navidromeVM: navidromeVM)
            }
        }
        .navigationTitle(appConfig.isConfigured ? "Edit Server" : "Initial Setup")
        .onAppear {
            if !navidromeVM.host.isEmpty && !navidromeVM.username.isEmpty && !navidromeVM.password.isEmpty {
                Task { await testConnectionWithOfflineCheck() }
            }
        }
        .alert("Success", isPresented: $showingSaveSuccess) { Button("OK", role: .cancel) {} } message: { Text("Configuration saved successfully") }
        .alert("Error", isPresented: $showingError) { Button("OK", role: .cancel) {} } message: { Text(errorMessage) }
        .alert("Switch to Online Mode?", isPresented: $showingOfflineWarning) {
            Button("Switch to Online") {
                offlineManager.switchToOnlineMode()
                Task { await navidromeVM.testConnection() }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("You need to be in online mode to test the server connection.") }
    }
    
    // ✅ FOCUSED: Route through ViewModels only (no service extraction)
    private func saveCredentialsAndReloadViaViewModels() async {
        let success = await navidromeVM.saveCredentials()
        if success {
            // ✅ ROUTE: Configure managers through their own methods (no direct service extraction)
            await MainActor.run {
                // PlayerViewModel and managers will be configured by NavidromeViewModel
                // when it calls updateService() internally
                NetworkMonitor.shared.setConnectionManager(navidromeVM.connectionManager)
            }
            
            await MainActor.run { dismiss() }
            if !appConfig.isConfigured {
                await MainActor.run { appConfig.isConfigured = true }
                showingSaveSuccess = true
            }
            await navidromeVM.loadInitialDataIfNeeded()
        } else {
            errorMessage = navidromeVM.errorMessage ?? "Fehler beim Speichern"
            showingError = true
        }
    }
    
    // ❌ REMOVED: service.getMediaService() calls
    // ❌ REMOVED: service.get*Service() manual extraction
    // ❌ REMOVED: Direct service configuration
    
    private func testConnectionWithOfflineCheck() async {
        if offlineManager.isOfflineMode || !networkMonitor.canLoadOnlineContent {
            showingOfflineWarning = true
            return
        }
        await navidromeVM.testConnection()
    }
    
    // ... (rest unchanged)
}

// MARK: - CacheSettingsView
struct CacheSettingsView: View {
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var coverArtService: CoverArtManager

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
                HStack { Text("Downloaded Music"); Spacer(); Text(downloadManager.totalDownloadSize()).foregroundStyle(.secondary) }
                Button(role: .destructive) { downloadManager.deleteAllDownloads() } label: { Label("Delete ALL Music", systemImage: "trash") }
            }
        }
        .navigationTitle("Cache Management")
        .confirmationDialog("Clear Cover Art Cache?", isPresented: $showingClearConfirmation) {
            Button("Clear Cache", role: .destructive) { clearCoverArtCache() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This will remove all cached cover art images.") }
        .alert("Cache Cleared", isPresented: $showingClearSuccess) { Button("OK") {} } message: { Text("Cover art cache has been successfully cleared.") }
        .task { updateCacheStats() }
        .refreshable { updateCacheStats() }
    }

    private func updateCacheStats() { cacheStats = PersistentImageCache.shared.getCacheStats() }
    private func clearCoverArtCache() { PersistentImageCache.shared.clearCache(); updateCacheStats(); showingClearSuccess = true }
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
