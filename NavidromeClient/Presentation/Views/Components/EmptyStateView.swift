import SwiftUI

struct notConfiguredView: View {
    @State var showingSettings = false

    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "gear.badge.questionmark")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 12) {
                Text("Setup Required")
                    .font(.title2.weight(.semibold))
                
                Text("Please configure your Navidrome server connection in Settings")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Open Settings") {
                showingSettings = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

}


