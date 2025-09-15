//
//  DownloadManager.swift - Enhanced with Complete Song Metadata Storage
//

import Foundation

@MainActor
class DownloadManager: ObservableObject {
    static let shared = DownloadManager()

    @Published private(set) var downloadedAlbums: [DownloadedAlbum] = []
    @Published private(set) var downloadedSongs: Set<String> = []
    @Published private(set) var isDownloading: Set<String> = []
    @Published private(set) var downloadProgress: [String: Double] = [:]

    // ✅ NEW: Enhanced data structures with full metadata
    struct DownloadedAlbum: Codable, Equatable {
        let albumId: String
        let albumName: String        // ✅ NEW
        let artistName: String       // ✅ NEW
        let year: Int?              // ✅ NEW
        let genre: String?          // ✅ NEW
        let songs: [DownloadedSong] // ✅ ENHANCED: Full song objects instead of just IDs
        let folderPath: String
        let downloadDate: Date      // ✅ NEW
        
        // Legacy support
        var songIds: [String] {
            return songs.map { $0.id }
        }
    }
    
    // ✅ NEW: Complete Song Metadata Storage
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
        let fileName: String        // ✅ NEW: Actual file name
        let fileSize: Int64         // ✅ NEW: File size in bytes
        let downloadDate: Date      // ✅ NEW
        
