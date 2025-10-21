import SwiftUI




struct DynamicMusicBackground: View {
    @EnvironmentObject var appConfig: AppConfig
    
    /*
    @AppStorage("UserBackgroundStyle") private var userBackgroundStyleRaw: String = UserBackgroundStyle.dynamic.rawValue
    
    private var userBackgroundStyle: UserBackgroundStyle {
        get { UserBackgroundStyle(rawValue: userBackgroundStyleRaw) ?? .dynamic }
        set { userBackgroundStyleRaw = newValue.rawValue }
    }
    */
    @State private var animateGradient = false
        
    var body: some View {
        ZStack {
            switch appConfig.userBackgroundStyle {
            case .dynamic:
                dynamicGradient
            case .light:
                Color.white.ignoresSafeArea()
            case .dark:
                Color.black.ignoresSafeArea()
            }
        }
    }
    
    private var dynamicGradient: some View {
        ZStack {
            // Hauptgradient in subtilen Blautönen
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.07, blue: 0.18),
                    Color(red: 0.10, green: 0.12, blue: 0.25),
                    Color(red: 0.08, green: 0.10, blue: 0.20),
                    Color(red: 0.12, green: 0.08, blue: 0.22)
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

            // Eleganter blauer Glow-Effekt
            RadialGradient(
                colors: [
                    Color(red: 0.2, green: 0.3, blue: 0.6).opacity(0.4),
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
    }}
