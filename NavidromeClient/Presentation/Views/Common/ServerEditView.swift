import SwiftUI

struct ServerEditView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var downloadManager: DownloadManager
    @Environment(\.dismiss) private var dismiss

    @State private var showingSaveSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        Form {
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

                HStack {
                    Text("Connection:")
                    Spacer()
                    Image(systemName: navidromeVM.connectionStatus ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(navidromeVM.connectionStatus ? .green : .red)
                    Text(navidromeVM.connectionStatus ? "Success" : "Error")
                        .foregroundColor(navidromeVM.connectionStatus ? .green : .red)
                }

                Button("Test connection") {
                    Task { await navidromeVM.testConnection() }
                }
                .disabled(navidromeVM.isLoading)
            }

            Section {
                Button("Save & Continue") {
                    Task {
                        await saveCredentialsAndClose()
                    }
                }
                .disabled(navidromeVM.isLoading || !navidromeVM.connectionStatus)
            }
        }
        .navigationTitle(appConfig.isConfigured ? "Edit server" : "Initial setup")
        .onAppear {
            if !navidromeVM.host.isEmpty {
                Task { await navidromeVM.testConnection() }
            }
        }
        .alert("Success", isPresented: $showingSaveSuccess) {
            Button("OK", role: .cancel) {
                // Nichts extra nötig, Sheet wird schon geschlossen
            }
        } message: {
            Text("Configuration saved successfully")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Save & Close
    private func saveCredentialsAndClose() async {
        let success = await navidromeVM.saveCredentials()
        if success {
            // Player-Service aktualisieren
            if let service = navidromeVM.getService() {
                playerVM.updateService(service)
            }

            // Sheet schließen auf MainActor
            await MainActor.run {
                dismiss()
            }

            // Ersteinrichtung markieren
            if !appConfig.isConfigured {
                appConfig.isConfigured = true
                showingSaveSuccess = true
            }
        } else {
            errorMessage = navidromeVM.errorMessage ?? "Fehler beim Speichern"
            showingError = true
        }
    }
}
