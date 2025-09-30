//
//  SongDurationView.swift
//  NavidromeClient
//
//  Created by Boris Eder on 21.09.25.
//
import SwiftUI

struct SongDurationView: View {
    let duration: Int?
    
    private var formattedDuration: String {
        let duration = duration ?? 0
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var body: some View {
        VStack(alignment: .trailing, spacing: DSLayout.tightGap) {
            Text(formattedDuration)
                .font(DSText.numbers)
                .foregroundStyle(DSColor.secondary)
                .monospacedDigit()
            
            Image(systemName: "music.note")
                .font(DSText.body)
                .foregroundStyle(DSColor.quaternary)
        }
    }
}
