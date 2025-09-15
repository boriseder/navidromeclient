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
        HStack(spacing: Spacing.m) {
            Circle()
                .fill(BackgroundColor.medium)
                .frame(width: Sizes.buttonHeight, height: Sizes.buttonHeight)
                .blur(radius: 1)
                .overlay(
                    Image(systemName: "music.note")
                        .foregroundStyle(TextColor.primary)
                )
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(genre.value)
                    .font(Typography.bodyEmphasized)
                    .foregroundColor(TextColor.primary)
                    .lineLimit(1)

                HStack(spacing: Spacing.xs) {
                    Image(systemName: "record.circle")
                        .font(Typography.caption)
                        .foregroundColor(TextColor.secondary)

                    let count = genre.albumCount
                    Text("\(count) Album\(count != 1 ? "s" : "")")
                        .font(Typography.caption)
                        .foregroundColor(TextColor.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(TextColor.tertiary)
        }
        .listItemPadding()
        .materialCardStyle()
    }
}
