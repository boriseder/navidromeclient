import SwiftUI

enum UserBackgroundStyle: String, CaseIterable {
    case dynamic
    case light
    case dark

    var dynamicTextColor: Color {
        switch self {
        case .light:
            return .black
        case .dynamic, .dark:
            return .white
        }
    }

    var dynamicBackgroundColor: Color {
        switch self {
        case .light:
            return .white
        case .dynamic, .dark:
            return .black
        }
    }
    
    var colorScheme: ColorScheme {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        case .dynamic:
            return .dark
        }
    }

}

enum UserAccentColor: String, CaseIterable, Identifiable {
    case red, orange, green, blue, purple, pink
    
    var id: String { rawValue }
    var color: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        }
    }
}
