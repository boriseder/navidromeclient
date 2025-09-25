//
//  StatsItem.swift
//  NavidromeClient
//
//  Created by Boris Eder on 21.09.25.
//
import SwiftUI

struct StatsItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(DSText.body)
                .foregroundStyle(DSColor.accent)
            
            Text(value)
                .font(DSText.emphasized)
                .foregroundStyle(DSColor.primary)
            
            Text(label)
                .font(DSText.metadata)
                .foregroundStyle(DSColor.secondary)
        }
        .frame(minWidth: 60)
        .padding(.vertical, DSLayout.elementPadding)
    }
}
