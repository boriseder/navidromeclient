import Foundation
import SwiftUI
import AVFoundation


@MainActor
class PlayerViewModel: NSObject, ObservableObject {
    // MARK: - Published
    @Published var isPlaying = false
    @Published var currentSong: Song?
    @Published var currentAlbumId: String?
    @Published var coverArt: UIImage?
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackProgress: Double = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var volume: Float = 0.7
    
    @Published var downloadingAlbums: Set<String> = []
    @Published var downloadProgress: [String: Double] = [:]  // AlbumID -> Fortschritt
    @Published var downloadedAlbums: Set<String> = []
    
    
    // MARK: - Playlist Management - Use PlaylistManager for consistency
    @Published var playlistManager = PlaylistManager()
    
    typealias RepeatMode = PlaylistManager.RepeatMode
    
    // Convenience accessors for UI
    var isShuffling: Bool { playlistManager.isShuffling }
    var repeatMode: RepeatMode { playlistManager.repeatMode }
    var currentPlaylist: [Song] { playlistManager.currentPlaylist }
    var currentIndex: Int { playlistManager.currentIndex }
    
    // MARK: - Dependencies
    var service: SubsonicService?
    let downloadManager: DownloadManager
    
    // MARK: - Private
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var lastUpdateTime: Double = 0
    
    init(service: SubsonicService? = nil, downloadManager: DownloadManager = .shared) {
        self.service = service
        self.downloadManager = downloadManager
        super.init()
        configureAudioSession()
        setupNotifications()
    }
    
    deinit {
        Task { @MainActor in
            cleanup()
        }
    }
    
    // MARK: - Service
    func updateService(_ newService: SubsonicService) { service = newService }
    
    // MARK: - Playback
    func play(song: Song) async {
        await setPlaylist([song], startIndex: 0, albumId: song.albumId)
    }
    
    func setPlaylist(_ songs: [Song], startIndex: Int = 0, albumId: String?) async {
        guard !songs.isEmpty else { errorMessage = "Playlist ist leer"; return }
        
        playlistManager.setPlaylist(songs, startIndex: startIndex)
        currentAlbumId = albumId
        await loadCoverArt()
        await playCurrent()
    }
    
    private func playCurrent() async {
        guard let song = playlistManager.currentSong else { stop(); return }
        currentSong = song
        currentAlbumId = song.albumId
        duration = Double(song.duration ?? 0)
        currentTime = 0
        isLoading = true
        
        cleanup()
        
        if let localURL = downloadManager.getLocalFileURL(for: song.id) {
            await playFromURL(localURL)
        } else if let service = service, let url = service.streamURL(for: song.id) {
            await playFromURL(url)
        } else {
            errorMessage = "Keine URL zum Abspielen gefunden"
            isLoading = false
        }
    }
    
    private func playFromURL(_ url: URL) async {
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player?.volume = volume
        player?.play()
        isPlaying = true
        isLoading = false
        setupTimeObserver()
    }
    
    func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying { player.pause() } else { player.play() }
        isPlaying.toggle()
    }
    
    func pause() { player?.pause(); isPlaying = false }
    func resume() { player?.play(); isPlaying = true }
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
        let cmTime = CMTime(seconds: clampedTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: cmTime)
        currentTime = clampedTime
        updateProgress()
    }
    
    func playNext() async {
        playlistManager.advanceToNext()
        await playCurrent()
    }
    
    func playPrevious() async {
        playlistManager.moveToPrevious(currentTime: currentTime)
        await playCurrent()
    }
    
    // MARK: - Playlist Controls
    func toggleShuffle() {
        playlistManager.toggleShuffle()
    }
    
    func toggleRepeat() {
        playlistManager.toggleRepeat()
    }
    
    // MARK: - Helpers
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth])
            try session.setActive(true)
        } catch { print("Audio session error: \(error)") }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinishPlaying),
                                               name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }
    
    @objc private func playerDidFinishPlaying(_ notification: Notification) {
        Task { await playNext() }
    }
    
    private func cleanup() {
        if let observer = timeObserver { player?.removeTimeObserver(observer); timeObserver = nil }
        player?.pause(); player = nil; isPlaying = false; isLoading = false
    }
    
    private func setupTimeObserver() {
        guard let player = player else { return }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
                                                      queue: .main) { [weak self] time in
            guard let self = self else { return }
            let newTime = time.seconds
            if abs(newTime - self.lastUpdateTime) > 0.1 {
                self.lastUpdateTime = newTime
                self.currentTime = newTime
                self.updateProgress()
            }
        }
    }
    
    private func updateProgress() { playbackProgress = duration > 0 ? currentTime / duration : 0 }
    
    // MARK: - Cover Art
    func loadCoverArt() async {
        guard let albumId = currentAlbumId, let service = service else { return }
        coverArt = await service.getCoverArt(for: albumId)
    }
    
    // MARK: - Volume
    func setVolume(_ volume: Float) { self.volume = volume; player?.volume = volume }
    
    // MARK: - Download Status Methods
    func isAlbumDownloaded(_ albumId: String) -> Bool { downloadManager.isAlbumDownloaded(albumId) }
    func isAlbumDownloading(_ albumId: String) -> Bool { downloadManager.isAlbumDownloading(albumId) }
    func isSongDownloaded(_ songId: String) -> Bool { downloadManager.isSongDownloaded(songId) }
    func getDownloadProgress(albumId: String) -> Double { downloadManager.downloadProgress[albumId] ?? 0.0 }
    func deleteAlbum(albumId: String) { downloadManager.deleteAlbum(albumId: albumId) }

}

