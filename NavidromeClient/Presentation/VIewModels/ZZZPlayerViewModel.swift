import Foundation
import SwiftUI
import AVFoundation

@MainActor
class PlayerViewModel: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isPlaying = false
    @Published var currentSong: Song?
    @Published var currentAlbumId: String?
    @Published var coverArt: UIImage?
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackProgress: Double = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var volume: Float? = 0.7
    @Published var isShuffling: Bool = false
    @Published var repeatMode: RepeatMode = .off
    @Published var downloadProgress: [String: Double] = [:]
    @Published var downloadedSongs: Set<String> = []
    @Published var currentPlaylist: [Song] = []
    @Published var currentIndex: Int = 0
    
    // MARK: - Download Properties
    struct DownloadedAlbum: Codable, Equatable {
        let albumId: String
        let songIds: [String]
        let folderPath: String
    }
    @Published private(set) var downloadedAlbums: [DownloadedAlbum] = []
    @Published var isDownloading: Set<String> = []
    
    enum RepeatMode {
        case off, all, one
    }
    
    // MARK: - Private Properties
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var service: SubsonicService?
    private var lastUpdateTime: Double = 0
    
    // MARK: - Init    
    convenience init(service: SubsonicService) {
        self.init()
        self.service = service
    }
    
    override init() {
        super.init()
        configureAudioSession()
        setupNotifications()
        loadDownloadedAlbums()
    }
    
    deinit {
        player?.pause()
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        player = nil
        timeObserver = nil
    }
    
    // MARK: - Service Management
    func updateService(_ newService: SubsonicService) {
        self.service = newService
    }
    
    func getService() -> SubsonicService? {
        return service
    }
    
    // MARK: - Audio Session
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
    }
    
    @objc private func playerDidFinishPlaying(_ notification: Notification) {
        Task {
            await playNext()
        }
    }
    
    // MARK: - Cleanup
    private func cleanup() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        player?.pause()
        player = nil
        isPlaying = false
        isLoading = false
    }
    
    // MARK: - Playlist Management
    func setPlaylist(_ songs: [Song], startIndex: Int = 0, albumId: String? = nil) async {
        guard !songs.isEmpty else {
            errorMessage = "Playlist ist leer"
            return
        }
        
        currentPlaylist = songs
        currentIndex = max(0, min(startIndex, songs.count - 1))
        currentAlbumId = albumId
        
        await loadCoverArt()
        await playCurrent()
    }
    
    // MARK: - Playback Methods
    func play(song: Song) async {
        await setPlaylist([song], startIndex: 0, albumId: song.albumId)
    }
    
    private func playCurrent() async {
        guard currentPlaylist.indices.contains(currentIndex) else {
            stop()
            return
        }
        
        let song = currentPlaylist[currentIndex]
        currentSong = song
        currentAlbumId = song.albumId
        
        duration = Double(song.duration ?? 0)
        currentTime = 0
        isLoading = true
        
        cleanup()
        
        // Versuche zuerst lokale Datei zu laden
        if let localURL = getLocalFileURL(for: song.id) {
            await playFromURL(localURL)
        } else {
            // Falls nicht lokal verfügbar, streame vom Server
            guard let service = service,
                  let streamURL = service.streamURL(for: song.id) else {
                errorMessage = "Stream-URL konnte nicht erstellt werden"
                isLoading = false
                return
            }
            await playFromURL(streamURL)
        }
    }
    
    private func playFromURL(_ url: URL) async {
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player?.volume = volume ?? 0.7
        player?.play()
        isPlaying = true
        isLoading = false
        
        setupTimeObserver()
    }
    
    func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
    }
    
    func resume() {
        player?.play()
        isPlaying = true
    }
    
    func stop() {
        cleanup()
        currentSong = nil
        currentTime = 0
        duration = 0
        playbackProgress = 0
        errorMessage = nil
    }
    
    func seek(to time: TimeInterval) {
        guard let player = player, duration > 0 else { return }
        let clampedTime = max(0, min(time, duration))
        let seekTime = CMTime(seconds: clampedTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: seekTime)
        currentTime = clampedTime
        updateProgress()
    }
    
    func playNext() async {
        guard !currentPlaylist.isEmpty else { return }
        
        switch repeatMode {
        case .one:
            await playCurrent()
            return
        case .off:
            if currentIndex < currentPlaylist.count - 1 {
                currentIndex += 1
            } else {
                stop()
                return
            }
        case .all:
            currentIndex = (currentIndex + 1) % currentPlaylist.count
        }
        
        await playCurrent()
    }
    
    func playPrevious() async {
        guard !currentPlaylist.isEmpty else { return }
        if currentTime > 5 {
            seek(to: 0)
        } else {
            currentIndex = currentIndex > 0 ? currentIndex - 1 : currentPlaylist.count - 1
            await playCurrent()
        }
    }
    
    // MARK: - Time Observer
    private func setupTimeObserver() {
        guard let player = player else { return }
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
            queue: .main
        ) { [weak self] time in
            guard let self = self else { return }
            let newTime = time.seconds
            if abs(newTime - self.lastUpdateTime) > 0.1 {
                self.lastUpdateTime = newTime
                self.currentTime = newTime
                self.updateProgress()
            }
        }
    }
    
    private func updateProgress() {
        playbackProgress = duration > 0 ? currentTime / duration : 0
    }
    
    // MARK: - Cover Art
    func loadCoverArt() async {
        guard let albumId = currentAlbumId,
              let service = service else { return }
        coverArt = await service.getCoverArt(for: albumId)


    }
    
    // MARK: - Volume & Controls
    func setVolume(_ volume: Float?) {
        guard let volume = volume else { return }
        self.volume = volume
        player?.volume = volume
    }
    
    func toggleShuffle() {
        isShuffling.toggle()
        if isShuffling {
            currentPlaylist.shuffle()
        }
    }
    
    func toggleRepeat() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }
    
    // MARK: - Download Methods
    func downloadAlbum(songs: [Song], albumId: String, service: SubsonicService) async {
        guard !isDownloading.contains(albumId) else { return }
        
        isDownloading.insert(albumId)
        downloadProgress[albumId] = 0.0
        
        let albumFolder = downloadsFolder.appendingPathComponent(albumId, isDirectory: true)
        if !FileManager.default.fileExists(atPath: albumFolder.path) {
            try? FileManager.default.createDirectory(at: albumFolder, withIntermediateDirectories: true)
        }
        
        var songIds: [String] = []
        let totalSongs = songs.count
        
        for (index, song) in songs.enumerated() {
            guard let url = service.streamURL(for: song.id) else {
                continue
            }
            
            let fileURL = albumFolder.appendingPathComponent("\(song.id).mp3")
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                try data.write(to: fileURL, options: Data.WritingOptions.atomic)
                songIds.append(song.id)
                downloadedSongs.insert(song.id)
                
                let progress = Double(index + 1) / Double(totalSongs)
                downloadProgress[albumId] = progress
                
            } catch {
                print("Download error for \(song.title): \(error)")
            }
        }
        
        let downloadedAlbum = DownloadedAlbum(albumId: albumId, songIds: songIds, folderPath: albumFolder.path)
        if let idx = downloadedAlbums.firstIndex(where: { $0.albumId == albumId }) {
            downloadedAlbums[idx] = downloadedAlbum
        } else {
            downloadedAlbums.append(downloadedAlbum)
        }
        
        saveDownloadedAlbums()
        
        isDownloading.remove(albumId)
        downloadProgress[albumId] = 1.0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.downloadProgress.removeValue(forKey: albumId)
        }
    }
    
    func downloadSong(_ song: Song, service: SubsonicService? = nil) async {
        let serviceToUse = service ?? self.service
        guard let service = serviceToUse else {
            print("Service nicht verfügbar für Download")
            return
        }
        
        if downloadedSongs.contains(song.id) {
            return
        }
        
        guard let streamURL = service.streamURL(for: song.id) else {
            print("Konnte Stream-URL für Download nicht erstellen")
            return
        }
        
        do {
            downloadProgress[song.id] = 0.0
            
            let (data, _) = try await URLSession.shared.data(from: streamURL)
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let filePath = documentsPath.appendingPathComponent("\(song.id).mp3")
            
            try data.write(to: filePath)
            
            downloadProgress[song.id] = 1.0
            downloadedSongs.insert(song.id)
            
        } catch {
            print("Fehler beim Herunterladen von \(song.title): \(error)")
            downloadProgress[song.id] = nil
        }
    }
    
    // MARK: - Download Management
    private var downloadsFolder: URL {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }
    
    private var downloadedAlbumsFile: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("downloaded_albums.json")
    }
    
    private func loadDownloadedAlbums() {
        guard FileManager.default.fileExists(atPath: downloadedAlbumsFile.path) else { return }
        
        do {
            let data = try Data(contentsOf: downloadedAlbumsFile)
            downloadedAlbums = try JSONDecoder().decode([DownloadedAlbum].self, from: data)
            
            // Load downloaded songs from albums
            for album in downloadedAlbums {
                for songId in album.songIds {
                    downloadedSongs.insert(songId)
                }
            }
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
    
    func isAlbumDownloaded(albumId: String) -> Bool {
        downloadedAlbums.contains { $0.albumId == albumId }
    }
    
    func isAlbumDownloading(albumId: String) -> Bool {
        isDownloading.contains(albumId)
    }
    
    func getDownloadProgress(albumId: String) -> Double {
        downloadProgress[albumId] ?? 0.0
    }
    
    func deleteAlbum(albumId: String) {
        guard let album = downloadedAlbums.first(where: { $0.albumId == albumId }) else { return }
        
        let albumFolder = URL(fileURLWithPath: album.folderPath)
        try? FileManager.default.removeItem(at: albumFolder)
        
        // Remove songs from downloadedSongs
        for songId in album.songIds {
            downloadedSongs.remove(songId)
        }
        
        downloadedAlbums.removeAll { $0.albumId == albumId }
        downloadProgress.removeValue(forKey: albumId)
        isDownloading.remove(albumId)
        
        saveDownloadedAlbums()
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
    
    func totalDownloadSize() -> String {
        var total: UInt64 = 0
        let folder = downloadsFolder
        if let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    total += UInt64(size)
                }
            }
        }
        let mb = Double(total) / 1_048_576.0
        return String(format: "%.1f MB", mb)
    }
    
    // MARK: - Helper Methods
    private func getLocalFileURL(for songId: String) -> URL? {
        guard downloadedSongs.contains(songId) else { return nil }
        
        // Check in album folders first
        for album in downloadedAlbums {
            if album.songIds.contains(songId) {
                let filePath = URL(fileURLWithPath: album.folderPath).appendingPathComponent("\(songId).mp3")
                if FileManager.default.fileExists(atPath: filePath.path) {
                    return filePath
                }
            }
        }
        
        // Check in documents folder (for individual downloads)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filePath = documentsPath.appendingPathComponent("\(songId).mp3")
        
        return FileManager.default.fileExists(atPath: filePath.path) ? filePath : nil
    }
    
    func isSongDownloaded(_ songId: String) -> Bool {
        return downloadedSongs.contains(songId)
    }
}
