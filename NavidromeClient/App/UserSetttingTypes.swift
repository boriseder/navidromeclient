//
//  UserBackgroundStyle.swift
//  NavidromeClient
//
//  Created by Boris Eder on 30.09.25.
//
import SwiftUI

enum UserBackgroundStyle: String, CaseIterable {
    case dynamic
    case light
    case dark
    
    var textColor: Color {
        switch self {
        case .dynamic, .dark:
            return .white
        case .light:
            return .black
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
