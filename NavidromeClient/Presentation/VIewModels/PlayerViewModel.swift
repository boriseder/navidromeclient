//
//  PlayerViewModel.swift - FIXED for New Image API
//  NavidromeClient
//
//  ✅ FIXED: Updated loadCoverArt method to use new convenience API
//

import Foundation
import SwiftUI
import AVFoundation
import MediaPlayer

@MainActor
class PlayerViewModel: NSObject, ObservableObject {
    // MARK: - Published Properties (unchanged)
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
    
    // MARK: - Playlist Management (unchanged)
    @Published var playlistManager = PlaylistManager()
    
    typealias RepeatMode = PlaylistManager.RepeatMode
    
    // Convenience accessors for UI
    var isShuffling: Bool { playlistManager.isShuffling }
    var repeatMode: RepeatMode { playlistManager.repeatMode }
    var currentPlaylist: [Song] { playlistManager.currentPlaylist }
    var currentIndex: Int { playlistManager.currentIndex }
    
    // MARK: - Dependencies (unchanged)
    var service: SubsonicService?
    let downloadManager: DownloadManager
    private let audioSessionManager = AudioSessionManager.shared
    private weak var coverArtService: ReactiveCoverArtService?
    
    // MARK: - Private Properties (unchanged)
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var lastUpdateTime: Double = 0
    private var playerItemEndObserver: NSObjectProtocol?
    
    // FIX: Track current play task
    private var currentPlayTask: Task<Void, Never>?
    private var playerObservers: [NSObjectProtocol] = []

    // MARK: - Init (unchanged)
    
    init(service: SubsonicService? = nil, downloadManager: DownloadManager? = nil) {
        self.service = service
        self.downloadManager = downloadManager ?? DownloadManager.shared
        super.init()
        
        setupNotifications()
        configureAudioSession()
    }
    
    deinit {
        // Can't call MainActor methods from deinit
        // Move cleanup to separate method or use Task
        
        // Option A: Just remove observers (thread-safe operations only)
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        if let token = playerItemEndObserver {
            NotificationCenter.default.removeObserver(token)
        }
        playerObservers.forEach {
            NotificationCenter.default.removeObserver($0)
        }
        NotificationCenter.default.removeObserver(self)
        
        // Option B: Schedule cleanup on MainActor (if needed)
        let playerToClean = player
        Task { @MainActor in
            playerToClean?.pause()
            playerToClean?.replaceCurrentItem(with: nil)
            AudioSessionManager.shared.clearNowPlayingInfo()
        }
    }

    // MARK: - Setup (unchanged)
    
    private func setupNotifications() {
        let notificationCenter = NotificationCenter.default
        
        // Audio Interruptions
        notificationCenter.addObserver(
            self,
            selector: #selector(handleAudioInterruptionBegan),
            name: .audioInterruptionBegan,
            object: nil
        )
        
        notificationCenter.addObserver(
            self,
            selector: #selector(handleAudioInterruptionEnded),
            name: .audioInterruptionEnded,
            object: nil
        )
        
        notificationCenter.addObserver(
            self,
            selector: #selector(handleAudioInterruptionEndedShouldResume),
            name: .audioInterruptionEndedShouldResume,
            object: nil
        )
        
        notificationCenter.addObserver(
            self,
            selector: #selector(handleAudioDeviceDisconnected),
            name: .audioDeviceDisconnected,
            object: nil
        )
        
        // Remote Commands
        notificationCenter.addObserver(
            self,
            selector: #selector(handleRemotePlayCommand),
            name: .remotePlayCommand,
            object: nil
        )
        
        notificationCenter.addObserver(
            self,
            selector: #selector(handleRemotePauseCommand),
            name: .remotePauseCommand,
            object: nil
        )
        
        notificationCenter.addObserver(
            self,
            selector: #selector(handleRemoteTogglePlayPauseCommand),
            name: .remoteTogglePlayPauseCommand,
            object: nil
        )
        
        notificationCenter.addObserver(
            self,
            selector: #selector(handleRemoteNextTrackCommand),
            name: .remoteNextTrackCommand,
            object: nil
        )
        
        notificationCenter.addObserver(
            self,
            selector: #selector(handleRemotePreviousTrackCommand),
            name: .remotePreviousTrackCommand,
            object: nil
        )
        
        notificationCenter.addObserver(
            self,
            selector: #selector(handleRemoteSeekCommand),
            name: .remoteSeekCommand,
            object: nil
        )
        
        notificationCenter.addObserver(
            self,
            selector: #selector(handleRemoteSkipForwardCommand),
            name: .remoteSkipForwardCommand,
            object: nil
        )
        
        notificationCenter.addObserver(
            self,
            selector: #selector(handleRemoteSkipBackwardCommand),
            name: .remoteSkipBackwardCommand,
            object: nil
        )
    }
    
