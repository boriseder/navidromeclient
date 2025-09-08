import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    
    @State private var showingSettings = false
    
    var body: some View {
        Group {
            if appConfig.isConfigured {
                MainTabView()
            } else {
                WelcomeView()
            }
        }
        .onAppear {
            // Überprüfe beim Start, ob Konfiguration vorhanden ist
            if !appConfig.isConfigured {
                showingSettings = true
            }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationView {
                SettingsView()
                    .navigationTitle("Setup")
                    .navigationBarTitleDisplayMode(.inline)
                   /*
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showingSettings = false
                                }
                        }
                    */
                    }
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

struct MainTabView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var appConfig: AppConfig

    @State private var navPath: [AnyHashable] = []

    var body: some View {
        TabView {
            ZStack {
                HomeScreenView()
                VStack {
                    Spacer()
                    MiniPlayerView()
                        .environmentObject(playerVM)
                        .frame(height: 90)
                }
            }
            .tabItem { Label("Explore", systemImage: "music.note.house") }
            ZStack {
                ArtistsView()
                VStack {
                    Spacer()
                    MiniPlayerView()
                        .environmentObject(playerVM)
                        .frame(height: 90)
                }
            }
            .tabItem { Label("Artists", systemImage: "person.2.fill") }
            ZStack {
            GenreView()
            VStack {
                Spacer()
                MiniPlayerView()
                    .environmentObject(playerVM)
                    .frame(height: 90)
                }
            }
            .tabItem { Label("Genre", systemImage: "music.note.list") }
            ZStack {
                SearchView()
                VStack {
                    Spacer()
                    MiniPlayerView()
                        .environmentObject(playerVM)
                        .frame(height: 90)
                }
            }
            .tabItem { Label("Suche", systemImage: "magnifyingglass") }
        }
        .onAppear {
            // TabBar transparent + ultra thin material
            let appearance = UITabBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)

            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}
