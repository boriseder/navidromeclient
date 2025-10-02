// ContentView.swift - Navigation direkt zu MainTabView
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var offlineManager: OfflineManager
    
    @State private var showingSettings = false
    @State private var isInitialSetup = false
    @State private var serviceInitError: String?

    var body: some View {
        Group {
            switch networkMonitor.contentLoadingStrategy {
            case .setupRequired:
                WelcomeView {
                    isInitialSetup = true
                    showingSettings = true
                }
                
            case .online, .offlineOnly:
                if appConfig.isInitializingServices {
                    VStack(spacing: DSLayout.contentGap) {
                        ProgressView()
                        Text("Initializing services...")
                            .font(DSText.body)
                            .foregroundStyle(DSColor.secondary)
                    }
                } else {
                    MainTabView()
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationView {
                ServerEditView(dismissParent: {
                    if isInitialSetup {
                        showingSettings = false
                        isInitialSetup = false
                    }
                })
                .navigationTitle("Server Setup")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .onAppear {
            if !appConfig.isConfigured {
                isInitialSetup = true
                showingSettings = true
            }
        }
        .onChange(of: networkMonitor.canLoadOnlineContent) { _, isConnected in
            handleNetworkChange(isConnected)
        }
    }

    private func handleNetworkChange(_ isConnected: Bool) {
        if !isConnected {
            print("Network lost - switching to offline mode")
            offlineManager.switchToOfflineMode()
        } else {
            print("Network restored")
        }
    }
    
    private func retryServiceInitialization() async {
        guard let credentials = appConfig.getCredentials() else {
            serviceInitError = "No credentials available"
            return
        }
        
        serviceInitError = nil
        
        // Trigger re-initialization
        NotificationCenter.default.post(
            name: .servicesNeedInitialization,
            object: credentials
        )
        
        // Wait for initialization with timeout
        for attempt in 0..<10 {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if appConfig.areServicesReady {
                print("Service initialization retry succeeded")
                return
            }
        }
        
        serviceInitError = "Retry failed - check your connection"
    }
}
