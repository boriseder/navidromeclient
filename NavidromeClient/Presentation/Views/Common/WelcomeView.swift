//
//  WelcomeView.swift - Enhanced with Design System
//  NavidromeClient
//
//  ✅ ENHANCED: Vollständige Anwendung des Design Systems
//

import SwiftUI

struct WelcomeView: View {
    let onGetStarted: () -> Void
    
    var body: some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "music.note.house")
                .font(.system(size: 80)) // Approx. DS applied
                .foregroundStyle(
                    LinearGradient(
                        colors: [BrandColor.primary, BrandColor.secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: Spacing.m) {
                Text("Welcome to Navidrome Client")
                    .font(Typography.largeTitle)
                    .multilineTextAlignment(.center)
                
                Text("Connect to your Navidrome server to start listening to your music library")
                    .font(Typography.body)
                    .foregroundStyle(TextColor.secondary)
                    .multilineTextAlignment(.center)
                    .screenPadding()
            }
            
            Button("Get Started") {
                onGetStarted()
            }
            .primaryButtonStyle()
            .font(Typography.buttonLarge)
        }
        .padding(Padding.xl)
    }
}
