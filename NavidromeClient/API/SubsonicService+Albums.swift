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
