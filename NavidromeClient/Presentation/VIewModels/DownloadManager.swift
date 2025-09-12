import Foundation
import SwiftUI

@MainActor
class DownloadManager: ObservableObject {
    static let shared = DownloadManager()

    @Published private(set) var downloadedAlbums: [DownloadedAlbum] = []
    @Published private(set) var downloadedSongs: Set<String> = []
    @Published private(set) var isDownloading: Set<String> = []
    @Published private(set) var downloadProgress: [String: Double] = [:]

    struct DownloadedAlbum: Codable, Equatable {
        let albumId: String
        let songIds: [String]
        let folderPath: String
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
        loadDownloadedSongs() // NEW: Load persisted songs
    }

    // MARK: - Album / Song Status
    func isAlbumDownloaded(_ albumId: String) -> Bool {
        downloadedAlbums.contains { $0.albumId == albumId }
    }

    func isAlbumDownloading(_ albumId: String) -> Bool {
        isDownloading.contains(albumId)
    }

    func isSongDownloaded(_ songId: String) -> Bool {
        downloadedSongs.contains(songId)
    }

    func getLocalFileURL(for songId: String) -> URL? {
        guard downloadedSongs.contains(songId) else { return nil }

        // First check in album folders
        for album in downloadedAlbums {
            if album.songIds.contains(songId) {
                let path = URL(fileURLWithPath: album.folderPath).appendingPathComponent("\(songId).mp3")
                if FileManager.default.fileExists(atPath: path.path) {
                    return path
                }
            }
        }

        // Fallback: check in root downloads folder
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filePath = documentsPath.appendingPathComponent("\(songId).mp3")
        return FileManager.default.fileExists(atPath: filePath.path) ? filePath : nil
    }

