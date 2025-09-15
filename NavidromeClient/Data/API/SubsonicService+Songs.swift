//
//  SubsonicService+Songs.swift
//  NavidromeClient
//
//  Created by Boris Eder on 04.09.25.
//
import Foundation

@MainActor
extension SubsonicService {
    func getSongs(for albumId: String) async throws -> [Song] {
        guard !albumId.isEmpty else { return [] }
        let decoded: SubsonicResponse<AlbumWithSongsContainer> =
            try await fetchData(endpoint: "getAlbum",
                                params: ["id": albumId],
                                type: SubsonicResponse<AlbumWithSongsContainer>.self)
        return decoded.subsonicResponse.album.song ?? []
    }
}