    private func configureAudioSession() {
        _ = audioSessionManager.isAudioSessionActive
    }
    
    // MARK: - Service Management (unchanged)
    
    func updateService(_ newService: SubsonicService) {
        self.service = newService
    }
    
    func updateCoverArtService(_ newCoverArtService: ReactiveCoverArtService) {
        self.coverArtService = newCoverArtService
    }
    
    // MARK: - Playback Methods (mostly unchanged)
    
    func play(song: Song) async {
        await setPlaylist([song], startIndex: 0, albumId: song.albumId)
    }
    
    func setPlaylist(_ songs: [Song], startIndex: Int = 0, albumId: String?) async {
        guard !songs.isEmpty else {
            errorMessage = "Playlist ist leer"
            return
        }
        
        playlistManager.setPlaylist(songs, startIndex: startIndex)
        currentAlbumId = albumId
        await loadCoverArt()
        await playCurrent()
    }
    
    // MARK: - ✅ FIXED: Cover Art Loading
    
    func loadCoverArt() async {
        guard let albumId = currentAlbumId else { return }
        guard let coverArtService = coverArtService else { return }
        
        // ✅ FIXED: Use the new convenience API instead of direct ImageType
        if let albumMetadata = AlbumMetadataCache.shared.getAlbum(id: albumId) {
            coverArt = await coverArtService.loadAlbumCover(albumMetadata, size: 300)
        } else {
            // ✅ GRACEFUL DEGRADATION: Clear cover art instead of forcing load
            print("⚠️ Album metadata not found for ID: \(albumId), clearing cover art")
            coverArt = nil
        }
        
        updateNowPlayingInfo()
    }
    
    // MARK: - Playback Control Methods (unchanged)
    
    private func playCurrent() async {
        // FIX: Cancel any pending play operation
        currentPlayTask?.cancel()
        
        currentPlayTask = Task {
            // Check cancellation before starting
            guard !Task.isCancelled else { return }
            
            guard let song = playlistManager.currentSong else {
                stop()
                return
            }
            
            currentSong = song
            currentAlbumId = song.albumId
            duration = Double(song.duration ?? 0)
            currentTime = 0
            isLoading = true
            
            // FIX: Ensure clean state before new playback
            cleanupPlayer()
            
            // Check again after cleanup
            guard !Task.isCancelled else {
                isLoading = false
                return
            }
            
            // Try local file first
            if let localURL = downloadManager.getLocalFileURL(for: song.id) {
                await playFromURL(localURL)
            } else if let service = service, let url = service.streamURL(for: song.id) {
                await playFromURL(url)
            } else {
                errorMessage = "Keine URL zum Abspielen gefunden"
                isLoading = false
            }
        }
    }
    
