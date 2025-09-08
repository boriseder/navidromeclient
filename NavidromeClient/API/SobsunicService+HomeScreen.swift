//
//  SubsonicService+Albums.swift
//  NavidromeClient
//
//  Created by Boris Eder on 04.09.25.
//

import Foundation

@MainActor
extension SubsonicService {
    enum AlbumListType: String {
        case recent = "recent"
        case newest = "newest"
        case frequent = "frequent"
        case random = "random"
        case byGenre = "byGenre"
    }
    
/*    func getAlbumsByGenre(genre: String) async throws -> [Album] {
        guard !genre.isEmpty else { return [] }
        let decoded: SubsonicResponse<AlbumListContainer> =
            try await fetchData(endpoint: "getAlbumList2",
                                params: ["type": "byGenre", "genre": genre],
                                type: SubsonicResponse<AlbumListContainer>.self)
        return decoded.subsonicResponse.albumList2.album
    }
 */
    func getAlbumList(type: AlbumListType, size: Int = 20, offset: Int = 0) async throws -> [Album] {
        var params = ["type": type.rawValue, "size": "\(size)", "offset": "\(offset)"]
        
        let decoded: SubsonicResponse<AlbumListContainer> =
            try await fetchData(endpoint: "getAlbumList2",
                                params: params,
                                type: SubsonicResponse<AlbumListContainer>.self)
        return decoded.subsonicResponse.albumList2.album
    }
    
    // Convenience methods for specific types
    func getRecentAlbums(size: Int = 20) async throws -> [Album] {
        return try await getAlbumList(type: .recent, size: size)
    }
    
    func getNewestAlbums(size: Int = 20) async throws -> [Album] {
        return try await getAlbumList(type: .newest, size: size)
    }
    
    func getFrequentAlbums(size: Int = 20) async throws -> [Album] {
        return try await getAlbumList(type: .frequent, size: size)
    }
    
    func getRandomAlbums(size: Int = 20) async throws -> [Album] {
        return try await getAlbumList(type: .random, size: size)
    }
}