        // Convert to Song object for playback
        func toSong() -> Song {
            Song(
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
                artistId: nil,
                isVideo: false,
                contentType: contentType ?? "audio/mpeg",
                suffix: "mp3",
                path: nil
            )
        }
    }

    private var downloadsFolder: URL {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    private var downloadedAlbumsFile: URL {
        downloadsFolder.appendingPathComponent("downloaded_albums.json")
    }
    
    private var downloadedSongsFile: URL {
        downloadsFolder.appendingPathComponent("downloaded_songs.json")
    }

    init() {
        loadDownloadedAlbums()
        migrateOldDataIfNeeded() // ✅ NEW: Handle migration from old format
    }

    // MARK: - Album / Song Status (Enhanced)
    func isAlbumDownloaded(_ albumId: String) -> Bool {
        downloadedAlbums.contains { $0.albumId == albumId }
    }

    func isAlbumDownloading(_ albumId: String) -> Bool {
        isDownloading.contains(albumId)
    }

    func isSongDownloaded(_ songId: String) -> Bool {
        downloadedSongs.contains(songId)
    }
    
    // ✅ NEW: Get downloaded song metadata
    func getDownloadedSong(_ songId: String) -> DownloadedSong? {
        for album in downloadedAlbums {
            if let song = album.songs.first(where: { $0.id == songId }) {
                return song
            }
        }
        return nil
    }
    
    // ✅ NEW: Get all downloaded songs for an album
    func getDownloadedSongs(for albumId: String) -> [DownloadedSong] {
        return downloadedAlbums.first { $0.albumId == albumId }?.songs ?? []
    }
    
    // ✅ NEW: Convert downloaded songs to Song objects for playback
    func getSongsForPlayback(albumId: String) -> [Song] {
        return getDownloadedSongs(for: albumId).map { $0.toSong() }
    }

    func getLocalFileURL(for songId: String) -> URL? {
        // ✅ ENHANCED: Use stored file name from metadata
        guard let downloadedSong = getDownloadedSong(songId) else { return nil }
        
        // Find the album this song belongs to
        for album in downloadedAlbums {
            if album.songs.contains(where: { $0.id == songId }) {
                let albumFolder = URL(fileURLWithPath: album.folderPath)
                let filePath = albumFolder.appendingPathComponent(downloadedSong.fileName)
                
                if FileManager.default.fileExists(atPath: filePath.path) {
                    return filePath
                }
            }
        }
        
        // Legacy fallback
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filePath = documentsPath.appendingPathComponent("\(songId).mp3")
        return FileManager.default.fileExists(atPath: filePath.path) ? filePath : nil
    }

    func totalDownloadSize() -> String {
        // ✅ ENHANCED: Use stored file sizes from metadata
        let totalBytes = downloadedAlbums.reduce(0) { total, album in
            total + album.songs.reduce(0) { songTotal, song in
                songTotal + song.fileSize
            }
        }
        
        let mb = Double(totalBytes) / 1_048_576.0
        return String(format: "%.1f MB", mb)
    }
    
    // ✅ NEW: Get download statistics
    func getDownloadStats() -> DownloadStats {
        let totalSongs = downloadedAlbums.reduce(0) { $0 + $1.songs.count }
        let totalSize = downloadedAlbums.reduce(0) { total, album in
            total + album.songs.reduce(0) { $0 + $1.fileSize }
        }
        
        return DownloadStats(
            albumCount: downloadedAlbums.count,
            songCount: totalSongs,
            totalSizeBytes: totalSize,
            oldestDownload: downloadedAlbums.map { $0.downloadDate }.min(),
            newestDownload: downloadedAlbums.map { $0.downloadDate }.max()
        )
    }

    // ✅ ENHANCED: Download with Complete Metadata Storage
    func downloadAlbum(songs: [Song], albumId: String, service: SubsonicService) async {
        guard !isDownloading.contains(albumId) else {
            print("⚠️ Download for album \(albumId) already in progress")
            return
        }
        
        // Get album metadata
        guard let albumMetadata = AlbumMetadataCache.shared.getAlbum(id: albumId) else {
            print("❌ Album metadata not found for \(albumId)")
            return
        }
        
        print("🔽 Starting download of album '\(albumMetadata.name)' with \(songs.count) songs")
        
        isDownloading.insert(albumId)
        downloadProgress[albumId] = 0

        let albumFolder = downloadsFolder.appendingPathComponent(albumId, isDirectory: true)
        if !FileManager.default.fileExists(atPath: albumFolder.path) {
            do {
                try FileManager.default.createDirectory(at: albumFolder, withIntermediateDirectories: true)
            } catch {
                print("❌ Failed to create album folder: \(error)")
                isDownloading.remove(albumId)
                downloadProgress.removeValue(forKey: albumId)
                return
            }
        }

        var downloadedSongsMetadata: [DownloadedSong] = []
        let totalSongs = songs.count
        let downloadDate = Date()

        for (index, song) in songs.enumerated() {
            guard let url = service.streamURL(for: song.id) else {
                print("❌ No stream URL for song: \(song.title)")
                continue
            }
            
            // ✅ ENHANCED: Generate proper file name
            let sanitizedTitle = sanitizeFileName(song.title)
            let trackNumber = String(format: "%02d", song.track ?? index + 1)
            let fileName = "\(trackNumber) - \(sanitizedTitle).mp3"
            let fileURL = albumFolder.appendingPathComponent(fileName)

            do {
                print("⬇️ Downloading: \(song.title)")
                let (data, response) = try await URLSession.shared.data(from: url)
                
                if let httpResponse = response as? HTTPURLResponse {
                    guard httpResponse.statusCode == 200 else {
                        print("❌ Download failed for \(song.title): HTTP \(httpResponse.statusCode)")
                        continue
                    }
                }
                
                try data.write(to: fileURL, options: .atomic)

                // ✅ NEW: Create complete song metadata
                let downloadedSong = DownloadedSong(
                    id: song.id,
                    title: song.title,
                    artist: song.artist,
                    album: song.album,
                    albumId: song.albumId,
                    track: song.track,
                    duration: song.duration,
                    year: song.year,
                    genre: song.genre,
                    contentType: song.contentType,
                    fileName: fileName,
                    fileSize: Int64(data.count),
                    downloadDate: downloadDate
                )
                
                downloadedSongsMetadata.append(downloadedSong)
                downloadedSongs.insert(song.id)
                
                await MainActor.run {
                    downloadProgress[albumId] = Double(index + 1) / Double(totalSongs)
                }
                
                print("✅ Downloaded: \(song.title) (\(data.count) bytes)")
                
            } catch {
                print("❌ Download error for \(song.title): \(error)")
            }
        }

        // ✅ ENHANCED: Save complete album metadata
        if !downloadedSongsMetadata.isEmpty {
            let downloadedAlbum = DownloadedAlbum(
                albumId: albumId,
                albumName: albumMetadata.name,
                artistName: albumMetadata.artist,
                year: albumMetadata.year,
                genre: albumMetadata.genre,
                songs: downloadedSongsMetadata,
                folderPath: albumFolder.path,
                downloadDate: downloadDate
            )
            
            // Update or add album
            if let existingIndex = downloadedAlbums.firstIndex(where: { $0.albumId == albumId }) {
                downloadedAlbums[existingIndex] = downloadedAlbum
            } else {
                downloadedAlbums.append(downloadedAlbum)
            }

            saveDownloadedAlbums()
            
            print("✅ Album download completed: '\(albumMetadata.name)' - \(downloadedSongsMetadata.count)/\(totalSongs) songs")
        } else {
            print("❌ Album download failed: No songs downloaded")
        }

        isDownloading.remove(albumId)
        downloadProgress[albumId] = 1.0
        
        NotificationCenter.default.post(name: .downloadCompleted, object: albumId)

        try? await Task.sleep(nanoseconds: 2_000_000_000)
        downloadProgress.removeValue(forKey: albumId)
    }
    
    // ✅ NEW: Sanitize file names for filesystem
    private func sanitizeFileName(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return name.components(separatedBy: invalidChars).joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(50) // Limit length
            .description
    }
    
    func deleteAlbum(albumId: String) {
        Task { @MainActor in
            guard let album = downloadedAlbums.first(where: { $0.albumId == albumId }) else {
                print("⚠️ Album \(albumId) not found for deletion")
                return
            }

            let albumFolder = URL(fileURLWithPath: album.folderPath)
            do {
                try FileManager.default.removeItem(at: albumFolder)
                print("🗑️ Deleted album folder: \(albumFolder.path)")
            } catch {
                print("❌ Failed to delete album folder: \(error)")
            }

            // Remove from tracking
            for song in album.songs {
                downloadedSongs.remove(song.id)
            }

            downloadedAlbums.removeAll { $0.albumId == albumId }
            downloadProgress.removeValue(forKey: albumId)
            isDownloading.remove(albumId)

            saveDownloadedAlbums()
            
            print("✅ Deleted album: \(album.albumName)")
        }
    }
    
    func deleteAllDownloads() {
        let folder = downloadsFolder
        do {
            try FileManager.default.removeItem(at: folder)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            print("🗑️ Deleted all downloads folder")
        } catch {
            print("❌ Failed to delete downloads folder: \(error)")
        }

        downloadedAlbums.removeAll()
        downloadedSongs.removeAll()
        downloadProgress.removeAll()
        isDownloading.removeAll()

        saveDownloadedAlbums()
        
        print("✅ Cleared all downloads")
    }

    // MARK: - ✅ ENHANCED: Persistence with Migration Support
    
    private func loadDownloadedAlbums() {
        guard FileManager.default.fileExists(atPath: downloadedAlbumsFile.path) else { return }
        
        do {
            let data = try Data(contentsOf: downloadedAlbumsFile)
            
            // Try to decode new format first
            if let newAlbums = try? JSONDecoder().decode([DownloadedAlbum].self, from: data) {
                downloadedAlbums = newAlbums
                rebuildDownloadedSongsSet()
                print("📦 Loaded \(downloadedAlbums.count) albums with full metadata")
                return
            }
            
            // ✅ LEGACY: Try old format for migration
            if let oldAlbums = try? JSONDecoder().decode([LegacyDownloadedAlbum].self, from: data) {
                print("🔄 Migrating \(oldAlbums.count) albums from legacy format...")
                downloadedAlbums = migrateLegacyAlbums(oldAlbums)
                rebuildDownloadedSongsSet()
                saveDownloadedAlbums() // Save in new format
                print("✅ Migration completed")
                return
            }
            
        } catch {
            print("❌ Failed to load downloaded albums: \(error)")
            downloadedAlbums = []
        }
    }
    
    // ✅ NEW: Migration from old format
    private struct LegacyDownloadedAlbum: Codable, Equatable {
        let albumId: String
        let songIds: [String]
        let folderPath: String
    }
    
    private func migrateLegacyAlbums(_ legacyAlbums: [LegacyDownloadedAlbum]) -> [DownloadedAlbum] {
        return legacyAlbums.compactMap { legacy in
            // Get album metadata
            guard let albumMetadata = AlbumMetadataCache.shared.getAlbum(id: legacy.albumId) else {
                print("⚠️ No metadata found for legacy album \(legacy.albumId)")
                return nil
            }
            
            // Create minimal song metadata from legacy data
            let songs = legacy.songIds.enumerated().map { index, songId in
                DownloadedSong(
                    id: songId,
                    title: "Track \(index + 1)", // Fallback title
                    artist: albumMetadata.artist,
                    album: albumMetadata.name,
                    albumId: legacy.albumId,
                    track: index + 1,
                    duration: nil,
                    year: albumMetadata.year,
                    genre: albumMetadata.genre,
                    contentType: "audio/mpeg",
                    fileName: "\(songId).mp3", // Legacy file naming
                    fileSize: getFileSizeForLegacySong(songId, folderPath: legacy.folderPath),
                    downloadDate: Date() // Approximate
                )
            }
            
            return DownloadedAlbum(
                albumId: legacy.albumId,
                albumName: albumMetadata.name,
                artistName: albumMetadata.artist,
                year: albumMetadata.year,
                genre: albumMetadata.genre,
                songs: songs,
                folderPath: legacy.folderPath,
                downloadDate: Date() // Approximate
            )
        }
    }
    
    private func getFileSizeForLegacySong(_ songId: String, folderPath: String) -> Int64 {
        let fileURL = URL(fileURLWithPath: folderPath).appendingPathComponent("\(songId).mp3")
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    private func migrateOldDataIfNeeded() {
        // Check if we need to migrate from very old format
        let oldSongsFile = downloadsFolder.appendingPathComponent("downloaded_songs.json")
        if FileManager.default.fileExists(atPath: oldSongsFile.path) && downloadedAlbums.isEmpty {
            print("🔄 Found old songs file - cleaning up...")
            try? FileManager.default.removeItem(at: oldSongsFile)
        }
    }
    
    private func rebuildDownloadedSongsSet() {
        downloadedSongs.removeAll()
        for album in downloadedAlbums {
            for song in album.songs {
                downloadedSongs.insert(song.id)
            }
        }
    }

    private func saveDownloadedAlbums() {
        do {
            let data = try JSONEncoder().encode(downloadedAlbums)
            try data.write(to: downloadedAlbumsFile)
            print("💾 Saved \(downloadedAlbums.count) albums with full metadata")
        } catch {
            print("❌ Failed to save downloaded albums: \(error)")
        }
    }
}

// ✅ NEW: Download Statistics
struct DownloadStats {
    let albumCount: Int
    let songCount: Int
    let totalSizeBytes: Int64
    let oldestDownload: Date?
    let newestDownload: Date?
    
    var totalSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: totalSizeBytes, countStyle: .file)
    }
    
    var averageSongSize: Int64 {
        guard songCount > 0 else { return 0 }
        return totalSizeBytes / Int64(songCount)
    }
    
    var averageAlbumSize: Int64 {
        guard albumCount > 0 else { return 0 }
        return totalSizeBytes / Int64(albumCount)
    }
    
    var downloadTimespan: String? {
        guard let oldest = oldestDownload, let newest = newestDownload else { return nil }
        let days = Calendar.current.dateComponents([.day], from: oldest, to: newest).day ?? 0
        return "\(days) days"
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let downloadCompleted = Notification.Name("downloadCompleted")
    static let networkStatusChanged = Notification.Name("networkStatusChanged")
}
