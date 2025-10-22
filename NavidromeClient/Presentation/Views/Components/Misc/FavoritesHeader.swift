//
//  FavoritesStatsHeader.swift
//  NavidromeClient
//
//  Created by Boris Eder on 21.09.25.
//
import SwiftUI

struct FavoritesStatsHeader: View {
    @EnvironmentObject var favoritesManager: FavoritesManager
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        let stats = favoritesManager.getFavoriteStats()
        
        HStack(spacing: DSLayout.contentGap) {
            VStack {
                Text("\(stats.songCount)")
                    .font(DSText.emphasized)
                    .foregroundStyle(theme.textColor)
                
                Text("Songs")
                    .font(DSText.metadata)
                    .foregroundStyle(theme.textColor)
            }
            .frame(minWidth: 60)
            .padding(.vertical, DSLayout.elementPadding)

            Divider()
            
            VStack {
                Text("\(stats.uniqueArtists)")
                    .font(DSText.emphasized)
                    .foregroundStyle(theme.textColor)
                
                Text("Artists")
                    .font(DSText.metadata)
                    .foregroundStyle(theme.textColor)
            }
            .frame(minWidth: 60)
            .padding(.vertical, DSLayout.elementPadding)
            
            Divider()
            
            VStack {
                Text("\(stats.uniqueAlbums)")
                    .font(DSText.emphasized)
                    .foregroundStyle(theme.textColor)
                
                Text("Albums")
                    .font(DSText.metadata)
                    .foregroundStyle(theme.textColor)
            }
            .frame(minWidth: 60)
            .padding(.vertical, DSLayout.elementPadding)
            
            Divider()
            
            VStack {
                Text("\(stats.formattedDurationShort)")
                    .font(DSText.emphasized)
                    .foregroundStyle(theme.textColor)
                
                Text("Duration")
                    .font(DSText.metadata)
                    .foregroundStyle(theme.textColor)
            }
            .frame(minWidth: 60)
            .padding(.vertical, DSLayout.elementPadding)
        }
        .frame(maxWidth: .infinity) // volle Breite wie Song-Rows
        .background(
            theme.backgroundContrastColor.opacity(0.05)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSCorners.element)
                .stroke(theme.backgroundContrastColor, lineWidth: 0.1)
        )
        .shadow(radius:DSCorners.element, y: 4)
        .cornerRadius(DSCorners.element)
    }
}

extension FavoriteStats {
    // kompakte Duration, z.B. "3h 25m" statt lang
    var formattedDurationShort: String {
        let totalMinutes = Int(totalDuration / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
