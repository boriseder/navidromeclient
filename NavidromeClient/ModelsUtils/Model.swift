import Foundation

// MARK: - Generic Subsonic Response Wrapper
struct SubsonicResponse<T: Codable>: Codable {
    let subsonicResponse: T
    
    private enum CodingKeys: String, CodingKey {
        case subsonicResponse = "subsonic-response"
    }
}

struct PingInfo: Codable {
    let status: String
    let version: String
    let type: String
    let serverVersion: String
    let openSubsonic: Bool
}


// MARK: - Artists
struct ArtistsContainer: Codable {
    let artists: ArtistsIndex?
}

struct ArtistsIndex: Codable {
    let index: [ArtistIndex]?
}

struct ArtistIndex: Codable {
    let name: String
    let artist: [Artist]?
}

struct Artist: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let coverArt: String?
    let albumCount: Int?          // KORRIGIERT: Optional gemacht
    let artistImageUrl: String?   // HINZUGEFÜGT: Fehlendes Feld
    
    enum CodingKeys: String, CodingKey {
        case id, name, coverArt, albumCount, artistImageUrl
    }
}

// MARK: - Artist Detail (Albums by Artist)
struct ArtistDetailContainer: Codable {
    let artist: ArtistDetail
}

struct ArtistDetail: Codable {
    let id: String
    let name: String
    let album: [Album]?
}

// MARK: - Albums
struct AlbumListContainer: Codable {
    let albumList2: AlbumList
}

struct AlbumList: Codable {
    let album: [Album]
}

struct Album: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let artist: String
    let year: Int?
    let genre: String?
    let coverArt: String?
    let coverArtId: String?
    let duration: Int?
    let songCount: Int?
    let artistId: String?
    let displayArtist: String?
    
    enum CodingKeys: String, CodingKey {
        case id, artist, year, genre, duration, songCount, artistId, displayArtist
        case name = "name"
        case title = "title"
        case coverArt = "coverArt"
        case coverArtId = "albumArt"
    }
    
    // Custom Decoder um flexibel name/title zu handhaben
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        artist = try container.decode(String.self, forKey: .artist)
        
        // Flexibles Decoding: Versuche zuerst "title", dann "name"
        if let title = try container.decodeIfPresent(String.self, forKey: .title) {
            name = title
        } else {
            name = try container.decode(String.self, forKey: .name)
        }
        
        // Flexible coverArt Behandlung
        if let coverArt = try container.decodeIfPresent(String.self, forKey: .coverArt) {
            self.coverArt = coverArt
            self.coverArtId = nil
        } else {
            self.coverArt = try container.decodeIfPresent(String.self, forKey: .coverArtId)
            self.coverArtId = self.coverArt
        }
        
        // Alle anderen optionalen Felder
        year = try container.decodeIfPresent(Int.self, forKey: .year)
        genre = try container.decodeIfPresent(String.self, forKey: .genre)
        duration = try container.decodeIfPresent(Int.self, forKey: .duration)
        songCount = try container.decodeIfPresent(Int.self, forKey: .songCount)
        artistId = try container.decodeIfPresent(String.self, forKey: .artistId)
        displayArtist = try container.decodeIfPresent(String.self, forKey: .displayArtist)
    }
    
    // Custom Encoder falls nötig
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(artist, forKey: .artist)
        try container.encodeIfPresent(year, forKey: .year)
        try container.encodeIfPresent(genre, forKey: .genre)
        try container.encodeIfPresent(coverArt, forKey: .coverArt)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encodeIfPresent(songCount, forKey: .songCount)
        try container.encodeIfPresent(artistId, forKey: .artistId)
        try container.encodeIfPresent(displayArtist, forKey: .displayArtist)
    }
}

// MARK: - Album with Songs
struct AlbumWithSongsContainer: Codable {
    let album: AlbumWithSongs
}

struct AlbumWithSongs: Codable {
    let id: String
    let name: String
    let song: [Song]?
}

struct Song: Codable, Identifiable {
    let id: String
    let title: String
    let duration: Int?
    let coverArt: String?
    let artist: String?
    let album: String?
    let albumId: String?     // <- hinzufügen
    let track: Int?
    let year: Int?
    let genre: String?
    let artistId: String?
    let isVideo: Bool?
    let contentType: String?
    let suffix: String?
    let path: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, duration, coverArt, artist, album,albumId, track, year, genre, artistId, isVideo, contentType, suffix, path
    }
    
    // Custom initializer für flexible Dekodierung
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        duration = try container.decodeIfPresent(Int.self, forKey: .duration)
        coverArt = try container.decodeIfPresent(String.self, forKey: .coverArt)
        artist = try container.decodeIfPresent(String.self, forKey: .artist)
        album = try container.decodeIfPresent(String.self, forKey: .album)
        albumId = try container.decodeIfPresent(String.self, forKey: .albumId)
        track = try container.decodeIfPresent(Int.self, forKey: .track)
        year = try container.decodeIfPresent(Int.self, forKey: .year)
        genre = try container.decodeIfPresent(String.self, forKey: .genre)
        artistId = try container.decodeIfPresent(String.self, forKey: .artistId)
        isVideo = try container.decodeIfPresent(Bool.self, forKey: .isVideo)
        contentType = try container.decodeIfPresent(String.self, forKey: .contentType)
        suffix = try container.decodeIfPresent(String.self, forKey: .suffix)
        path = try container.decodeIfPresent(String.self, forKey: .path)
    }
}

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

// MARK: - Search
struct SearchContainer: Codable {
    let searchResult2: SearchResult2
}

struct SearchResult2: Codable {
    let artist: [Artist]?
    let album: [Album]?
    let song: [Song]?
}

// MARK: - SearchResult DTO (für Service)
struct SearchResult {
    let artists: [Artist]
    let albums: [Album]
    let songs: [Song]
}

// MARK: - Empty Response DTO (für Ping)
struct EmptyResponse: Codable {}