    func totalDownloadSize() -> String {
        var total: UInt64 = 0
        if let enumerator = FileManager.default.enumerator(at: downloadsFolder, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    total += UInt64(size)
                }
            }
        }
        let mb = Double(total) / 1_048_576.0
        return String(format: "%.1f MB", mb)
    }

    // MARK: - Persistenz
    private func loadDownloadedAlbums() {
        guard FileManager.default.fileExists(atPath: downloadedAlbumsFile.path) else { return }
        do {
            let data = try Data(contentsOf: downloadedAlbumsFile)
            downloadedAlbums = try JSONDecoder().decode([DownloadedAlbum].self, from: data)
            // Rebuild downloadedSongs from albums
            downloadedSongs.removeAll()
            for album in downloadedAlbums {
                downloadedSongs.formUnion(album.songIds)
            }
            print("📦 Loaded \(downloadedAlbums.count) albums, \(downloadedSongs.count) songs from cache")
        } catch {
            print("Failed to load downloaded albums: \(error)")
            downloadedAlbums = []
        }
    }
    
    // NEW: Load downloaded songs separately for robustness
    private func loadDownloadedSongs() {
        guard FileManager.default.fileExists(atPath: downloadedSongsFile.path) else {
            print("📦 No separate songs file found - using songs from albums")
            return
        }
        do {
            let data = try Data(contentsOf: downloadedSongsFile)
            let songIds = try JSONDecoder().decode([String].self, from: data)
            let loadedSongs = Set(songIds)
            
            // Merge with songs from albums (albums are authoritative)
            downloadedSongs.formUnion(loadedSongs)
            
            print("📦 Loaded additional \(loadedSongs.count) songs from separate cache")
        } catch {
            print("Failed to load downloaded songs: \(error)")
        }
    }

    private func saveDownloadedAlbums() {
        do {
            let data = try JSONEncoder().encode(downloadedAlbums)
            try data.write(to: downloadedAlbumsFile)
            
            // Also save songs separately for persistence
            saveDownloadedSongs()
            
            print("💾 Saved \(downloadedAlbums.count) albums, \(downloadedSongs.count) songs")
        } catch {
            print("Failed to save downloaded albums: \(error)")
        }
    }
    
    // NEW: Save downloaded songs separately
    private func saveDownloadedSongs() {
        do {
            let songIds = Array(downloadedSongs).sorted() // Sort for consistent file
            let data = try JSONEncoder().encode(songIds)
            try data.write(to: downloadedSongsFile)
        } catch {
            print("Failed to save downloaded songs: \(error)")
        }
    }

    // MARK: - Enhanced Download Logic
    func downloadAlbum(songs: [Song], albumId: String, service: SubsonicService) async {
        // Prüfen, ob schon ein Download läuft
        guard !isDownloading.contains(albumId) else {
            print("⚠️ Download for album \(albumId) already in progress")
            return
        }
        
        print("🔽 Starting download of album \(albumId) with \(songs.count) songs")
        
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

        var successfulSongIds: [String] = []
        let totalSongs = songs.count

        for (index, song) in songs.enumerated() {
            guard let url = service.streamURL(for: song.id) else {
                print("❌ No stream URL for song: \(song.title)")
                continue
            }
            
            let fileURL = albumFolder.appendingPathComponent("\(song.id).mp3")

            do {
                print("⬇️ Downloading: \(song.title)")
                let (data, response) = try await URLSession.shared.data(from: url)
                
                // Verify response
                if let httpResponse = response as? HTTPURLResponse {
                    guard httpResponse.statusCode == 200 else {
                        print("❌ Download failed for \(song.title): HTTP \(httpResponse.statusCode)")
                        continue
                    }
                }
                
                // Write file atomically
                try data.write(to: fileURL, options: .atomic)

                // Update tracking
                successfulSongIds.append(song.id)
                downloadedSongs.insert(song.id)
                
                // Update progress - IMPORTANT: Update on MainActor
                await MainActor.run {
                    downloadProgress[albumId] = Double(index + 1) / Double(totalSongs)
                    print("📊 Progress updated: \(albumId) -> \(downloadProgress[albumId] ?? 0)")
                }
                
                print("✅ Downloaded: \(song.title)")
                
            } catch {
                print("❌ Download error for \(song.title): \(error)")
                // Continue with other songs
            }
        }

        // Save album metadata if any songs were downloaded
        if !successfulSongIds.isEmpty {
            let downloadedAlbum = DownloadedAlbum(
                albumId: albumId,
                songIds: successfulSongIds,
                folderPath: albumFolder.path
            )
            
            // Update or add album
            if let existingIndex = downloadedAlbums.firstIndex(where: { $0.albumId == albumId }) {
                // Merge with existing download
                let existingSongs = Set(downloadedAlbums[existingIndex].songIds)
                let newSongs = Set(successfulSongIds)
                let allSongs = existingSongs.union(newSongs)
                
                downloadedAlbums[existingIndex] = DownloadedAlbum(
                    albumId: albumId,
                    songIds: Array(allSongs),
                    folderPath: albumFolder.path
                )
            } else {
                downloadedAlbums.append(downloadedAlbum)
            }

            saveDownloadedAlbums()
            
            print("✅ Album download completed: \(successfulSongIds.count)/\(totalSongs) songs")
        } else {
            print("❌ Album download failed: No songs downloaded")
        }

        // Cleanup
        isDownloading.remove(albumId)
        downloadProgress[albumId] = 1.0
        
        // Send completion notification
        NotificationCenter.default.post(name: .downloadCompleted, object: albumId)

        // Clear progress after delay
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        downloadProgress.removeValue(forKey: albumId)
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
            for songId in album.songIds {
                downloadedSongs.remove(songId)
            }

            downloadedAlbums.removeAll { $0.albumId == albumId }
            downloadProgress.removeValue(forKey: albumId)
            isDownloading.remove(albumId)

            saveDownloadedAlbums()
            
            print("✅ Deleted album: \(albumId)")
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

        // Clear all tracking
        downloadedAlbums.removeAll()
        downloadedSongs.removeAll()
        downloadProgress.removeAll()
        isDownloading.removeAll()

        saveDownloadedAlbums()
        
        print("✅ Cleared all downloads")
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let downloadCompleted = Notification.Name("downloadCompleted")
    static let networkStatusChanged = Notification.Name("networkStatusChanged")
}
