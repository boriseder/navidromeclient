import SwiftUI

struct ContentView: View {
   
    @EnvironmentObject var deps: AppDependencies
    
    @State private var showingSettings = false
    
    var body: some View {
        Group {
            if deps.appConfig.isConfigured {
                MainTabView()
            } else {
                WelcomeView {
                    showingSettings = true
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationView {
                SettingsView()
                    .navigationTitle("Server Setup")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .onAppear {
            if !deps.appConfig.isConfigured {
                showingSettings = true
            }
        }
        .onChange(of: deps.networkMonitor.isConnected) { _, isConnected in
            handleNetworkChange(isConnected)
        }
    }
    
    private func handleNetworkChange(_ isConnected: Bool) {
        if !isConnected {
            print("📵 Network lost - switching to offline mode")
            deps.offlineManager.switchToOfflineMode()
        } else {
            print("📶 Network restored")
        }
    }
}
