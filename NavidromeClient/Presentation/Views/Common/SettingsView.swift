//
//  SettingsView.swift - ENHANCED with Complete Reset & Reload Logic
//  NavidromeClient
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var coverArtService: ReactiveCoverArtService
    @Environment(\.dismiss) private var dismiss

    @State private var showingSaveSuccess = false
    @State private var showingError = false
    @State private var showingLogoutConfirmation = false
    @State private var errorMessage = ""
    @State private var isLoggingOut = false

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
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(appConfig.isConfigured ? "Settings" : "Initial setup")
            .navigationBarTitleDisplayMode(.inline)
            .disabled(isLoggingOut) // Disable during logout
            .overlay {
                if isLoggingOut {
                    LogoutOverlayView()
                }
            }
        }
    }

    // MARK: - Navidrome Section (Enhanced with DS)
    @ViewBuilder
    private var navidromeSection: some View {
        Section("Navidrome") {
            NavigationLink("Edit server") {
                ServerEditView()
            }
            .font(Typography.body)
        }
    }

    // MARK: - Server Info Section (Enhanced with DS)
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

            // ✅ ENHANCED: Logout with confirmation
            Button(role: .destructive) {
                showingLogoutConfirmation = true
            } label: {
                HStack {
                    if isLoggingOut {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Logging out...")
                    } else {
                        Label("Logout", systemImage: "power")
                    }
                }
                .font(Typography.body)
            }
            .disabled(isLoggingOut)
        }
        .task {
            await navidromeVM.testConnection()
        }
    }

    // MARK: - Download Section (Enhanced with DS)
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
            .disabled(isLoggingOut)
        }
    }

    // MARK: - Cache Section (Enhanced with DS)
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

    // MARK: - Server Details Section (Enhanced with DS)
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

    // MARK: - ✅ ENHANCED: Complete Logout Logic
    private func performCompleteLogout() async {
        isLoggingOut = true
        defer { isLoggingOut = false }
        
        print("🔄 Starting complete app reset...")
        
        // 1. Stop any current playback immediately
        await MainActor.run {
            playerVM.stop()
        }
        
        // 2. Clear all app config & credentials
        await MainActor.run {
            appConfig.logout()
        }
        
        // 3. Complete ViewModel reset
        await MainActor.run {
            navidromeVM.reset()
        }
        
        // 4. ✅ CRITICAL: Force clear all offline/download data
        await MainActor.run {
            downloadManager.deleteAllDownloads()
            offlineManager.loadOfflineAlbums() // Refresh empty state
        }
        
        // 5. ✅ CRITICAL: Clear all caches
        await MainActor.run {
            PersistentImageCache.shared.clearCache()
            coverArtService.clearMemoryCache()
        }
        
        // 6. ✅ CRITICAL: Reset all services to neutral state
        await MainActor.run {
            let neutralService = SubsonicService(
                baseURL: URL(string: "http://localhost")!,
                username: "",
                password: ""
            )
            playerVM.updateService(neutralService)
            navidromeVM.updateService(neutralService)
            
            // Clear cover art service
            coverArtService.configure(service: neutralService)
        }
        
        // 7. ✅ CRITICAL: Force offline manager to switch to online mode and refresh
        await MainActor.run {
            offlineManager.switchToOnlineMode()
            offlineManager.loadOfflineAlbums() // This should now be empty
        }
        
        // 8. ✅ CRITICAL: Force all UI to update by triggering objectWillChange
        await MainActor.run {
            navidromeVM.objectWillChange.send()
            playerVM.objectWillChange.send()
            downloadManager.objectWillChange.send()
            offlineManager.objectWillChange.send()
            coverArtService.objectWillChange.send()
        }
        
        print("✅ Complete app reset finished")
        
        // 9. Dismiss after everything is clean
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

// MARK: - ✅ ENHANCED: Server Edit View with Offline Mode Handling
struct ServerEditView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @EnvironmentObject var coverArtService: ReactiveCoverArtService
    @Environment(\.dismiss) private var dismiss

    @State private var showingSaveSuccess = false
    @State private var showingError = false
    @State private var showingOfflineWarning = false
    @State private var errorMessage = ""

    var body: some View {
        Form {
            // ✅ NEW: Offline Mode Warning
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

                // Connection status display
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
    
    // ✅ NEW: Test Connection with Offline Check
    private func testConnectionWithOfflineCheck() async {
        if offlineManager.isOfflineMode || !networkMonitor.canLoadOnlineContent {
            showingOfflineWarning = true
            return
        }
        
        await navidromeVM.testConnection()
    }

    // ✅ ENHANCED: Save Credentials and Complete Data Reload
    private func saveCredentialsAndReload() async {
        let success = await navidromeVM.saveCredentials()
        if success {
            // ✅ CRITICAL: Update all services with new credentials
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

            // ✅ CRITICAL: Trigger complete data reload like app start
            if !appConfig.isConfigured {
                await MainActor.run {
                    appConfig.isConfigured = true
                }
                showingSaveSuccess = true
            }
            
            // ✅ CRITICAL: Force initial data load
            await navidromeVM.loadInitialDataIfNeeded()
            
        } else {
            errorMessage = navidromeVM.errorMessage ?? "Fehler beim Speichern"
            showingError = true
        }
    }
}

// MARK: - ✅ Helper Components
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

struct LogoutOverlayView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: Spacing.l) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text("Logging out...")
                    .font(Typography.headline)
                    .foregroundStyle(.white)
                
                Text("Clearing all data and caches")
                    .font(Typography.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(Padding.xl)
            .background(BackgroundColor.thick, in: RoundedRectangle(cornerRadius: Radius.l))
            .largeShadow()
        }
    }
}

// MARK: - ✅ CRITICAL: Confirmation Dialog Extension
extension SettingsView {
    var logoutConfirmationDialog: some View {
        EmptyView()
            .confirmationDialog(
                "Logout and Reset App?",
                isPresented: $showingLogoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Logout & Reset All Data", role: .destructive) {
                    Task {
                        await performCompleteLogout()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove all downloaded music, cached data, and reset the app to initial state.")
            }
    }
}

// MARK: - Settings Row Component (Enhanced with DS)
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
