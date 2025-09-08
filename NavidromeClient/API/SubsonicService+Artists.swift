//
//  SubSonicServiceArtist.swift
//  NavidromeClient
//
//  Created by Boris Eder on 04.09.25.
//


import Foundation

@MainActor
extension SubsonicService {
    func getArtists() async throws -> [Artist] {
        let decoded: SubsonicResponse<ArtistsContainer> =
            try await fetchData(endpoint: "getArtists", type: SubsonicResponse<ArtistsContainer>.self)
        return decoded.subsonicResponse.artists?.index?.flatMap { $0.artist ?? [] } ?? []
    }
    
    func getAlbumsByArtist(artistId: String) async throws -> [Album] {
        guard !artistId.isEmpty else { return [] }
        let decoded: SubsonicResponse<ArtistDetailContainer> =
            try await fetchData(endpoint: "getArtist",
                                params: ["id": artistId],
                                type: SubsonicResponse<ArtistDetailContainer>.self)
        return decoded.subsonicResponse.artist.album ?? []
    }
}