//
//  SubsonicService+Genres.swift
//  NavidromeClient
//
//  Created by Boris Eder on 04.09.25.
//

import Foundation

@MainActor
extension SubsonicService {
    func getGenres() async throws -> [Genre] {
        let decoded: SubsonicResponse<GenresContainer> =
            try await fetchData(endpoint: "getGenres",
                                type: SubsonicResponse<GenresContainer>.self)
        return decoded.subsonicResponse.genres?.genre ?? []
    }
}
