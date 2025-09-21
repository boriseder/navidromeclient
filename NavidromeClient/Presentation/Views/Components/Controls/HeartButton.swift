//
//  HeartButton.swift
//  NavidromeClient
//
//  Created by Boris Eder on 21.09.25.
//


//
//  HeartButton.swift - Wiederverwendbare Herz-Komponente
//  NavidromeClient
//
//  REUSABLE: Für MiniPlayer, FullScreenPlayer und SongRows
//

import SwiftUI

struct HeartButton: View {
    let song: Song
    let size: HeartButtonSize
    let style: HeartButtonStyle
    
    @StateObject private var favoritesManager = FavoritesManager.shared
    
    @State private var isAnimating = false
    
    enum HeartButtonSize {
        case small    // 16pt - für SongRows
        case medium   // 20pt - für MiniPlayer
        case large    // 24pt - für FullScreenPlayer
        
        var iconSize: CGFloat {
            switch self {
            case .small: return 16
            case .medium: return 20
            case .large: return 24
            }
        }
        
        var font: Font {
            return .system(size: iconSize, weight: .medium)
        }
    }
    
    enum HeartButtonStyle {
        case minimal      // Nur Icon
        case withHaptic   // Icon + Haptic Feedback
        case prominent    // Icon + Animation + Haptic
        
        var hasHaptic: Bool {
            switch self {
            case .minimal: return false
            case .withHaptic, .prominent: return true
            }
        }
        
        var hasAnimation: Bool {
            switch self {
            case .minimal, .withHaptic: return false
            case .prominent: return true
            }
        }
    }
    
    var body: some View {
        Button(action: toggleFavorite) {
            ZStack {
                // Background pulse für Animation
                if style.hasAnimation && isAnimating {
                    Circle()
                        .fill(DSColor.error.opacity(0.3))
                        .scaleEffect(isAnimating ? 1.2 : 0.8)
                        .opacity(isAnimating ? 0 : 1)
                        .animation(.easeOut(duration: 0.6), value: isAnimating)
                }
                
                // Heart Icon
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(size.font)
                    .foregroundStyle(isFavorite ? DSColor.error : DSColor.secondary)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isAnimating)
            }
        }
        .disabled(favoritesManager.isLoading)
    }
    
    // MARK: - Computed Properties
    
    private var isFavorite: Bool {
        return favoritesManager.isFavorite(song.id)
    }
    
    // MARK: - Actions
    
    private func toggleFavorite() {
        if style.hasHaptic {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
        
        if style.hasAnimation {
            withAnimation {
                isAnimating = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    isAnimating = false
                }
            }
        }
        
        Task {
            await favoritesManager.toggleFavorite(song)
        }
    }
}

// MARK: - Convenience Initializers

extension HeartButton {
    /// Für SongRows in Listen
    static func songRow(song: Song) -> HeartButton {
        HeartButton(song: song, size: .small, style: .withHaptic)
    }
    
    /// Für MiniPlayer
    static func miniPlayer(song: Song) -> HeartButton {
        HeartButton(song: song, size: .medium, style: .withHaptic)
    }
    
    /// Für FullScreenPlayer
    static func fullScreen(song: Song) -> HeartButton {
        HeartButton(song: song, size: .large, style: .prominent)
    }
}
