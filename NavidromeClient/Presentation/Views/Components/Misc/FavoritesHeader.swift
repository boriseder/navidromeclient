//
//  FavoritesStatsHeader.swift
//  NavidromeClient
//
//  Created by Boris Eder on 21.09.25.
//
import SwiftUI

struct FavoritesStatsHeader: View {
    @StateObject private var favoritesManager = FavoritesManager.shared
    
    var body: some View {
        let stats = favoritesManager.getFavoriteStats()
        
        HStack(spacing: DSLayout.elementGap) {
            StatsItem(
                icon: "music.note",
                value: "\(stats.songCount)",
                label: "Songs"
            )
            
            Spacer()
            
            StatsItem(
                icon: "person.2",
                value: "\(stats.uniqueArtists)",
                label: "Artists"
            )
            
            Spacer()
            
            StatsItem(
                icon: "record.circle",
                value: "\(stats.uniqueAlbums)",
                label: "Albums"
            )
            
            Spacer()
            
            StatsItem(
                icon: "clock",
                value: stats.formattedDurationShort,
                label: "Duration"
            )
        }
        .frame(maxWidth: .infinity) // volle Breite wie Song-Rows
        .background(
            Color(DSColor.background)
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
