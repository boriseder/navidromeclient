//
//  DownloadManager.swift - ENHANCED with UI State Management
//  NavidromeClient
//
//  ✅ ENHANCED: Centralized download state + UI logic extraction from DownloadButton
//

import Foundation

@MainActor
class DownloadManager: ObservableObject {
    static let shared = DownloadManager()

    @Published private(set) var downloadedAlbums: [DownloadedAlbum] = []
    @Published private(set) var downloadedSongs: Set<String> = []
    @Published private(set) var isDownloading: Set<String> = []
    @Published private(set) var downloadProgress: [String: Double] = [:]
    
    // ✅ NEW: Centralized Download UI States
    @Published private(set) var downloadStates: [String: DownloadState] = [:]
    @Published private(set) var downloadErrors: [String: String] = [:]

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

    // ✅ NEW: Download State Enum (moved from DownloadButton)
    enum DownloadState: Equatable {
        case idle
        case downloading
        case downloaded
        case error(String)
        case cancelling
        
        var isLoading: Bool {
            switch self {
            case .downloading, .cancelling: return true
            default: return false
            }
        }
        
        var canStartDownload: Bool {
            switch self {
            case .idle, .error: return true
            default: return false
            }
        }
        
        var canCancel: Bool {
            return self == .downloading
        }
        
        var canDelete: Bool {
            return self == .downloaded
        }
    }

    init() {
        loadDownloadedAlbums()
        migrateOldDataIfNeeded()
        setupStateObservation()
    }
    
    // ✅ NEW: Setup state observation for UI consistency
    private func setupStateObservation() {
        // Update download states when core properties change
        NotificationCenter.default.addObserver(
            forName: .downloadCompleted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let albumId = notification.object as? String {
                self?.updateDownloadState(for: albumId)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .downloadFailed,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let albumId = notification.object as? String {
                self?.downloadStates[albumId] = .error("Download failed")
            }
        }
    }

    // MARK: - ✅ ENHANCED: UI State Management
    
    /// Get current download state for UI
    func getDownloadState(for albumId: String) -> DownloadState {
        return downloadStates[albumId] ?? determineDownloadState(for: albumId)
    }
    
    /// Set download state (for UI updates)
    private func setDownloadState(_ state: DownloadState, for albumId: String) {
        downloadStates[albumId] = state
        objectWillChange.send()
    }
    
    /// Update download state based on current data
    private func updateDownloadState(for albumId: String) {
        let newState = determineDownloadState(for: albumId)
        setDownloadState(newState, for: albumId)
    }
    
    /// Determine download state from current data
    private func determineDownloadState(for albumId: String) -> DownloadState {
        if isAlbumDownloaded(albumId) {
            return .downloaded
        } else if isAlbumDownloading(albumId) {
            return .downloading
        } else if let error = downloadErrors[albumId] {
            return .error(error)
        } else {
            return .idle
        }
    }
    
    // MARK: - ✅ ENHANCED: Download Operations with State Management
    
    /// Start download with UI state management
    func startDownload(album: Album, songs: [Song], service: SubsonicService) async {
        guard getDownloadState(for: album.id).canStartDownload else {
            print("⚠️ Cannot start download for album \(album.id) in current state")
            return
        }
        
        setDownloadState(.downloading, for: album.id)
        downloadErrors.removeValue(forKey: album.id)
        
        do {
            try await downloadAlbum(songs: songs, albumId: album.id, service: service)
            setDownloadState(.downloaded, for: album.id)
        } catch {
            let errorMessage = "Download failed: \(error.localizedDescription)"
            downloadErrors[album.id] = errorMessage
            setDownloadState(.error(errorMessage), for: album.id)
            
            NotificationCenter.default.post(
                name: .downloadFailed,
                object: album.id,
                userInfo: ["error": error]
            )
        }
    }
    
    /// Cancel download with UI state management
    func cancelDownload(albumId: String) {
        guard getDownloadState(for: albumId).canCancel else {
            print("⚠️ Cannot cancel download for album \(albumId) in current state")
            return
        }
        
        setDownloadState(.cancelling, for: albumId)
        
        // Cancel the actual download (this would need enhancement in the actual download logic)
        isDownloading.remove(albumId)
        downloadProgress.removeValue(forKey: albumId)
        
        // After a brief delay, reset to idle
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
            setDownloadState(.idle, for: albumId)
        }
    }
    
    /// Delete download with UI state management
    func deleteDownload(albumId: String) {
        guard getDownloadState(for: albumId).canDelete else {
            print("⚠️ Cannot delete download for album \(albumId) in current state")
            return
        }
        
        deleteAlbum(albumId: albumId)
        setDownloadState(.idle, for: albumId)
        downloadErrors.removeValue(forKey: albumId)
    }

