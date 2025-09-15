//
//  Song+Extensions.swift - Simple Initializer for Downloaded Songs
//

import Foundation

extension Song {
    
    // ✅ NEW: Simple initializer for downloaded songs (bypasses complex decoder)
    static func createFromDownload(
        id: String,
        title: String,
        duration: Int? = nil,
        coverArt: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        albumId: String? = nil,
        track: Int? = nil,
        year: Int? = nil,
        genre: String? = nil,
        contentType: String? = nil
    ) -> Song {
        
        // Create a dictionary with all required fields
        let songData: [String: Any?] = [
            "id": id,
            "title": title,
            "duration": duration,
            "coverArt": coverArt,
            "artist": artist,
            "album": album,
            "albumId": albumId,
            "track": track,
            "year": year,
            "genre": genre,
            "artistId": nil,
            "isVideo": false,
            "contentType": contentType ?? "audio/mpeg",
            "suffix": "mp3",
            "path": nil
        ]
        
        // Convert to JSON and back to create proper Song object
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: songData.compactMapValues { $0 })
            let song = try JSONDecoder().decode(Song.self, from: jsonData)
            return song
        } catch {
            print("❌ Failed to create Song from download data: \(error)")
            // Fallback - this should not happen, but just in case
            fatalError("Could not create Song object")
        }
    }
}
