//
//  SubsonicService+Search.swift
//  NavidromeClient
//
//  Created by Boris Eder on 04.09.25.
//

import Foundation

@MainActor
extension SubsonicService {
    func search(query: String, maxResults: Int = 50) async throws -> SearchResult {
        guard !query.isEmpty else {
            return SearchResult(artists: [], albums: [], songs: [])
        }
        
        let decoded: SubsonicResponse<SearchContainer> =
            try await fetchData(endpoint: "search2",
                                params: ["query": query, "maxResults": "\(maxResults)"],
                                type: SubsonicResponse<SearchContainer>.self)
        
        return SearchResult(
            artists: decoded.subsonicResponse.searchResult2.artist ?? [],
            albums: decoded.subsonicResponse.searchResult2.album ?? [],
            songs: decoded.subsonicResponse.searchResult2.song ?? []
        )
    }
}
