import SwiftUI

struct DynamicMusicBackground: View {
    @State private var animateGradient = false
    
    var body: some View {
        ZStack {
            // Base gradient with animation
            LinearGradient(
                colors: [
                    Color(red: 0.25, green: 0.30, blue: 0.42),
                    Color(red: 0.32, green: 0.25, blue: 0.45),
                    Color(red: 0.20, green: 0.28, blue: 0.38)
                ],
                startPoint: animateGradient ? .topLeading : .bottomLeading,
                endPoint: animateGradient ? .bottomTrailing : .topTrailing
            )
            .ignoresSafeArea()
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 8)
                    .repeatForever(autoreverses: true)
                ) {
                    animateGradient.toggle()
                }
            }
            
            // Overlay gradient for depth
            RadialGradient(
                colors: [
                    Color(red: 0.38, green: 0.35, blue: 0.48).opacity(0.3),
                    Color.clear,
                    Color(red: 0.18, green: 0.22, blue: 0.32).opacity(0.4)
                ],
                center: UnitPoint(x: 0.3, y: 0.2),
                startRadius: 150,
                endRadius: 500
            )
            .ignoresSafeArea()
            
            // Subtle texture overlay
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.01),
                            Color.clear,
                            Color.black.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .ignoresSafeArea()
        }
    }
}

// MARK: - Alternative Variants

extension DynamicMusicBackground {
    // Spotify-inspired variant
    static var spotifyStyle: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.35, green: 0.45, blue: 0.40),
                    Color(red: 0.25, green: 0.55, blue: 0.35),
                    Color(red: 0.30, green: 0.40, blue: 0.35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
    
    // Elegant dark variant
    static var elegantDark: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.22, green: 0.28, blue: 0.35),
                    Color(red: 0.28, green: 0.22, blue: 0.38),
                    Color(red: 0.18, green: 0.25, blue: 0.32)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Subtle highlight
            RadialGradient(
                colors: [
                    Color.white.opacity(0.08),
                    Color.clear
                ],
                center: UnitPoint(x: 0.7, y: 0.3),
                startRadius: 100,
                endRadius: 300
            )
            .ignoresSafeArea()
        }
    }
}
