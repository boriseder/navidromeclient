//
//  PlayerViewModel.swift - COMPLETE CLEAN IMPLEMENTATION
//  NavidromeClient
//
//  ✅ FIXED: Complete Observer Management & Thread Safety
//  ✅ BULLETPROOF: No more AVPlayer crashes
//

import Foundation
import SwiftUI
import AVFoundation
import MediaPlayer

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
    @Published var volume: Float = 0.7
    
    // MARK: - Playlist Management
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
    private let audioSessionManager = AudioSessionManager.shared
    private weak var coverArtManager: CoverArtManager?

    // MARK: - ✅ FIXED: Complete Observer Management
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var playerItemEndObserver: NSObjectProtocol?
    private var currentPlayTask: Task<Void, Never>?
    
    // ✅ NEW: Observer tracking for complete cleanup
    private var notificationObservers: [NSObjectProtocol] = []
    private var lastUpdateTime: Double = 0

    // MARK: - Init with proper cleanup setup
    init(service: SubsonicService? = nil, downloadManager: DownloadManager? = nil) {
        self.service = service
        self.downloadManager = downloadManager ?? DownloadManager.shared
        super.init()
        
        setupNotifications()
        configureAudioSession()
    }
    
    // ✅ BULLETPROOF: Thread-safe deinit
    deinit {
        // CRITICAL: Can't call @MainActor methods from deinit
        // Only perform thread-safe cleanup here
        
        // Cancel tasks (thread-safe)
        currentPlayTask?.cancel()
        
        // Remove time observer (thread-safe if player exists)
        if let observer = timeObserver, let player = player {
            player.removeTimeObserver(observer)
        }
        
        // Remove notification observers (thread-safe)
        if let token = playerItemEndObserver {
            NotificationCenter.default.removeObserver(token)
        }
        notificationObservers.forEach {
            NotificationCenter.default.removeObserver($0)
        }
        NotificationCenter.default.removeObserver(self)
        
        // Schedule heavy cleanup on MainActor for proper UI updates
        let playerToClean = player
        Task { @MainActor in
            playerToClean?.pause()
            playerToClean?.replaceCurrentItem(with: nil)
            AudioSessionManager.shared.clearNowPlayingInfo()
        }
    }

    // MARK: - ✅ BULLETPROOF: Complete Notification Setup
    private func setupNotifications() {
        let center = NotificationCenter.default
        
        // Store all observers for proper cleanup
        let observers: [(Notification.Name, Selector)] = [
            (.audioInterruptionBegan, #selector(handleAudioInterruptionBegan)),
            (.audioInterruptionEnded, #selector(handleAudioInterruptionEnded)),
            (.audioInterruptionEndedShouldResume, #selector(handleAudioInterruptionEndedShouldResume)),
            (.audioDeviceDisconnected, #selector(handleAudioDeviceDisconnected)),
            (.remotePlayCommand, #selector(handleRemotePlayCommand)),
            (.remotePauseCommand, #selector(handleRemotePauseCommand)),
            (.remoteTogglePlayPauseCommand, #selector(handleRemoteTogglePlayPauseCommand)),
            (.remoteNextTrackCommand, #selector(handleRemoteNextTrackCommand)),
            (.remotePreviousTrackCommand, #selector(handleRemotePreviousTrackCommand)),
            (.remoteSeekCommand, #selector(handleRemoteSeekCommand)),
            (.remoteSkipForwardCommand, #selector(handleRemoteSkipForwardCommand)),
            (.remoteSkipBackwardCommand, #selector(handleRemoteSkipBackwardCommand))
        ]
        
        for (name, selector) in observers {
            let observer = center.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.perform(selector, with: notification)
            }
            notificationObservers.append(observer)
        }
    }
    
    private func configureAudioSession() {
        _ = audioSessionManager.isAudioSessionActive
    }
    
    // MARK: - Service Management
    func updateService(_ newService: SubsonicService) {
        self.service = newService
    }
    
    func updateCoverArtService(_ newCoverArtManager: CoverArtManager) {
        self.coverArtManager = newCoverArtManager
    }
    
    func loadCoverArt() async {
        guard let albumId = currentAlbumId else { return }
        guard let coverArtManager = coverArtManager else { return }
        
        if let albumMetadata = AlbumMetadataCache.shared.getAlbum(id: albumId) {
            coverArt = await coverArtManager.loadAlbumImage(album: albumMetadata, size: 300)
        } else {
            print("⚠️ Album metadata not found for ID: \(albumId)")
            coverArt = nil
        }
        
        updateNowPlayingInfo()
    }

    // MARK: - ✅ BULLETPROOF: Complete Player Cleanup
    private func cleanupPlayer() {
        print("🧹 Starting complete player cleanup")
        
        // 1. Cancel any pending operations
        currentPlayTask?.cancel()
        currentPlayTask = nil
        
        // 2. Remove time observer FIRST (most critical)
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
            print("✅ Time observer removed")
        }
        
        // 3. Remove player item observer
        if let token = playerItemEndObserver {
            NotificationCenter.default.removeObserver(token)
            playerItemEndObserver = nil
            print("✅ Player item observer removed")
        }
        
        // 4. Stop and clear player completely
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        print("✅ Player cleared")
        
        // 5. Reset state
        isPlaying = false
        isLoading = false
        
        print("✅ Player cleanup completed")
    }

    // MARK: - ✅ FIXED: Safe Playback Methods
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
    
    // ✅ FIXED: Safe playback without premature cleanup
    private func playCurrent() async {
        print("🎵 playCurrent called")
        
        // Cancel any pending play operation
        currentPlayTask?.cancel()
        
        currentPlayTask = Task {
            guard !Task.isCancelled else { return }
            guard let song = playlistManager.currentSong else {
                await MainActor.run { stop() }
                return
            }
            
            await MainActor.run {
                currentSong = song
                currentAlbumId = song.albumId
                duration = Double(song.duration ?? 0)
                currentTime = 0
                isLoading = true
                objectWillChange.send()
            }
            
            print("🎵 Playing song: \(song.title)")
            
            guard !Task.isCancelled else {
                await MainActor.run {
                    isLoading = false
                    objectWillChange.send()
                }
                return
            }
            
            print("➡️ Reached playback decision for song \(song.id)")
            
            if let localURL = downloadManager.getLocalFileURL(for: song.id) {
                print("🎵 Playing from local file: \(localURL)")
                await playFromURL(localURL)
            } else if let service = service, let url = service.streamURL(for: song.id) {
                print("🎵 Playing from stream: \(url)")
                await playFromURL(url)
            } else {
                await MainActor.run {
                    errorMessage = "Keine URL zum Abspielen gefunden"
                    print("❌ Keine URL zum Abspielen gefunden")
                    isLoading = false
                    objectWillChange.send()
                }
            }
        }
    }

    // ✅ CORRECT: Safe URL playback with proper observer cleanup
    private func playFromURL(_ url: URL) async {
        print("🎵 playFromURL called: \(url)")
        
        guard currentPlayTask?.isCancelled == false else { return }
        
        // ✅ CORRECT: Cleanup old player/observers ONLY when creating new one
        await MainActor.run {
            // Remove old observers first
            if let observer = timeObserver {
                player?.removeTimeObserver(observer)
                timeObserver = nil
                print("✅ Old time observer removed")
            }
            
            if let token = playerItemEndObserver {
                NotificationCenter.default.removeObserver(token)
                playerItemEndObserver = nil
                print("✅ Old player item observer removed")
            }
            
            // Stop old player
            player?.pause()
            player?.replaceCurrentItem(with: nil)
            
            // Create new player
            let item = AVPlayerItem(url: url)
            player = AVPlayer(playerItem: item)
            player?.volume = volume
            
            // Update UI state
            isPlaying = true
            isLoading = false
            objectWillChange.send()
            
            // Start playback
            player?.play()
            print("✅ New player created and started")
        }
        
        // ✅ Setup new observers AFTER player is ready
        if let player = player, let currentItem = player.currentItem {
            await MainActor.run {
                setupPlayerItemObserver(for: currentItem)
                setupTimeObserver()
                updateNowPlayingInfo()
                print("✅ New observers setup completed")
            }
        }
    }
    
    // ✅ NEW: Safe player item observer setup
    private func setupPlayerItemObserver(for item: AVPlayerItem) {
        // Remove existing observer first
        if let existingObserver = playerItemEndObserver {
            NotificationCenter.default.removeObserver(existingObserver)
            playerItemEndObserver = nil
        }
        
        playerItemEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.playNext()
            }
        }
        print("✅ Player item observer setup")
    }

    // ✅ BULLETPROOF: Safe time observer setup
    private func setupTimeObserver() {
        guard let player = player else { return }
        
        // Remove existing observer first
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
                
                // Update Now Playing Info every few seconds
                if Int(newTime) % 5 == 0 {
                    self.updateNowPlayingInfo()
                }
            }
        }
        print("✅ Time observer setup")
    }

    // MARK: - Playback Control Methods
    func togglePlayPause() {
        guard let player = player else {
            print("❌ No player available for togglePlayPause")
            return
        }
        
        print("🎵 togglePlayPause called - current isPlaying: \(isPlaying)")
        
        if isPlaying {
            player.pause()
            isPlaying = false
            print("⏸️ Player paused")
        } else {
            player.play()
            isPlaying = true
            print("▶️ Player playing")
        }
        
        updateNowPlayingInfo()
        objectWillChange.send()
    }

    func pause() {
        print("⏸️ Pause called")
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
        objectWillChange.send()
    }
    
    func resume() {
        print("▶️ Resume called")
        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
        objectWillChange.send()
    }
    
    func stop() {
        print("⏹️ Stop called")
        cleanupPlayer()
        currentSong = nil
        currentTime = 0
        duration = 0
        playbackProgress = 0
        errorMessage = nil
        audioSessionManager.clearNowPlayingInfo()
        objectWillChange.send()
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
        print("⏭️ playNext called")
        currentPlayTask?.cancel()
        playlistManager.advanceToNext()
        await playCurrent()
    }
    
    func playPrevious() async {
        print("⏮️ playPrevious called")
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
    
    // MARK: - Playlist Controls
    func toggleShuffle() {
        playlistManager.toggleShuffle()
    }
    
    func toggleRepeat() {
        playlistManager.toggleRepeat()
    }
    
    // MARK: - Volume Control
    func setVolume(_ volume: Float) {
        self.volume = volume
        player?.volume = volume
    }
    
    // MARK: - Now Playing Info
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
    
    private func updateProgress() {
        playbackProgress = duration > 0 ? currentTime / duration : 0
    }

    // MARK: - ✅ SAFE: Notification Handlers
    @objc private func handleAudioInterruptionBegan() {
        pause()
    }
    
    @objc private func handleAudioInterruptionEnded() {
        // Don't auto-resume, user needs to manually resume
    }
    
    @objc private func handleAudioInterruptionEndedShouldResume() {
        if currentSong != nil {
            resume()
        }
    }
    
    @objc private func handleAudioDeviceDisconnected() {
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

    // MARK: - Download Status Methods
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
