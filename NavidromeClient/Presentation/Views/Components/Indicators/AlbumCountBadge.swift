//
//  AlbumCountBadge.swift
//  NavidromeClient
//
//  Created by Boris Eder on 18.09.25.
//
import SwiftUI

struct AlbumCountBadge: View {
    let count: Int
    let label: String
    let color: Color
    
    var body: some View {
        Text("\(count) \(label) Album\(count != 1 ? "s" : "")")
            .font(DSText.metadata)
            .foregroundStyle(color)
            .padding(.horizontal, DSLayout.elementPadding)
            .padding(.vertical, DSLayout.tightPadding)
            .background(color.opacity(0.1), in: Capsule())
            .overlay(
                Capsule().stroke(color.opacity(0.3), lineWidth: 1)
            )
    }
}
