//
//  DynamicMusicBackground.swift
//  NavidromeClient
//
//  Created by Boris Eder on 04.09.25.
//


//
//  DynamicMusicBackground.swift
//  NavidromeClient
//
//  Created by Boris Eder on 04.09.25.
//

import SwiftUI

struct DynamicMusicBackground: View {
    @State private var rotation = 0.0
    @State private var scale = 1.0
    @State private var offset = CGSize.zero
    @State private var animationPhase = 0.0
    
    let colors = [
        Color.purple.opacity(0.5),
        Color.blue.opacity(0.4),
        Color.cyan.opacity(0.6),
        Color.mint.opacity(0.4),
        Color.teal.opacity(0.3),
        Color.indigo.opacity(0.4)
    ]
    
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color.black.opacity(0.05),
                    Color.white.opacity(0.95),
                    Color.black.opacity(0.02)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Animated circles
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                colors[index],
                                colors[index].opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 150
                        )
                    )
                    .frame(width: 200 + Double(index) * 30, height: 200 + Double(index) * 30)
                    .offset(
                        x: cos(animationPhase + Double(index) * 0.5) * 100,
                        y: sin(animationPhase + Double(index) * 0.7) * 80
                    )
                    .rotationEffect(.degrees(rotation + Double(index) * 60))
                    .scaleEffect(scale + sin(animationPhase + Double(index)) * 0.1)
                    .blur(radius: 20 + Double(index) * 5)
                    .opacity(0.6)
            }
            
            // Floating particles
            ForEach(0..<12, id: \.self) { index in
                Circle()
                    .fill(colors[index % colors.count].opacity(0.4))
                    .frame(width: 4 + Double(index % 3) * 2, height: 4 + Double(index % 3) * 2)
                    .offset(
                        x: cos(animationPhase * 0.3 + Double(index) * 0.8) * 200,
                        y: sin(animationPhase * 0.2 + Double(index) * 1.2) * 150
                    )
                    .blur(radius: 1)
                    .opacity(0.8)
            }
            
            // Noise texture overlay
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.02),
                            Color.black.opacity(0.01),
                            Color.white.opacity(0.015)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .ignoresSafeArea()
                .blendMode(.overlay)
        }
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                scale = 1.2
            }
            withAnimation(.linear(duration: 15).repeatForever(autoreverses: false)) {
                animationPhase = .pi * 2
            }
        }
    }
}

