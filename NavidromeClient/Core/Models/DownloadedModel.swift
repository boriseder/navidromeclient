//
//  DownloadedAlbum.swift
//  NavidromeClient
//
//  Created by Boris Eder on 15.09.25.
//
import Foundation

struct DownloadedAlbum: Codable, Equatable {
    let albumId: String
    let albumName: String
    let artistName: String
    let year: Int?
    let genre: String?
    let songs: [DownloadedSong]
    let folderPath: String
    let downloadDate: Date
    
    var songIds: [String] {
        return songs.map { $0.id }
    }
}

struct DownloadedSong: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let artist: String?
    let album: String?
    let albumId: String?
    let track: Int?
    let duration: Int?
    let year: Int?
    let genre: String?
    let contentType: String?
    let fileName: String
    let fileSize: Int64
    let downloadDate: Date
    
    func toSong() -> Song {
        return Song.createFromDownload(
            id: id,
            title: title,
            duration: duration,
            coverArt: albumId,
            artist: artist,
            album: album,
            albumId: albumId,
            track: track,
            year: year,
            genre: genre,
            contentType: contentType
        )
    }
}
