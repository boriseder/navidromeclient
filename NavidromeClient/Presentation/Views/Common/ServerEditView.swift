import SwiftUI

struct ServerEditView: View {
    // ALLE zu @EnvironmentObject geändert
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

                // Connection status display
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

                Button("Test connection") {
                    Task { await navidromeVM.testConnection() }
                }
                .disabled(navidromeVM.isLoading || navidromeVM.host.isEmpty || navidromeVM.username.isEmpty || navidromeVM.password.isEmpty)
            }

            Section {
                Button("Save & Continue") {
                    Task {
                        await saveCredentialsAndClose()
                    }
                }
                .disabled(navidromeVM.isLoading || !navidromeVM.connectionStatus)
            }
            
            if navidromeVM.connectionStatus {
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
        .navigationTitle(appConfig.isConfigured ? "Edit server" : "Initial setup")
        .onAppear {
            if !navidromeVM.host.isEmpty && !navidromeVM.username.isEmpty && !navidromeVM.password.isEmpty {
                Task { await navidromeVM.testConnection() }
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
    }

    private func saveCredentialsAndClose() async {
        let success = await navidromeVM.saveCredentials()
        if success {
            if let service = navidromeVM.getService() {
                playerVM.updateService(service)
            }

            await MainActor.run {
                dismiss()
            }

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
