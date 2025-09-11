//
//  SubsonicService+Albums.swift
//  NavidromeClient
//
//  Created by Boris Eder on 04.09.25.
//

import Foundation

@MainActor
extension SubsonicService {
    func getAlbumsByGenre(genre: String) async throws -> [Album] {
        guard !genre.isEmpty else { return [] }
        let decoded: SubsonicResponse<AlbumListContainer> =
            try await fetchData(endpoint: "getAlbumList2",
                                params: ["type": "byGenre", "genre": genre],
                                type: SubsonicResponse<AlbumListContainer>.self)
        return decoded.subsonicResponse.albumList2.album
    }
}


// Neue Datei: SubsonicService+AllAlbums.swift
extension SubsonicService {
    // Neue Methode für alle Alben mit verschiedenen Sortierungen
    func getAllAlbums(sortBy: AlbumSortType = .alphabetical, size: Int = 500, offset: Int = 0) async throws -> [Album] {
        let params = [
            "type": sortBy.rawValue,
            "size": "\(size)",
            "offset": "\(offset)"
        ]
        
        // Prüfe Netzwerkverbindung
        guard NetworkMonitor.shared.isConnected else {
            throw SubsonicError.offline
        }
        
        let decoded: SubsonicResponse<AlbumListContainer> = try await fetchData(
            endpoint: "getAlbumList2",
            params: params,
            type: SubsonicResponse<AlbumListContainer>.self
        )
        
        let albums = decoded.subsonicResponse.albumList2.album
        print("✅ Loaded \(albums.count) albums sorted by \(sortBy.rawValue)")
        return albums
    }
    
    enum AlbumSortType: String, CaseIterable {
        case alphabetical = "alphabeticalByName"
        case alphabeticalByArtist = "alphabeticalByArtist"
        case newest = "newest"
        case recent = "recent"
        case frequent = "frequent"
        case random = "random"
        case byYear = "byYear"
        case byGenre = "byGenre"
        
        var displayName: String {
            switch self {
            case .alphabetical: return "A-Z (Name)"
            case .alphabeticalByArtist: return "A-Z (Artist)"
            case .newest: return "Newest"
            case .recent: return "Recently Played"
            case .frequent: return "Most Played"
            case .random: return "Random"
            case .byYear: return "By Year"
            case .byGenre: return "By Genre"
            }
        }
        
        var icon: String {
            switch self {
            case .alphabetical, .alphabeticalByArtist: return "textformat.abc"
            case .newest: return "sparkles"
            case .recent: return "clock"
            case .frequent: return "chart.bar"
            case .random: return "shuffle"
            case .byYear: return "calendar"
            case .byGenre: return "music.note.list"
            }
        }
    }
}

// Enhanced SubsonicError
extension SubsonicError {
    static let offline = SubsonicError.network(underlying: URLError(.notConnectedToInternet))
    
    var isOfflineError: Bool {
        switch self {
        case .network(let error):
            if let urlError = error as? URLError {
                return urlError.code == .notConnectedToInternet ||
                       urlError.code == .timedOut ||
                       urlError.code == .cannotConnectToHost
            }
            return false
        default:
            return false
        }
    }
}
