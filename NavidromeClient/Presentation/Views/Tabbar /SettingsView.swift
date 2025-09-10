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
                // MARK: - Ersteinrichtung
                if !appConfig.isConfigured {
                    Section("Navidrome") {
                        NavigationLink("Edit server") {
                            ServerEditView()
                                .environmentObject(navidromeVM)
                                .environmentObject(appConfig)
                                .environmentObject(playerVM)
                                .environmentObject(downloadManager)
                        }
                    }
                }

                // MARK: - Generelle Einstellungen
                if appConfig.isConfigured {
                    // Server Section
                    Section("Navidrome") {
                        if let creds = AppConfig.shared.getCredentials() {
                            let portPart = creds.baseURL.port.map { ":\($0)" } ?? ""

                            HStack {
                                Text("Server:")
                                Spacer()
                                Text("\(creds.baseURL.scheme ?? "http")://\(creds.baseURL.host ?? "-")\(portPart)")
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.trailing)
                            }

                            HStack {
                                Text("User:")
                                Spacer()
                                Text(creds.username)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.trailing)
                                    .textCase(nil)
                            }

                        }
                        NavigationLink("Edit server") {
                            ServerEditView()
                                .environmentObject(navidromeVM)
                                .environmentObject(appConfig)
                                .environmentObject(playerVM)
                                .environmentObject(downloadManager)
                        }

                        Button(role: .destructive) {
                            logout()
                        } label: {
                            Label("Logout", systemImage: "power")
                        }
                    }
                    .task {
                        await navidromeVM.testConnection()
                    }
                    // Caches Section
                    Section("Caches") {
                        HStack {
                            Text("Download cache")
                            Spacer()
                            Text(downloadManager.totalDownloadSize())
                                .foregroundStyle(.secondary)
                        }

                        Button(role: .destructive) {
                            downloadManager.deleteAllDownloads()
                        } label: {
                            Label("Delete all downloads", systemImage: "trash")
                        }
                    }

                    // MARK: - Server-Infos Section (Fußnote)
                    Section("Server info") {

                            HStack {
                                Text("Type:")
                                Spacer()
                                Text(navidromeVM.serverType ?? "-")
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                Text("Navidrome-Version:")
                                Spacer()
                                Text(navidromeVM.serverVersion ?? "-")
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                Text("Subsonic-Version:")
                                Spacer()
                                Text(navidromeVM.subsonicVersion ?? "-")
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                Text("OpenSubsonic:")
                                Spacer()
                                if let open = navidromeVM.openSubsonic {
                                    Text(open ? "Yes" : "No")
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("-")
                                        .foregroundStyle(.secondary)
                                }
                            }
                    }
                    .task {
                        await navidromeVM.testConnection()
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(appConfig.isConfigured ? "Settings" : "Initial setup")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Logout
    private func logout() {
        appConfig.logout()
        navidromeVM.reset()
        downloadManager.deleteAllDownloads()
        let defaultService = SubsonicService(baseURL: URL(string: "http://localhost")!, username: "", password: "")
        playerVM.updateService(defaultService)
        dismiss()
    }
}
