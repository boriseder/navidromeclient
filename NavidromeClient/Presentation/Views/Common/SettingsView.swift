//
//  SettingsView.swift - Enhanced with Design System
//  NavidromeClient
//
//  ✅ ENHANCED: Vollständige Anwendung des Design Systems
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var downloadManager: DownloadManager
    @Environment(\.dismiss) private var dismiss

    @State private var showingSaveSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""

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

            Button(role: .destructive) {
                logout()
            } label: {
                Label("Logout", systemImage: "power")
                    .font(Typography.body)
            }
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

    // MARK: - Helper Methods
    private func logout() {
        appConfig.logout()
        navidromeVM.reset()
        downloadManager.deleteAllDownloads()
        let defaultService = SubsonicService(baseURL: URL(string: "http://localhost")!, username: "", password: "")
        playerVM.updateService(defaultService)
        dismiss()
    }
    
    private func getCoverCacheSize() -> String {
        let stats = PersistentImageCache.shared.getCacheStats()
        return stats.diskSizeFormatted
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