    private func playFromURL(_ url: URL) async {
        // FIX: Check task cancellation
        guard currentPlayTask?.isCancelled == false else { return }
        
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player?.volume = volume
        player?.play()
        isPlaying = true
        isLoading = false
        
        // FIX: Clean observer management
        if let existingObserver = playerItemEndObserver {
            NotificationCenter.default.removeObserver(existingObserver)
            playerItemEndObserver = nil
        }
        
        playerItemEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,  // Important: observe specific item
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.playNext()
            }
        }
        
        setupTimeObserver()
        updateNowPlayingInfo()
    }

    func togglePlayPause() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
        
        updateNowPlayingInfo()
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }
    
    func resume() {
        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
    }
    
    func stop() {
        cleanupPlayer()
        currentSong = nil
        currentTime = 0
        duration = 0
        playbackProgress = 0
        errorMessage = nil
        audioSessionManager.clearNowPlayingInfo()
    }
    
    func seek(to time: TimeInterval) {
        guard let player = player, duration > 0 else { return }
        let clampedTime = max(0, min(time, duration))
        let cmTime = CMTime(seconds: clampedTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: cmTime)
        currentTime = clampedTime
        updateProgress()
        updateNowPlayingInfo()
    }
    
    func playNext() async {
        // FIX: Cancel current before next
        currentPlayTask?.cancel()
        playlistManager.advanceToNext()
        await playCurrent()
    }
    
    func playPrevious() async {
        // FIX: Cancel current before previous
        currentPlayTask?.cancel()
        playlistManager.moveToPrevious(currentTime: currentTime)
        await playCurrent()
    }
    
    func skipForward(seconds: TimeInterval = 15) {
        let newTime = currentTime + seconds
        seek(to: newTime)
    }
    
    func skipBackward(seconds: TimeInterval = 15) {
        let newTime = currentTime - seconds
        seek(to: newTime)
    }
    
    // MARK: - Playlist Controls (unchanged)
    
    func toggleShuffle() {
        playlistManager.toggleShuffle()
    }
    
    func toggleRepeat() {
        playlistManager.toggleRepeat()
    }
    
    // MARK: - Volume Control (unchanged)
    
    func setVolume(_ volume: Float) {
        self.volume = volume
        player?.volume = volume
    }
    
    // MARK: - Now Playing Info (unchanged)
    
    private func updateNowPlayingInfo() {
        guard let song = currentSong else {
            audioSessionManager.clearNowPlayingInfo()
            return
        }
        
        audioSessionManager.updateNowPlayingInfo(
            title: song.title,
            artist: song.artist ?? "Unknown Artist",
            album: song.album,
            artwork: coverArt,
            duration: duration,
            currentTime: currentTime,
            playbackRate: isPlaying ? 1.0 : 0.0
        )
    }
    
    // MARK: - Time Observer (unchanged)
    
    private func updateProgress() {
        playbackProgress = duration > 0 ? currentTime / duration : 0
    }
    
    private func setupTimeObserver() {
        guard let player = player else { return }
        
        // Remove existing observer
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        
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
                
                // Update Now Playing Info every few seconds to keep it current
                if Int(newTime) % 5 == 0 {
                    self.updateNowPlayingInfo()
                }
            }
        }
    }

    // MARK: - Cleanup (unchanged)
    
    private func cleanupPlayer() {
        // FIX: Complete cleanup
        currentPlayTask?.cancel()
        currentPlayTask = nil
        
        // Remove time observer
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        // Remove end observer
        if let token = playerItemEndObserver {
            NotificationCenter.default.removeObserver(token)
            playerItemEndObserver = nil
        }
        
        // Remove all other observers
        playerObservers.forEach {
            NotificationCenter.default.removeObserver($0)
        }
        playerObservers.removeAll()
        
        // Stop and properly clear player
        player?.pause()
        player?.replaceCurrentItem(with: nil)  // FIX: Properly clear item
        player = nil
        
        isPlaying = false
        isLoading = false
    }

    // MARK: - Notification Handlers (unchanged)
    
    @objc private func handleAudioInterruptionBegan() {
        pause()
    }
    
    @objc private func handleAudioInterruptionEnded() {
        // Don't auto-resume, user needs to manually resume
    }
    
    @objc private func handleAudioInterruptionEndedShouldResume() {
        // Auto-resume if system recommends it
        if currentSong != nil {
            resume()
        }
    }
    
    @objc private func handleAudioDeviceDisconnected() {
        // Pause when headphones are removed
        pause()
    }
    
    @objc private func handleRemotePlayCommand() {
        if currentSong != nil {
            resume()
        }
    }
    
    @objc private func handleRemotePauseCommand() {
        pause()
    }
    
    @objc private func handleRemoteTogglePlayPauseCommand() {
        togglePlayPause()
    }
    
    @objc private func handleRemoteNextTrackCommand() {
        Task { [weak self] in
            await self?.playNext()
        }
    }

    @objc private func handleRemotePreviousTrackCommand() {
        Task { [weak self] in
            await self?.playPrevious()
        }
    }

    @objc private func handleRemoteSeekCommand(notification: Notification) {
        if let time = notification.userInfo?["time"] as? TimeInterval {
            seek(to: time)
        }
    }
    
    @objc private func handleRemoteSkipForwardCommand(notification: Notification) {
        let interval = notification.userInfo?["interval"] as? TimeInterval ?? 15
        skipForward(seconds: interval)
    }
    
    @objc private func handleRemoteSkipBackwardCommand(notification: Notification) {
        let interval = notification.userInfo?["interval"] as? TimeInterval ?? 15
        skipBackward(seconds: interval)
    }

    // MARK: - Download Status Methods (unchanged)
    func isAlbumDownloaded(_ albumId: String) -> Bool {
        downloadManager.isAlbumDownloaded(albumId)
    }
    
    func isAlbumDownloading(_ albumId: String) -> Bool {
        downloadManager.isAlbumDownloading(albumId)
    }
    
    func isSongDownloaded(_ songId: String) -> Bool {
        downloadManager.isSongDownloaded(songId)
    }
    
    func getDownloadProgress(albumId: String) -> Double {
        downloadManager.downloadProgress[albumId] ?? 0.0
    }
    
    func deleteAlbum(albumId: String) {
        downloadManager.deleteAlbum(albumId: albumId)
    }
}
