import SwiftUI

struct DynamicMusicBackground: View {
    @State private var rotation = 0.0
    @State private var scale = 1.0
    @State private var animationPhase = 0.0
    
    // Farbpalette: rötlich
    let colors: [Color] = [
        Color.red.opacity(0.3),
        Color.orange.opacity(0.25),
        Color.red.opacity(0.25),
        Color.green.opacity(0.7)
    ]
    
    // Helligkeitsanpassung: negative Werte = dunkler
    let brightnessAdjustment: Double = 0
 
    var body: some View {
        ZStack {
            // Hintergrund-Gradient
            LinearGradient(
                colors: [
                    Color.red.opacity(0.35),
                    Color.orange.opacity(0.3),
                    Color.pink.opacity(0.25)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .brightness(brightnessAdjustment) // Dunkler machen
            .ignoresSafeArea()
            
            // Blobs
            ForEach(0..<6, id: \.self) { index in
                MusicBlobView(
                    index: index,
                    colors: colors,
                    rotation: rotation,
                    scale: scale,
                    animationPhase: animationPhase,
                    brightnessAdjustment: brightnessAdjustment
                )
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 40).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 18).repeatForever(autoreverses: true)) {
                scale = 1.1
            }
            withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                animationPhase = .pi * 2
            }
        }
        .background(.black.opacity(0.7))
    }
  
    
}

// MARK: - Music Blob View
struct MusicBlobView: View {
    let index: Int
    let colors: [Color]
    let rotation: Double
    let scale: Double
    let animationPhase: Double
    let brightnessAdjustment: Double
    
    var body: some View {
        let baseColor = colors[index % colors.count]
        let size = 220 + Double(index) * 40
        let offsetX = cos(animationPhase + Double(index) * 0.7) * 120
        let offsetY = sin(animationPhase + Double(index) * 0.9) * 100
        let angle = rotation + Double(index) * 45
        let scaleAmount = scale + sin(animationPhase + Double(index)) * 0.12
        
        Circle()
            .fill(
                RadialGradient(
                    colors: [baseColor, baseColor.opacity(0.05), .clear],
                    center: .center,
                    startRadius: 20,
                    endRadius: 200
                )
            )
            .brightness(brightnessAdjustment) // Dunkler machen
            .frame(width: size, height: size)
            .offset(x: offsetX, y: offsetY)
            .rotationEffect(.degrees(angle))
            .scaleEffect(scaleAmount)
            .blur(radius: 35)
            .opacity(0.6)
    }
}