    // MARK: - Status Methods (unchanged)
    
    func isAlbumDownloaded(_ albumId: String) -> Bool {
        downloadedAlbums.contains { $0.albumId == albumId }
    }

    func isAlbumDownloading(_ albumId: String) -> Bool {
        isDownloading.contains(albumId)
    }

    func isSongDownloaded(_ songId: String) -> Bool {
        downloadedSongs.contains(songId)
    }
    
    func getDownloadedSong(_ songId: String) -> DownloadedSong? {
        for album in downloadedAlbums {
            if let song = album.songs.first(where: { $0.id == songId }) {
                return song
            }
        }
        return nil
    }
    
    func getDownloadedSongs(for albumId: String) -> [DownloadedSong] {
        return downloadedAlbums.first { $0.albumId == albumId }?.songs ?? []
    }
    
    func getSongsForPlayback(albumId: String) -> [Song] {
        return getDownloadedSongs(for: albumId).map { $0.toSong() }
    }

    func getLocalFileURL(for songId: String) -> URL? {
        guard let downloadedSong = getDownloadedSong(songId) else { return nil }
        
        for album in downloadedAlbums {
            if album.songs.contains(where: { $0.id == songId }) {
                let albumFolder = URL(fileURLWithPath: album.folderPath)
                let filePath = albumFolder.appendingPathComponent(downloadedSong.fileName)
                
                if FileManager.default.fileExists(atPath: filePath.path) {
                    return filePath
                }
            }
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filePath = documentsPath.appendingPathComponent("\(songId).mp3")
        return FileManager.default.fileExists(atPath: filePath.path) ? filePath : nil
    }

    func totalDownloadSize() -> String {
        let totalBytes = downloadedAlbums.reduce(0) { total, album in
            total + album.songs.reduce(0) { songTotal, song in
                songTotal + song.fileSize
            }
        }
        
        let mb = Double(totalBytes) / 1_048_576.0
        return String(format: "%.1f MB", mb)
    }

    // MARK: - ✅ ENHANCED: Download with Artist Image Caching (unchanged but enhanced error handling)
    
    func downloadAlbum(songs: [Song], albumId: String, service: SubsonicService) async throws {
        guard !isDownloading.contains(albumId) else {
            throw DownloadError.alreadyInProgress
        }
        
        guard let albumMetadata = AlbumMetadataCache.shared.getAlbum(id: albumId) else {
            throw DownloadError.missingMetadata
        }
        
        print("🔽 Starting enhanced download of album '\(albumMetadata.name)' with \(songs.count) songs")
        
        isDownloading.insert(albumId)
        downloadProgress[albumId] = 0

        let albumFolder = downloadsFolder.appendingPathComponent(albumId, isDirectory: true)
        if !FileManager.default.fileExists(atPath: albumFolder.path) {
            do {
                try FileManager.default.createDirectory(at: albumFolder, withIntermediateDirectories: true)
            } catch {
                isDownloading.remove(albumId)
                downloadProgress.removeValue(forKey: albumId)
                throw DownloadError.folderCreationFailed(error)
            }
        }

        var downloadedSongsMetadata: [DownloadedSong] = []
        let totalSongs = songs.count
        let downloadDate = Date()

        // Step 1: Download album cover art
        await cacheAlbumCoverArt(album: albumMetadata, service: service)
        
        // Step 2: Download artist image (if available)
        await cacheArtistImage(for: albumMetadata, service: service)

        // Step 3: Download songs
        for (index, song) in songs.enumerated() {
            guard let url = service.streamURL(for: song.id) else {
                print("❌ No stream URL for song: \(song.title)")
                continue
            }
            
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
                throw DownloadError.songDownloadFailed(song.title, error)
            }
        }

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
            
            if let existingIndex = downloadedAlbums.firstIndex(where: { $0.albumId == albumId }) {
                downloadedAlbums[existingIndex] = downloadedAlbum
            } else {
                downloadedAlbums.append(downloadedAlbum)
            }

            saveDownloadedAlbums()
            
            print("✅ Enhanced album download completed: '\(albumMetadata.name)' - \(downloadedSongsMetadata.count)/\(totalSongs) songs + cover arts")
        } else {
            throw DownloadError.noSongsDownloaded
        }

        isDownloading.remove(albumId)
        downloadProgress[albumId] = 1.0
        
        NotificationCenter.default.post(name: .downloadCompleted, object: albumId)

