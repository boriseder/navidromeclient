import SwiftUI

struct notConfiguredView: View {
    @State var showingSettings = false

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "gear.badge.questionmark")
                .font(.system(size: 60)) // Approx. DS applied
                .foregroundStyle(TextColor.secondary)
            
            VStack(spacing: Spacing.s) {
                Text("Setup Required")
                    .font(Typography.title2)
                
                Text("Please configure your Navidrome server connection in Settings")
                    .font(Typography.body)
                    .foregroundStyle(TextColor.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Open Settings") {
                showingSettings = true
            }
            .primaryButtonStyle()
        }
        .padding(Padding.xl)
    }
}


