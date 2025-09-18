//
//  HelperExtension.swift
//  NavidromeClient
//
//  Created by Boris Eder on 18.09.25.
//

import SwiftUI

// MARK: - Helper Extensions
public extension View {
    @ViewBuilder
    func conditionalSearchable(searchText: Binding<String>?, prompt: String?) -> some View {
        if let searchText = searchText {
            self.searchable(
                text: searchText,
                placement: .automatic,
                prompt: prompt ?? "Search..."
            )
        } else {
            self
        }
    }
}

