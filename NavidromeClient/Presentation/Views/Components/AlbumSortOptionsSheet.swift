//
//  AlbumSortOptionsSheet.swift
//  NavidromeClient
//
//  Created by Boris Eder on 11.09.25.
//


import SwiftUI

// MARK: - Sort Options Sheet
struct AlbumSortOptionsSheet: View {
    @Binding var selectedSort: SubsonicService.AlbumSortType
    let isOnline: Bool
    let onSortChanged: (SubsonicService.AlbumSortType) -> Void
    @Environment(\.dismiss) private var dismiss
    
    // Offline verfügbare Sortierungen (lokale Sortierung)
    private var availableSorts: [SubsonicService.AlbumSortType] {
        if isOnline {
            return SubsonicService.AlbumSortType.allCases
        } else {
            // Offline nur lokale Sortierungen
            return [.alphabetical, .alphabeticalByArtist]
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(availableSorts, id: \.self) { sortType in
                    Button {
                        selectedSort = sortType
                        onSortChanged(sortType)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: sortType.icon)
                                .foregroundStyle(.blue)
                                .frame(width: 24)
                            
                            Text(sortType.displayName)
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            if selectedSort == sortType {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .disabled(!isOnline && ![.alphabetical, .alphabeticalByArtist].contains(sortType))
                }
            }
            .navigationTitle("Sort Albums")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}