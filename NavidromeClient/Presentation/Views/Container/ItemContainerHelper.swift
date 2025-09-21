//
//  Helper.swift
//  NavidromeClient
//
//  Created by Boris Eder on 18.09.25.
//
import SwiftUI

// MARK: - Extension to CoverCardContent
// This extension handles the presentation logic based on the enum type
extension CardContent {
    var id: String {
        switch self {
        case .album(let album): return album.id
        case .artist(let artist): return artist.id
        case .genre(let genre): return genre.id
        }
    }
    
    var title: String {
        switch self {
        case .album(let album): return album.name
        case .artist(let artist): return artist.name
        case .genre(let genre): return genre.value
        }
    }
    
    var year: String? {
        switch self {
        case .album(let album):
            return album.year.map { String($0) }
        case .artist, .genre:
            return nil
        }
    }
    
    var subtitle: String {
        switch self {
        case .album(let album): return album.artist
        case .artist(let artist):
            guard let count = artist.albumCount else { return "" }
            return "\(count) Album\(count != 1 ? "s" : "")"
        case .genre(let genre):
            let count = genre.albumCount
            return "\(count) Album\(count != 1 ? "s" : "")"
        }
    }
    
    var iconName: String {
        switch self {
        case .album: return "music.note"
        case .artist: return "music.mic"
        case .genre: return "music.note"
        }
    }
    
    var hasChevron: Bool {
        switch self {
        case .album: return false
        default: return true
        }
    }
    
    var clipShape: some Shape {
        switch self {
        case .artist: return AnyShape(Circle())
        default: return AnyShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    // A simple helper to allow different shapes for clipShape
    private struct AnyShape: Shape {
        private let closure: (CGRect) -> Path

        init<S: Shape>(_ shape: S) {
            closure = { rect in
                shape.path(in: rect)
            }
        }

        func path(in rect: CGRect) -> Path {
            closure(rect)
        }
    }
}
