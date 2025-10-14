//
//  FavoritesStatsHeader.swift
//  NavidromeClient
//
//  Created by Boris Eder on 21.09.25.
//
import SwiftUI

struct FavoritesStatsHeader: View {
    @EnvironmentObject var favoritesManager: FavoritesManager
    
    var body: some View {
        let stats = favoritesManager.getFavoriteStats()
        
        HStack(spacing: DSLayout.elementGap) {
            VStack {
                Text("\(stats.songCount)")
                    .font(DSText.emphasized)
                    .foregroundStyle(DSColor.primary)
                
                Text("Songs")
                    .font(DSText.metadata)
                    .foregroundStyle(DSColor.secondary)
            }
            .frame(minWidth: 60)
            .padding(.vertical, DSLayout.elementPadding)

            Spacer()
            
            VStack {
                Text("\(stats.uniqueArtists)")
                    .font(DSText.emphasized)
                    .foregroundStyle(DSColor.primary)
                
                Text("Artists")
                    .font(DSText.metadata)
                    .foregroundStyle(DSColor.secondary)
            }
            .frame(minWidth: 60)
            .padding(.vertical, DSLayout.elementPadding)
            
            Spacer()
            
            VStack {
                Text("\(stats.uniqueAlbums)")
                    .font(DSText.emphasized)
                    .foregroundStyle(DSColor.primary)
                
                Text("Albums")
                    .font(DSText.metadata)
                    .foregroundStyle(DSColor.secondary)
            }
            .frame(minWidth: 60)
            .padding(.vertical, DSLayout.elementPadding)
            
            Spacer()
            
            VStack {
                Text("\(stats.formattedDurationShort)")
                    .font(DSText.emphasized)
                    .foregroundStyle(DSColor.primary)
                
                Text("Duration")
                    .font(DSText.metadata)
                    .foregroundStyle(DSColor.secondary)
            }
            .frame(minWidth: 60)
            .padding(.vertical, DSLayout.elementPadding)
        }
        .frame(maxWidth: .infinity) // volle Breite wie Song-Rows
        .background(
            DSMaterial.background
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
