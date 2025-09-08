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
                    Section("Navidrome-Server") {
                        NavigationLink("Server einrichten") {
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
                    Section("Navidrome-Server") {
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
                        NavigationLink("Server bearbeiten") {
                            ServerEditView()
                                .environmentObject(navidromeVM)
                                .environmentObject(appConfig)
                                .environmentObject(playerVM)
                                .environmentObject(downloadManager)
                        }

                        Button(role: .destructive) {
                            logout()
                        } label: {
                            Label("Abmelden", systemImage: "power")
                        }
                    }
                    .task {
                        await navidromeVM.testConnection()
                    }
                    // Caches Section
                    Section("Caches") {
                        HStack {
                            Text("Download Speicher")
                            Spacer()
                            Text(downloadManager.totalDownloadSize())
                                .foregroundStyle(.secondary)
                        }

                        Button(role: .destructive) {
                            downloadManager.deleteAllDownloads()
                        } label: {
                            Label("Alle Downloads löschen", systemImage: "trash")
                        }
                    }

                    // Dummy Section: Benachrichtigungen
                    Section("Benachrichtigungen") {
                        Toggle("Push-Benachrichtigungen aktiv", isOn: .constant(true))
                        Toggle("Newsletter abonnieren", isOn: .constant(false))
                    }

                    // Dummy Section: Design
                    Section("Design") {
                        Picker("App-Theme", selection: .constant("Hell")) {
                            Text("Hell").tag("Hell")
                            Text("Dunkel").tag("Dunkel")
                        }
                        .pickerStyle(.segmented)
                    }
                    // MARK: - Server-Infos Section (Fußnote)
                    Section("Server-Infos") {

                            HStack {
                                Text("Server-Typ:")
                                Spacer()
                                Text(navidromeVM.serverType ?? "-")
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                Text("Server-Version:")
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
                                    Text(open ? "Ja" : "Nein")
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
            .navigationTitle(appConfig.isConfigured ? "Einstellungen" : "Ersteinrichtung")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Erfolg", isPresented: $showingSaveSuccess) {
                Button("OK") {}
            } message: {
                Text("Konfiguration gespeichert!")
            }
            .alert("Fehler", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
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
