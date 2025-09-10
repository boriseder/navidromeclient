import SwiftUI

struct loadingView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel

    var body: some View {
        VStack(spacing: 24) {
            // Animated loading circles
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color(.systemIndigo))
                        .frame(width: 12, height: 12)
                        .scaleEffect(navidromeVM.isLoading ? 1.0 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                            value: navidromeVM.isLoading
                        )
                }
            }
            
            Text("Loading...")
                .font(.headline.weight(.medium))
                .foregroundStyle(.primary)
            
            Text("Discovering your music library")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(radius: 20, y: 10)
    }
}


