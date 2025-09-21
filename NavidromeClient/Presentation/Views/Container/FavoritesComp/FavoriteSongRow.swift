//
//  FavoriteSongRow.swift
//  NavidromeClient
//
//  Created by Boris Eder on 21.09.25.
//
import SwiftUI

struct FavoriteSongRow: View {
    let song: Song
    let index: Int
    let isPlaying: Bool
    let onPlay: () -> Void
    let onToggleFavorite: () -> Void
    
    @State private var showingRemoveConfirmation = false
    
    var body: some View {
        HStack(spacing: DSLayout.elementGap) {
            
            // Song Cover + Playing Indicator
            ZStack(alignment: .bottomTrailing) {
                SongImageView(song: song, isPlaying: isPlaying)
                    .frame(width: DSLayout.miniCover, height: DSLayout.miniCover)
                    .cornerRadius(DSCorners.tight)
                
                if isPlaying {
                    EqualizerBars(isActive: true)
                        .frame(width: 16, height: 16)
                        .padding(4)
                        .background(DSColor.background.opacity(0.7))
                        .cornerRadius(4)
                }
            }
            
            VStack(alignment: .leading, spacing: DSLayout.tightGap / 2) {
                Text(song.title)
                    .font(isPlaying ? DSText.emphasized : DSText.body)
                    .foregroundStyle(isPlaying ? DSColor.playing : DSColor.primary)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    if let artist = song.artist {
                        Text(artist)
                            .font(DSText.metadata)
                            .foregroundStyle(DSColor.secondary)
                            .lineLimit(1)
                    }
                    if let artist = song.artist, let album = song.album {
                        Text("•")
                            .font(DSText.metadata)
                            .foregroundStyle(DSColor.secondary)
                    }
                    if let album = song.album {
                        Text(album)
                            .font(DSText.metadata)
                            .foregroundStyle(DSColor.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Duration + Heart Button
            HStack(spacing: DSLayout.elementGap / 2) {
                if let duration = song.duration, duration > 0 {
                    Text(formatDuration(duration))
                        .font(DSText.numbers)
                        .foregroundStyle(DSColor.secondary)
                        .monospacedDigit()
                }
                
                Button(action: {
                    showingRemoveConfirmation = true
                }) {
                    Image(systemName: "heart.fill")
                        .font(.title3)
                        .foregroundStyle(DSColor.error)
                        .padding(4)
                }
                .buttonStyle(.borderless)
                .confirmationDialog(
                    "Remove from Favorites?",
                    isPresented: $showingRemoveConfirmation
                ) {
                    Button("Remove", role: .destructive) {
                        onToggleFavorite()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will remove \"\(song.title)\" from your favorites.")
                }
            }
        }
        .padding(DSLayout.elementGap)
        .background(
            Color(DSColor.surfaceLight)
                .opacity(0.5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSCorners.tight)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
        .cornerRadius(DSCorners.tight)
        .contentShape(Rectangle())
        .onTapGesture {
            onPlay()
        }
        .animation(.easeInOut(duration: 0.2), value: isPlaying)
    }

    
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
