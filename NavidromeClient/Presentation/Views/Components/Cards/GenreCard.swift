//
//  GenreCard.swift
//  NavidromeClient
//
//  Created by Boris Eder on 15.09.25.
//
import SwiftUI

// MARK: - Genre Card (Enhanced with DS)
struct GenreCard: View {
    let genre: Genre

    var body: some View {
        HStack(spacing: DSLayout.contentGap) {
            Circle()
                .fill(DSColor.background)
                .frame(width: DSLayout.buttonHeight, height: DSLayout.buttonHeight)
                .blur(radius: 1)
                .overlay(
                    Image(systemName: "music.note")
                        .foregroundColor(.primary)
                )
            
            VStack(alignment: .leading, spacing: DSLayout.tightGap) {
                Text(genre.value)
                    .font(DSText.emphasized)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: DSLayout.tightGap) {
                    Image(systemName: "record.circle")
                        .font(DSText.metadata)
                        .foregroundColor(.secondary)

                    let count = genre.albumCount
                    Text("\(count) Album\(count != 1 ? "s" : "")")
                        .font(DSText.metadata)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .listItemPadding()
        .cardStyle()
    }
}
