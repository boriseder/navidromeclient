import SwiftUI

struct DynamicMusicBackground: View {
    @State private var animateGradient = false
    
    var body: some View {
        ZStack {
            // Hauptgradient mit subtilen Rotstichen
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.12, blue: 0.16), // fast schwarz
                    Color(red: 0.25, green: 0.08, blue: 0.12), // tiefrot
                    Color(red: 0.18, green: 0.15, blue: 0.20), // dunkles violettgrau
                    Color(red: 0.20, green: 0.10, blue: 0.15)  // rot-violetter Touch
                ],
                startPoint: animateGradient ? .topLeading : .bottomTrailing,
                endPoint: animateGradient ? .bottomTrailing : .topLeading
            )
            .ignoresSafeArea()
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 10)
                    .repeatForever(autoreverses: true)
                ) {
                    animateGradient.toggle()
                }
            }
            
            // Eleganter roter Glow-Effekt
            RadialGradient(
                colors: [
                    Color(red: 0.6, green: 0.1, blue: 0.15).opacity(0.4),
                    Color.clear
                ],
                center: UnitPoint(x: 0.4, y: 0.3),
                startRadius: 100,
                endRadius: 500
            )
            .blendMode(.screen)
            .ignoresSafeArea()
            
            // Leichte Textur für Tiefe
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.015),
                            Color.clear,
                            Color.black.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.overlay)
                .ignoresSafeArea()
        }
    }
}
