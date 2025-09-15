import SwiftUI

// MARK: - Genres
struct GenresContainer: Codable {
    let genres: GenreList?
}

struct GenreList: Codable {
    let genre: [Genre]?
}

struct Genre: Identifiable, Hashable, Codable {
    var id: String { value }
    let value: String
    let songCount: Int
    let albumCount: Int
}

