//
//  DesignSystemMinimal.swift
//  NavidromeClient
//
//  Minimal & konsistent für Musik-App
//  💡 Kommentare enthalten: wie man die Tokens anwendet
//

import SwiftUI

// MARK: - Spacing (zwischen Views, Layouts)
// Verwendung: VStack/HStack spacing, List Abstände
enum Spacing {
    static let s: CGFloat = 8       // kleine Abstände, z.B. Icon/Text im Button
    static let m: CGFloat = 16      // Standard-Abstände zwischen Elementen
    static let l: CGFloat = 24      // größere Blöcke, Sections
    static let xl: CGFloat = 32     // Screen Margins, große Trenner
}

/*
 Anwendung:
 VStack(spacing: Spacing.m) {
     Text("Titel")
     Text("Untertitel")
 }
 */

// MARK: - Padding (innerhalb von Komponenten)
// Verwendung: Button-Inhalt, Card-Inhalt, Text Container
enum Padding {
    static let s: CGFloat = 8
    static let m: CGFloat = 16
    static let l: CGFloat = 24
}

/*
 Anwendung:
 Button("Play") { ... }
     .padding(.horizontal, Padding.m)
     .padding(.vertical, Padding.s)
 */

// MARK: - Radius / Corner Rounding
enum Radius {
    static let s: CGFloat = 8
    static let m: CGFloat = 16
    static let l: CGFloat = 24
}

/*
 Anwendung:
 RoundedRectangle(cornerRadius: Radius.m)
 */

// MARK: - Sizes (Kern-Dimensionen)
enum Sizes {
    static let card: CGFloat = 140
    static let avatar: CGFloat = 72
    static let cover: CGFloat = 300
    static let tabBar: CGFloat = 90
}

/*
 Anwendung:
 Image("Cover")
     .frame(width: Sizes.cover, height: Sizes.cover)
 */

// MARK: - Typography / Fonts
enum Typography {
    static let title = Font.system(.title2, design: .rounded).weight(.semibold)
    static let sectionTitle = Font.headline.weight(.semibold)
    static let body = Font.body
    static let caption = Font.caption
    static let button = Font.callout.weight(.semibold)
}

/*
 Anwendung:
 Text("Album Name")
     .font(Typography.sectionTitle)
 */

// MARK: - Text Colors
enum TextColor {
    static let primary = Color.primary
    static let secondary = Color.secondary
    static let tertiary = Color(.tertiaryLabel)
    static let inverse = Color(.systemBackground)
}

/*
 Anwendung:
 Text("Play")
     .foregroundColor(TextColor.primary)
 */

// MARK: - Brand & Status Colors
enum BrandColor {
    static let primary = Color.accentColor
    static let secondary = Color(.systemBlue)
    static let success = Color(.systemGreen)
    static let warning = Color(.systemOrange)
    static let error = Color(.systemRed)
}

/*
 Anwendung:
 Button("Play") { ... }
     .background(BrandColor.primary)
 */

// MARK: - Shadows
extension View {
    func cardShadow() -> some View {
        self.shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
    
    func buttonShadow() -> some View {
        self.shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}

/*
 Anwendung:
 VStack { ... }
     .cardShadow()
 */

// MARK: - Component Styles
extension View {
    func cardStyle() -> some View {
        self
            .clipShape(RoundedRectangle(cornerRadius: Radius.m))
            .cardShadow()
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
            .background(.ultraThinMaterial, in: Capsule())
            .foregroundStyle(TextColor.primary)
    }
}

/*
 Anwendung:
 Button("Play") { ... }
     .primaryButtonStyle()

 Button("Shuffle") { ... }
     .secondaryButtonStyle()
 */

// MARK: - Animations
enum Animations {
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.8)
    static let ease = Animation.easeInOut(duration: 0.2)
}

/*
 Anwendung:
 withAnimation(Animations.spring) {
     isExpanded.toggle()
 }
 */
