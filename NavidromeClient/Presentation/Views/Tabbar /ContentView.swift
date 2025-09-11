import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var offlineManager = OfflineManager.shared
    
    @State private var showingSettings = false
    
    var body: some View {
        Group {
            if appConfig.isConfigured {
                MainTabView()
                    .environmentObject(networkMonitor)
                    .environmentObject(offlineManager)
            } else {
                WelcomeView()
            }
        }
        .onAppear {
            if !appConfig.isConfigured {
                showingSettings = true
            }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationView {
                SettingsView()
                    .navigationTitle("Setup")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .onChange(of: networkMonitor.isConnected) { _, isConnected in
            handleNetworkChange(isConnected)
        }
    }
    
    private func handleNetworkChange(_ isConnected: Bool) {
        if !isConnected {
            // Automatisch zu Offline-Modus wechseln wenn Verbindung verloren
            print("📵 Network lost - switching to offline mode")
            offlineManager.switchToOfflineMode()
        } else {
            print("📶 Network restored")
            // Benutzer entscheidet selbst ob zurück zu Online-Modus
        }
    }
}

struct WelcomeView: View {
    @EnvironmentObject var appConfig: AppConfig
    @State private var showingSettings = false
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "music.note.house")
                .font(.system(size: 80))
                .foregroundStyle(.linearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
            
            VStack(spacing: 16) {
                Text("Welcome to Navidrome Client")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                
                Text("Connect to your Navidrome server to start listening to your music library")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button("Get Started") {
                showingSettings = true
            }
            .buttonStyle(.borderedProminent)
            .font(.headline)
        }
        .padding()
        .sheet(isPresented: $showingSettings) {
            NavigationView {
                SettingsView()
                    .navigationTitle("Server Setup")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}
