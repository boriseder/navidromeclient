//
//  CapsuleButton.swift
//  NavidromeClient
//
//  Created by Boris Eder on 22.09.25.
//
import SwiftUI

// MARK: - CapsuleButton Helper
struct CapsuleButton: View {
    let title: String
    let systemImage: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(color)
            .clipShape(Capsule())
            .shadow(radius: 4)
        }
    }
}
