//
//  DebugLines.swift
//  NavidromeClient
//
//  Created by Boris Eder on 25.09.25.
//

import SwiftUI

struct DebugLines: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.blue)
                .frame(width: 1)
                .frame(maxHeight: .infinity)
                .padding(.trailing, 20) // Abstand vom rechten Rand
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .overlay(
            Rectangle()
                .fill(Color.red)
                .frame(width: 1)
                .ignoresSafeArea()     // auch über NavigationTitle & Statusbar
                .padding(.leading, 20),
            alignment: .leading
        )
            .overlay(
                Rectangle()
                    .fill(Color.green)
                    .frame(height: 1)               // dünne Linie
                    .frame(maxWidth: .infinity)     // über ganze Breite
                    .position(x: UIScreen.main.bounds.width / 2, y: 130)
            )
            .overlay(
                Rectangle()
                    .fill(Color.green)
                    .frame(height: 1)               // dünne Linie
                    .frame(maxWidth: .infinity)     // über ganze Breite
                    .position(x: UIScreen.main.bounds.width / 2, y: 170)
            )

    }
}

