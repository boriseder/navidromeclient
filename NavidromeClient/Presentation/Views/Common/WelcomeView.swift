import SwiftUI

struct WelcomeView: View {
    let onGetStarted: () -> Void
    
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
                onGetStarted()
            }
            .buttonStyle(.borderedProminent)
            .font(.headline)
        }
        .padding()
    }
}