        try? await Task.sleep(nanoseconds: 2_000_000_000)
        downloadProgress.removeValue(forKey: albumId)
    }
    
    // MARK: - ✅ NEW: Download Error Types
    
    enum DownloadError: LocalizedError {
        case alreadyInProgress
        case missingMetadata
        case folderCreationFailed(Error)
        case songDownloadFailed(String, Error)
        case noSongsDownloaded
        
        var errorDescription: String? {
            switch self {
            case .alreadyInProgress:
                return "Download already in progress"
            case .missingMetadata:
                return "Album metadata not found"
            case .folderCreationFailed(let error):
                return "Failed to create download folder: \(error.localizedDescription)"
            case .songDownloadFailed(let title, let error):
                return "Failed to download '\(title)': \(error.localizedDescription)"
            case .noSongsDownloaded:
                return "No songs were successfully downloaded"
            }
        }
    }
    
    // MARK: - Helper Methods (unchanged)
    
    private func cacheAlbumCoverArt(album: Album, service: SubsonicService) async {
        let coverArtService = ReactiveCoverArtService.shared
        
        let sizes = [50, 120, 200, 300]
        
        for size in sizes {
            _ = await coverArtService.loadAlbumCover(album, size: size)
        }
        
        print("✅ Cached album cover art for \(album.id) in \(sizes.count) sizes")
    }
    
    private func cacheArtistImage(for album: Album, service: SubsonicService) async {
        let coverArtService = ReactiveCoverArtService.shared
        
        let artist = findOrCreateArtist(for: album)
        let sizes = [50, 120]
        
        for size in sizes {
            _ = await coverArtService.loadArtistImage(artist, size: size)
        }
        
        print("✅ Cached artist image for \(artist.name) in \(sizes.count) sizes")
    }
    
    private func findOrCreateArtist(for album: Album) -> Artist {
        return Artist(
            id: album.artistId ?? "artist_\(album.artist.hash)",
            name: album.artist,
            coverArt: album.coverArt,
            albumCount: 1,
            artistImageUrl: nil
        )
    }
    
    // MARK: - Deletion Methods (enhanced with state management)
    
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

            for song in album.songs {
                downloadedSongs.remove(song.id)
            }

            downloadedAlbums.removeAll { $0.albumId == albumId }
            downloadProgress.removeValue(forKey: albumId)
            isDownloading.remove(albumId)
            
            // ✅ NEW: Clean up UI state
            downloadStates.removeValue(forKey: albumId)
            downloadErrors.removeValue(forKey: albumId)

            saveDownloadedAlbums()
            
            NotificationCenter.default.post(name: .downloadDeleted, object: nil)
            objectWillChange.send()

            print("✅ Deleted album: \(album.albumName)")
        }
    }
    
    func deleteAllDownloads() {
        print("🗑️ Starting complete download deletion...")
        
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
        
        // ✅ NEW: Clean up all UI state
        downloadStates.removeAll()
        downloadErrors.removeAll()

        saveDownloadedAlbums()
        
        NotificationCenter.default.post(name: .downloadDeleted, object: nil)
        objectWillChange.send()
        
        print("✅ Cleared all downloads and notified observers")
    }

    // MARK: - Persistence (unchanged)
    
    private func loadDownloadedAlbums() {
        guard FileManager.default.fileExists(atPath: downloadedAlbumsFile.path) else { return }
        
        do {
            let data = try Data(contentsOf: downloadedAlbumsFile)
            
            if let newAlbums = try? JSONDecoder().decode([DownloadedAlbum].self, from: data) {
                downloadedAlbums = newAlbums
                rebuildDownloadedSongsSet()
                
                // ✅ NEW: Initialize UI states
                for album in newAlbums {
                    updateDownloadState(for: album.albumId)
                }
                
                print("📦 Loaded \(downloadedAlbums.count) albums with full metadata")
                return
            }
            
        } catch {
            print("❌ Failed to load downloaded albums: \(error)")
            downloadedAlbums = []
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
    
    private func migrateOldDataIfNeeded() {
        // Migration logic if needed
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
    
    private func sanitizeFileName(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return name.components(separatedBy: invalidChars).joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(50)
            .description
    }
}

// MARK: - Notification Names (enhanced)
extension Notification.Name {
    static let downloadCompleted = Notification.Name("downloadCompleted")
    static let downloadStarted = Notification.Name("downloadStarted")
    static let downloadFailed = Notification.Name("downloadFailed")
    static let downloadDeleted = Notification.Name("downloadDeleted")
    static let networkStatusChanged = Notification.Name("networkStatusChanged")
}
