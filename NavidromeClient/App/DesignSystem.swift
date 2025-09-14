//
//  DesignSystem.swift - Enhanced Version
//  NavidromeClient
//
//  Enhanced with missing values from app analysis
//

import SwiftUI

// MARK: - Spacing (zwischen Views, Layouts)
// Verwendung: VStack/HStack spacing, List Abstände
enum Spacing {
    static let xs: CGFloat = 4      // sehr kleine Abstände, z.B. Icon/Badge spacing
    static let s: CGFloat = 8       // kleine Abstände, z.B. Icon/Text im Button
    static let m: CGFloat = 16      // Standard-Abstände zwischen Elementen
    static let l: CGFloat = 24      // größere Blöcke, Sections
    static let xl: CGFloat = 32     // Screen Margins, große Trenner
    static let xxl: CGFloat = 40    // sehr große Abstände, zwischen major sections
}

// MARK: - Padding (innerhalb von Komponenten)
// Verwendung: Button-Inhalt, Card-Inhalt, Text Container
enum Padding {
    static let xs: CGFloat = 4      // sehr kleine Inhalte
    static let s: CGFloat = 8       // kleine Inhalte
    static let m: CGFloat = 16      // Standard-Padding
    static let l: CGFloat = 24      // große Inhalte
    static let xl: CGFloat = 32     // sehr große Inhalte
}

// MARK: - Radius / Corner Rounding
enum Radius {
    static let xs: CGFloat = 3      // AlbumCover, kleine Elemente
    static let s: CGFloat = 8       // Standard kleine Radius
    static let m: CGFloat = 16      // Standard mittlere Radius
    static let l: CGFloat = 24      // große Radius
    static let xl: CGFloat = 32     // sehr große Radius
    static let circle: CGFloat = 50 // für runde Buttons/Avatare
}

// MARK: - Sizes (Kern-Dimensionen)
enum Sizes {
    // Cards & Images
    static let cardSmall: CGFloat = 60     // kleine Cards, Mini-Cover
    static let card: CGFloat = 140         // Standard Album Cards
    static let cardLarge: CGFloat = 200    // große Cards
    
    // Avatars & Icons
    static let iconSmall: CGFloat = 16     // kleine Icons
    static let icon: CGFloat = 24          // Standard Icons
    static let iconLarge: CGFloat = 32     // große Icons
    static let avatar: CGFloat = 72        // User Avatare
    static let avatarLarge: CGFloat = 100  // große Avatare
    
    // Cover Art
    static let coverMini: CGFloat = 50     // MiniPlayer
    static let coverSmall: CGFloat = 70    // Listen
    static let cover: CGFloat = 300        // Detail Views
    static let coverFull: CGFloat = 400    // Full Screen
    
    // UI Elements
    static let buttonHeight: CGFloat = 44   // Standard Button Höhe
    static let tabBar: CGFloat = 90        // Tab Bar Höhe
    static let miniPlayer: CGFloat = 90    // Mini Player Höhe
    static let searchBar: CGFloat = 44     // Search Bar Höhe
    
    // Layout
    static let screenPadding: CGFloat = 16  // Standard Screen Padding
    static let maxContentWidth: CGFloat = 400 // Max Content Width
}

// MARK: - Typography / Fonts
enum Typography {
    // Headers
    static let largeTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let title = Font.system(.title, design: .rounded).weight(.bold)
    static let title2 = Font.system(.title2, design: .rounded).weight(.semibold)
    static let title3 = Font.system(.title3, design: .rounded).weight(.semibold)
    
    // Content
    static let headline = Font.headline.weight(.semibold)
    static let subheadline = Font.subheadline.weight(.medium)
    static let body = Font.body
    static let bodyEmphasized = Font.body.weight(.medium)
    static let callout = Font.callout
    
    // Small Text
    static let caption = Font.caption
    static let caption2 = Font.caption2
    static let footnote = Font.footnote
    
    // Special Purpose
    static let button = Font.callout.weight(.semibold)
    static let buttonLarge = Font.headline.weight(.semibold)
    static let monospacedNumbers = Font.body.monospacedDigit()
    
    // Legacy (für Kompatibilität)
    static let sectionTitle = Font.headline.weight(.semibold)
}

// MARK: - Text Colors
enum TextColor {
    static let primary = Color.primary
    static let secondary = Color.secondary
    static let tertiary = Color(.tertiaryLabel)
    static let quaternary = Color(.quaternaryLabel)
    static let inverse = Color(.systemBackground)
    
    // Contextual
    static let onDark = Color.white
    static let onLight = Color.black
    static let onDarkSecondary = Color.white.opacity(0.7)
    static let onLightSecondary = Color.black.opacity(0.7)
}

// MARK: - Brand & Status Colors
enum BrandColor {
    static let primary = Color.accentColor
    static let secondary = Color(.systemBlue)
    
    // Status
    static let success = Color(.systemGreen)
    static let warning = Color(.systemOrange)
    static let error = Color(.systemRed)
    static let info = Color(.systemBlue)
    
