//
//  PlayerViewModel.swift - FIXED: Remove Duplicate Cover Art System
//  NavidromeClient
//
//   FIXED: Eliminated duplicate cover art management
//   CLEAN: Single source of truth via CoverArtManager
//   REMOVED: Redundant coverArt property and loadCoverArt method
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
    // REMOVED: @Published var coverArt: UIImage?
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
    
    private weak var mediaService: MediaService?
        
    let downloadManager: DownloadManager
    private let audioSessionManager = AudioSessionManager.shared
    private weak var coverArtManager: CoverArtManager?

    // MARK: - Observer Management
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var playerItemEndObserver: NSObjectProtocol?
    private var currentPlayTask: Task<Void, Never>?
    
    private var notificationObservers: [NSObjectProtocol] = []
    private var lastUpdateTime: Double = 0

    // MARK: - Initialization
    init(service: UnifiedSubsonicService? = nil, downloadManager: DownloadManager = DownloadManager.shared) {
        self.downloadManager = downloadManager
        
        if let service = service {
            self.mediaService = service.getMediaService()
        }
        
        super.init()
        
        setupNotifications()
        configureAudioSession()
    }

    // MARK: - Thread-safe deinit
    deinit {
        currentPlayTask?.cancel()
        
        if let observer = timeObserver, let player = player {
            player.removeTimeObserver(observer)
        }
        
        if let token = playerItemEndObserver {
            NotificationCenter.default.removeObserver(token)
        }
        notificationObservers.forEach {
            NotificationCenter.default.removeObserver($0)
        }
        NotificationCenter.default.removeObserver(self)
        
        let playerToClean = player
        Task { @MainActor in
            playerToClean?.pause()
            playerToClean?.replaceCurrentItem(with: nil)
            AudioSessionManager.shared.clearNowPlayingInfo()
        }
        
        print("PlayerViewModel: Complete cleanup completed")
    }

    // MARK: - Service Management
    
    func updateService(_ service: UnifiedSubsonicService?) {
        if let service = service {
            self.mediaService = service.getMediaService()
            print("PlayerViewModel: MediaService updated")
        } else {
            self.mediaService = nil
            print("⚠️ PlayerViewModel: MediaService removed")
        }
    }
    
    func configure(mediaService: MediaService) {
        self.mediaService = mediaService
        print("PlayerViewModel: Configured with focused MediaService directly")
    }

    func getOptimalStreamURL(for songId: String) -> URL? {
        guard let mediaService = mediaService else {
            print("❌ MediaService not available for optimal stream URL")
            return nil
        }
        
        let connectionQuality: ConnectionService.ConnectionQuality = .good
        
        return mediaService.getOptimalStreamURL(
            for: songId,
            preferredBitRate: nil,
            connectionQuality: connectionQuality
        )
    }
        
    // MARK: - Cover Art Management
    func updateCoverArtService(_ newCoverArtManager: CoverArtManager) {
        self.coverArtManager = newCoverArtManager
    }
    
    // REMOVED: loadCoverArt() method - now handled by CoverArtManager directly

    // MARK: - Playback Methods
    
    func play(song: Song) async {
        await setPlaylist([song], startIndex: 0, albumId: song.albumId)
    }
    
    func setPlaylist(_ songs: [Song], startIndex: Int = 0, albumId: String?) async {
        guard !songs.isEmpty else {
            errorMessage = "Playlist is empty"
            return
        }
        
        playlistManager.setPlaylist(songs, startIndex: startIndex)
        currentAlbumId = albumId
        await playCurrent()
    }
    
    private func playCurrent() async {
        print("🎵 playCurrent called")
        
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
            
            if let localURL = downloadManager.getLocalFileURL(for: song.id) {
                await playFromURL(localURL)
            } else if let streamURL = await getStreamURL(for: song) {
                await playFromURL(streamURL)
            } else {
                await MainActor.run {
                    errorMessage = "No playback source available"
                    print("❌ No playback source found")
                    isLoading = false
                    objectWillChange.send()
                }
            }
        }
    }

    private func getStreamURL(for song: Song) async -> URL? {
        guard let mediaService = mediaService else {
            print("❌ No MediaService available for streaming")
            return nil
        }
        
        return mediaService.streamURL(for: song.id)
    }
    
    private func playFromURL(_ url: URL) async {
        
        guard currentPlayTask?.isCancelled == false else { return }
        
        await MainActor.run {
            if let observer = timeObserver {
                player?.removeTimeObserver(observer)
                timeObserver = nil
                print("Old time observer removed")
            }
            
            if let token = playerItemEndObserver {
                NotificationCenter.default.removeObserver(token)
                playerItemEndObserver = nil
                print("Old player item observer removed")
            }
            
            player?.pause()
            player?.replaceCurrentItem(with: nil)
            
            let item = AVPlayerItem(url: url)
            player = AVPlayer(playerItem: item)
            player?.volume = volume
            
            isPlaying = true
            isLoading = false
            objectWillChange.send()
            
            player?.play()
            print("New player created and started")
        }
        
        if let player = player, let currentItem = player.currentItem {
            await MainActor.run {
                setupPlayerItemObserver(for: currentItem)
                setupTimeObserver()
                updateNowPlayingInfo()
                print("New observers setup completed")
            }
        }
    }
    
    // MARK: - Download Status Methods
    
    func isAlbumDownloaded(_ albumId: String) -> Bool {
        let isDownloaded = downloadManager.isAlbumDownloaded(albumId)
        if isDownloaded {
            print("📱 Album \(albumId) is available offline")
        }
        return isDownloaded
    }
    
    func isAlbumDownloading(_ albumId: String) -> Bool {
        return downloadManager.isAlbumDownloading(albumId)
    }
    
    func isSongDownloaded(_ songId: String) -> Bool {
        return downloadManager.isSongDownloaded(songId)
    }
    
    func getDownloadProgress(albumId: String) -> Double {
        return downloadManager.downloadProgress[albumId] ?? 0.0
    }
    
    func deleteAlbum(albumId: String) {
        downloadManager.deleteAlbum(albumId: albumId)
    }
    
    // MARK: - Media Quality Selection
    
    func setPreferredStreamingQuality(_ bitRate: Int) {
        print("🎵 Preferred streaming quality set to \(bitRate) kbps")
    }
    
    func getCurrentMediaInfo() async -> MediaInfo? {
        guard let song = currentSong,
              let mediaService = mediaService else {
            print("❌ MediaService not available for media info")
            return nil
        }
        
        do {
            return try await mediaService.getMediaInfo(for: song.id)
        } catch {
            print("⚠️ Failed to get media info: \(error)")
            return nil
        }
    }
    
    // MARK: - Service Health Monitoring
    
    func getMediaServiceDiagnostics() -> String {
        guard let mediaService = mediaService else {
            return "❌ No MediaService configured"
        }
        
        let stats = mediaService.getCacheStats()
        return """
        📊 MEDIA SERVICE DIAGNOSTICS:
        - Service: Available
        - Cache: \(stats.summary)
        - Stream Quality: Adaptive
        - Connection: Ready
        """
    }
    
    // MARK: - Observer Setup Methods
    
    private func setupNotifications() {
        let center = NotificationCenter.default
        
        let observers: [(Notification.Name, Selector)] = [
            (.audioInterruptionBegan, #selector(handleAudioInterruptionBegan)),
            (.audioInterruptionEnded, #selector(handleAudioInterruptionEnded)),
            (.audioInterruptionEndedShouldResume, #selector(handleAudioInterruptionEndedShouldResume)),
            (.audioDeviceDisconnected, #selector(handleAudioDeviceDisconnected)),
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
        
        print("PlayerViewModel: All notification observers setup completed")
    }
    
    private func configureAudioSession() {
        _ = audioSessionManager.isAudioSessionActive
        print("PlayerViewModel: Audio session configured")
    }
    
    private func cleanupPlayer() {
        print("🧹 Starting complete player cleanup")
        
        currentPlayTask?.cancel()
        currentPlayTask = nil
        
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
            print("Time observer removed")
        }
        
        if let token = playerItemEndObserver {
            NotificationCenter.default.removeObserver(token)
            playerItemEndObserver = nil
            print("Player item observer removed")
        }
        
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        print("Player cleared")
        
        isPlaying = false
        isLoading = false
        
        print("Player cleanup completed")
    }

    private func setupPlayerItemObserver(for item: AVPlayerItem) {
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
        print("Player item observer setup")
    }

    private func setupTimeObserver() {
        guard let player = player else { return }
        
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
            queue: .main
        ) { [weak self] time in
            guard let self = self else { return }
            let newTime = time.seconds
            
            if abs(newTime - self.lastUpdateTime) > 0.1 {
                self.lastUpdateTime = newTime
                self.currentTime = newTime
                self.updateProgress()
                
                if Int(newTime) % 5 == 0 {
                    self.updateNowPlayingInfo()
                }
            }
        }
        print("Time observer setup")
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
    
    // MARK: - Now Playing Info - FIXED: Use CoverArtManager
    private func updateNowPlayingInfo() {
        guard let song = currentSong else {
            audioSessionManager.clearNowPlayingInfo()
            return
        }
        
        // Get cover art from CoverArtManager instead of local property
        let coverArt = coverArtManager?.getAlbumImage(for: currentAlbumId ?? "", size: 300)
        
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

    // MARK: - Notification Handlers
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
    
    func handleRemotePlay() {
        if currentSong != nil {
            resume()
        }
    }

    func handleRemotePause() {
        pause()
    }

    func handleRemoteTogglePlayPause() {
        togglePlayPause()
    }

    func handleRemoteNextTrack() {
        Task { [weak self] in
            await self?.playNext()
        }
    }

    func handleRemotePreviousTrack() {
        Task { [weak self] in
            await self?.playPrevious()
        }
    }

    func handleRemoteSeek(to time: TimeInterval) {
        seek(to: time)
    }

    func handleRemoteSkipForward(interval: TimeInterval) {
        skipForward(seconds: interval)
    }

    func handleRemoteSkipBackward(interval: TimeInterval) {
        skipBackward(seconds: interval)
    }
}
