import SwiftUI

struct DynamicMusicBackground: View {
    @State private var animateNoise = false
    
    var body: some View {
        ZStack {
            // 1. Basis: dunkler, aber erkennbarer Gradient
            LinearGradient(
                colors: [
                    Color(red: 0.68, green: 0.48, blue: 0.35),
                    Color(red: 0.45, green: 0.20, blue: 0.35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // 2. Dynamisches Noise
            NoiseOverlay()
                .ignoresSafeArea()
                .opacity(0.12)
                .blendMode(.screen) // Screen = Noise heller auf dunkel
            
            // 3. Vignette
            RadialGradient(
                gradient: Gradient(colors: [.clear, .black.opacity(0.5)]),
                center: .center,
                startRadius: 200,
                endRadius: 800
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Noise Overlay
struct NoiseOverlay: View {
    @State private var seed = Int.random(in: 0..<10_000)
    
    var body: some View {
        TimelineView(.animation) { _ in
            Canvas { context, size in
                let grainCount = Int(size.width * size.height / 150)
                
                for _ in 0..<grainCount {
                    let x = CGFloat.random(in: 0..<size.width)
                    let y = CGFloat.random(in: 0..<size.height)
                    let gray = Double.random(in: 0.6...1.0) // heller, mehr sichtbar
                    let opacity = Double.random(in: 0.05...0.2)
                    
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: 1.3, height: 1.3)),
                        with: .color(Color(white: gray, opacity: opacity))
                    )
                }
            }
        }
    }
}