    // Music App Specific
    static let playing = Color(.systemBlue)
    static let offline = Color(.systemOrange)
    static let downloaded = Color(.systemGreen)
}

// MARK: - Background Colors
enum BackgroundColor {
    static let primary = Color(.systemBackground)
    static let secondary = Color(.secondarySystemBackground)
    static let tertiary = Color(.tertiarySystemBackground)
    
    // Materials
    static let thin: Material = .ultraThin
    static let regular: Material = .regular
    static let thick: Material = .thick

    // Overlays
    static let overlay = Color.black.opacity(0.4)
    static let overlayLight = Color.black.opacity(0.2)
    static let overlayHeavy = Color.black.opacity(0.6)
}

// MARK: - Enhanced Shadows
extension View {
    func cardShadow() -> some View {
        self.shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
    
    func buttonShadow() -> some View {
        self.shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
    
    func miniShadow() -> some View {
        self.shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    func largeShadow() -> some View {
        self.shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 10)
    }
    
    func glowShadow(color: Color = .blue) -> some View {
        self.shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Enhanced Component Styles
extension View {
    func cardStyle() -> some View {
        self
            .clipShape(RoundedRectangle(cornerRadius: Radius.m))
            .cardShadow()
    }
    
    func miniCardStyle() -> some View {
        self
            .clipShape(RoundedRectangle(cornerRadius: Radius.s))
            .miniShadow()
    }
    
    func largeCardStyle() -> some View {
        self
            .clipShape(RoundedRectangle(cornerRadius: Radius.l))
            .largeShadow()
    }
    
    func avatarStyle() -> some View {
        self
            .clipShape(Circle())
            .cardShadow()
    }
    
    func primaryButtonStyle() -> some View {
        self
            .padding(.horizontal, Padding.m)
            .padding(.vertical, Padding.s)
            .background(BrandColor.primary, in: Capsule())
            .foregroundStyle(TextColor.inverse)
            .buttonShadow()
    }
    
    func secondaryButtonStyle() -> some View {
        self
            .padding(.horizontal, Padding.m)
            .padding(.vertical, Padding.s)
            .background(BackgroundColor.regular, in: Capsule())
            .foregroundStyle(TextColor.primary)
    }
    
    func compactButtonStyle() -> some View {
        self
            .padding(.horizontal, Padding.s)
            .padding(.vertical, Padding.xs)
            .background(BrandColor.primary, in: Capsule())
            .foregroundStyle(TextColor.inverse)
    }
    
    func iconButtonStyle() -> some View {
        self
            .frame(width: Sizes.buttonHeight, height: Sizes.buttonHeight)
            .background(BackgroundColor.regular, in: Circle())
            .foregroundStyle(TextColor.primary)
    }
    
    func materialCardStyle() -> some View {
        self
            .background(BackgroundColor.regular, in: RoundedRectangle(cornerRadius: Radius.m))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.m)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
    
    func glassCardStyle() -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.m))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.m)
                    .stroke(.white.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Layout Helpers
extension View {
    func screenPadding() -> some View {
        self.padding(.horizontal, Sizes.screenPadding)
    }
    
    func sectionSpacing() -> some View {
        self.padding(.vertical, Spacing.l)
    }
    
    func listItemPadding() -> some View {
        self.padding(.horizontal, Padding.m)
            .padding(.vertical, Padding.s)
    }
    
    func maxContentWidth() -> some View {
        self.frame(maxWidth: Sizes.maxContentWidth)
    }
}

// MARK: - Animations (Enhanced)
enum Animations {
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.8)
    static let springSnappy = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let ease = Animation.easeInOut(duration: 0.2)
    static let easeQuick = Animation.easeInOut(duration: 0.1)
    static let easeSlow = Animation.easeInOut(duration: 0.4)
    
    // Interactive
    static let interactive = Animation.interactiveSpring()
    static let bounce = Animation.spring(response: 0.6, dampingFraction: 0.6)
}

// MARK: - Grid Helpers
enum GridColumns {
    static let two = Array(repeating: GridItem(.flexible(), spacing: Spacing.m), count: 2)
    static let three = Array(repeating: GridItem(.flexible(), spacing: Spacing.s), count: 3)
    static let four = Array(repeating: GridItem(.flexible(), spacing: Spacing.s), count: 4)
}

/*
 ENHANCED USAGE EXAMPLES:
 
 // Typography
 Text("Album Name")
     .font(Typography.title3)
     .foregroundColor(TextColor.primary)
 
 // Layouts
 VStack(spacing: Spacing.m) {
     Text("Title")
     Text("Subtitle")
 }
 .screenPadding()
 
 // Cards
 AlbumCoverView()
     .frame(width: Sizes.card, height: Sizes.card)
     .cardStyle()
 
 // Buttons
 Button("Play") { ... }
     .primaryButtonStyle()
 
 // Grid
 LazyVGrid(columns: GridColumns.two, spacing: Spacing.m) {
     // Album cards
 }
 
 // Materials
 VStack { ... }
     .materialCardStyle()
     .screenPadding()
*/
