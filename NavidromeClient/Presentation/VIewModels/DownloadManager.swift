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

    init() {
        loadDownloadedAlbums()
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

        for album in downloadedAlbums {
            if album.songIds.contains(songId) {
                let path = URL(fileURLWithPath: album.folderPath).appendingPathComponent("\(songId).mp3")
                if FileManager.default.fileExists(atPath: path.path) { return path }
            }
        }

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
            for album in downloadedAlbums { downloadedSongs.formUnion(album.songIds) }
        } catch {
            print("Failed to load downloaded albums: \(error)")
            downloadedAlbums = []
        }
    }

    private func saveDownloadedAlbums() {
        do {
            let data = try JSONEncoder().encode(downloadedAlbums)
            try data.write(to: downloadedAlbumsFile)
        } catch {
            print("Failed to save downloaded albums: \(error)")
        }
    }

    // MARK: - Download Logic (Album)
    func downloadAlbum(songs: [Song], albumId: String, service: SubsonicService) async {
        // Prüfen, ob schon ein Download läuft
        await MainActor.run {
            guard !isDownloading.contains(albumId) else { return }
            isDownloading.insert(albumId)
            downloadProgress[albumId] = 0
        }

        let albumFolder = downloadsFolder.appendingPathComponent(albumId, isDirectory: true)
        if !FileManager.default.fileExists(atPath: albumFolder.path) {
            try? FileManager.default.createDirectory(at: albumFolder, withIntermediateDirectories: true)
        }

        var songIds: [String] = []
        let totalSongs = songs.count

        for (index, song) in songs.enumerated() {
            guard let url = service.streamURL(for: song.id) else { continue }
            let fileURL = albumFolder.appendingPathComponent("\(song.id).mp3")

            do {
                // Download läuft im Hintergrund
                let (data, _) = try await URLSession.shared.data(from: url)
                try data.write(to: fileURL, options: .atomic)

                // UI-Update am MainActor
                await MainActor.run {
                    songIds.append(song.id)
                    downloadedSongs.insert(song.id)
                    downloadProgress[albumId] = Double(index + 1) / Double(totalSongs)
                }
            } catch {
                print("Download error for \(song.title): \(error)")
            }
        }

        await MainActor.run {
            // Album speichern
            let downloadedAlbum = DownloadedAlbum(albumId: albumId, songIds: songIds, folderPath: albumFolder.path)
            if let idx = downloadedAlbums.firstIndex(where: { $0.albumId == albumId }) {
                downloadedAlbums[idx] = downloadedAlbum
            } else {
                downloadedAlbums.append(downloadedAlbum)
            }

            saveDownloadedAlbums()
            isDownloading.remove(albumId)
            downloadProgress[albumId] = 1.0
        }

        // Fortschritt nach kurzer Zeit ausblenden
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        await MainActor.run {
            downloadProgress.removeValue(forKey: albumId)
        }
    }
    func deleteAlbum(albumId: String) {
        Task { @MainActor in
            guard let album = downloadedAlbums.first(where: { $0.albumId == albumId }) else { return }

            let albumFolder = URL(fileURLWithPath: album.folderPath)
            try? FileManager.default.removeItem(at: albumFolder)

            for songId in album.songIds {
                downloadedSongs.remove(songId)
            }

            downloadedAlbums.removeAll { $0.albumId == albumId }
            downloadProgress.removeValue(forKey: albumId)
            isDownloading.remove(albumId)

            saveDownloadedAlbums()
        }
    }
    
    
    func deleteAllDownloads() {
        let folder = downloadsFolder
        try? FileManager.default.removeItem(at: folder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        downloadedAlbums.removeAll()
        downloadedSongs.removeAll()
        downloadProgress.removeAll()
        isDownloading.removeAll()

        saveDownloadedAlbums()
    }
}
