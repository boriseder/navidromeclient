import SwiftUI

struct loadingView: View {
    @EnvironmentObject var navidromeVM: NavidromeViewModel

    var body: some View {
        VStack(spacing: Spacing.l) {
            // Animated loading circles
            HStack(spacing: Spacing.s) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(BrandColor.primary)
                        .frame(width: 12, height: 12) // Approx. DS applied
                        .scaleEffect(navidromeVM.isLoading ? 1.0 : 0.5)
                        .animation(
                            Animations.ease.repeatForever()
                            .delay(Double(index) * 0.2),
                            value: navidromeVM.isLoading
                        )
                }
            }
            
            Text("Loading...")
                .font(Typography.headline)
                .foregroundStyle(TextColor.primary)
            
            Text("Discovering your music library")
                .font(Typography.caption)
                .foregroundStyle(TextColor.secondary)
        }
        .padding(Spacing.xl)
        .materialCardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: Radius.m)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .largeShadow()
    }
}


