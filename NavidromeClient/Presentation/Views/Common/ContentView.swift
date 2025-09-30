// ContentView.swift - Navigation direkt zu MainTabView
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    
    @State private var showingSettings = false
    
    var body: some View {
        Group {
            if appConfig.isConfigured {
                if appConfig.isInitializingServices {
                    // Show loading state during service initialization
                    VStack(spacing: DSLayout.contentGap) {
                        ProgressView()
                        Text("Initializing services...")
                            .font(DSText.body)
                            .foregroundStyle(DSColor.secondary)
                    }
                } else {
                    MainTabView()
                }
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
            if !appConfig.isConfigured {
                showingSettings = true
            }
        }
        .onChange(of: networkMonitor.canLoadOnlineContent) { _, isConnected in
            handleNetworkChange(isConnected)
        }
    }
    
    private func handleNetworkChange(_ isConnected: Bool) {
        if !isConnected {
            print("📵 Network lost - switching to offline mode")
            offlineManager.switchToOfflineMode()
        } else {
            print("📶 Network restored")
        }
    }
}
