//
//  ServerEditView.swift
//  NavidromeClient
//
//  Created by Boris Eder on 24.09.25.
//


//
//  ServerEditView.swift - FIXED: Direct ConnectionManager Binding
//  NavidromeClient
//
//  Removed circular dependency with NavidromeViewModel
//  Direct ConnectionManager usage for proper SwiftUI binding
//

import SwiftUI

struct ServerEditView: View {
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    @Environment(\.dismiss) private var dismiss

    @StateObject private var connectionManager = ConnectionViewModel()
    @State private var showingSaveSuccess = false
    @State private var showingError = false
    @State private var showingOfflineWarning = false
    @State private var errorMessage = ""

    var body: some View {
        Form {
            if offlineManager.isOfflineMode || !networkMonitor.canLoadOnlineContent {
                OfflineWarningSection()
            }

            Section("Server & Login") {
                Picker("Protocol", selection: $connectionManager.scheme) {
                    Text("http").tag("http")
                    Text("https").tag("https")
                }.pickerStyle(.segmented)

                TextField("Host", text: $connectionManager.host)
                    .textInputAutocapitalization(.none)
                    .disableAutocorrection(true)
                TextField("Port", text: $connectionManager.port)
                    .keyboardType(.numberPad)
                TextField("Username", text: $connectionManager.username)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                SecureField("Password", text: $connectionManager.password)

                ConnectionStatusView(connectionManager: connectionManager)

                Button("Test Connection") {
                    Task { await testConnectionWithOfflineCheck() }
                }
                .disabled(!connectionManager.canTestConnection || 
                         (offlineManager.isOfflineMode && !networkMonitor.canLoadOnlineContent))
            }

            Section {
                Button("Save & Continue") {
                    Task { await saveCredentialsAndConfigure() }
                }
                .disabled(!connectionManager.isConnected)
            }

            if connectionManager.isConnected {
                ServerHealthSection(connectionManager: connectionManager)
            }
        }
        .navigationTitle(appConfig.isConfigured ? "Edit Server" : "Initial Setup")
        .onAppear {
            loadExistingCredentials()
            if connectionManager.canTestConnection {
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
                Task { await connectionManager.testConnection() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You need to be in online mode to test the server connection.")
        }
    }
    
    // MARK: - Actions
    
    private func loadExistingCredentials() {
        if let creds = AppConfig.shared.getCredentials() {
            connectionManager.scheme = creds.baseURL.scheme ?? "http"
            connectionManager.host = creds.baseURL.host ?? ""
            connectionManager.port = creds.baseURL.port.map { String($0) } ?? ""
            connectionManager.username = creds.username
            connectionManager.password = creds.password
        }
    }
    
    private func saveCredentialsAndConfigure() async {
        let success = await connectionManager.saveCredentials()
        if success {
            await MainActor.run {
                showingSaveSuccess = true
                dismiss()
            }
        } else {
            errorMessage = connectionManager.connectionError ?? "Failed to save credentials"
            showingError = true
        }
    }
    
    private func testConnectionWithOfflineCheck() async {
        if offlineManager.isOfflineMode || !networkMonitor.canLoadOnlineContent {
            showingOfflineWarning = true
            return
        }
        await connectionManager.testConnection()
    }
}

// MARK: - Supporting Views

struct ConnectionStatusView: View {
    @ObservedObject var connectionManager: ConnectionViewModel

    var body: some View {
        HStack {
            Text("Connection:")
            Spacer()
            if connectionManager.isTestingConnection {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Image(systemName: connectionManager.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(connectionManager.isConnected ? .green : .red)
                Text(connectionManager.connectionStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ServerHealthSection: View {
    @ObservedObject var connectionManager: ConnectionViewModel
    
    var body: some View {
        Section("Connection Details") {
            HStack {
                Text("Response Time:")
                Spacer()
                Text("< 1000ms") // Placeholder since we don't have detailed metrics
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Connection Quality:")
                Spacer()
                Text(connectionManager.connectionStatusText)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct OfflineWarningSection: View {
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    
    var body: some View {
        Section {
            HStack {
                Image(systemName: offlineManager.isOfflineMode ? "icloud.slash" : "wifi.slash")
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Offline Mode Active")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(warningText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if networkMonitor.canLoadOnlineContent {
                    Button("Go Online") {
                        offlineManager.switchToOnlineMode()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(Color.orange.opacity(0.1))
    }
    
    private var warningText: String {
        if !networkMonitor.canLoadOnlineContent {
            return "No internet connection available"
        } else if offlineManager.isOfflineMode {
            return "Using downloaded content only"
        } else {
            return "Limited connectivity"
        }
    }
}
