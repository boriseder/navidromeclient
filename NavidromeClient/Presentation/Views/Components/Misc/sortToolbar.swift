//
//  sortToolbar.swift
//  NavidromeClient
//
//  Created by Boris Eder on 30.09.25.
//

import SwiftUI

struct sortToolbar: View {
    var body: some View {
        HStack {
            Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
        }
        .toolbar{
            SortMenuButton("",)
        }
    }
}

private struct SortMenuButton: View {
    
    let current: String
    let options: [SortOption]
    let onSelect: (SortOption) -> Void
    
    private var currentOption: SortOption? {
        options.first { $0.id == current }
    }
    
    var body: some View {
        Menu {
            ForEach(options) { option in
                Button {
                    onSelect(option)
                } label: {
                    HStack {
                        if let icon = option.icon.isEmpty ? nil : option.icon {
                            Image(systemName: icon)
                        }
                        Text(option.displayName)
                        if option.id == current {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: currentOption?.icon ?? "line.3.horizontal.decrease")
                .foregroundColor(.primary)
        }
    }
}

struct SortOption: Identifiable, Hashable {
    let id: String
    let displayName: String
    let icon: String
    
    init(id: String, displayName: String, icon: String) {
        self.id = id
        self.displayName = displayName
        self.icon = icon
    }
}

// MARK: - 8. Sort Configuration Helpers

private func getSortDisplayName<T>(_ sortType: T) -> String where T: RawRepresentable, T.RawValue == String {
    // This would need to be implemented based on your actual sort types
    if let albumSort = sortType as? ContentService.AlbumSortType {
        return albumSort.displayName
    }
}

private func getSortIcon<T>(_ sortType: T) -> String where T: RawRepresentable, T.RawValue == String {
    if let albumSort = sortType as? ContentService.AlbumSortType {
        return albumSort.icon
    }
    
    // Fallback icon
    return "line.3.horizontal.decrease"
}


#Preview {
    sortToolbar()
}
