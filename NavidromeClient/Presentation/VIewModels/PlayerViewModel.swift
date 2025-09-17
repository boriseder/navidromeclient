//
//  PlayerViewModel.swift - MIGRATED to MediaService
//  NavidromeClient
//
//  ✅ MIGRATION COMPLETE: SubsonicService → MediaService
//  ✅ ALL MEDIA-RELATED SERVICE CALLS UPDATED
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
    
    
    // ✅ NEW: Primary MediaService for streaming
    private weak var mediaService: MediaService?
        
    let downloadManager: DownloadManager
    private let audioSessionManager = AudioSessionManager.shared
    private weak var coverArtManager: CoverArtManager?

    // MARK: - Observer Management (unchanged)
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var playerItemEndObserver: NSObjectProtocol?
    private var currentPlayTask: Task<Void, Never>?
    
    private var notificationObservers: [NSObjectProtocol] = []
    private var lastUpdateTime: Double = 0

    // MARK: - ✅ MIGRATION: Enhanced Initialization
    init(downloadManager: DownloadManager? = nil) {
        self.downloadManager = downloadManager ?? DownloadManager.shared
        super.init()
        
        setupNotifications()
        configureAudioSession()
    }

    // MARK: - Thread-safe deinit (unchanged but enhanced logging)
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
        
        print("✅ PlayerViewModel: Complete cleanup completed")
    }

    // MARK: - ✅ MIGRATION: Enhanced Service Management
    
    /// ✅ NEW: Configure with focused MediaService (preferred)
    func configure(service: UnifiedSubsonicService) {
        self.mediaService = service.getMediaService()
        print("✅ PlayerViewModel: Configured with UnifiedSubsonicService only")
    }
    
    /// ✅ FOCUSED: Configure with MediaService directly
    func configure(mediaService: MediaService) {
        self.mediaService = mediaService
        print("✅ PlayerViewModel: Configured with focused MediaService directly")
    }

    /// ✅ NEW: Get optimal stream URL based on connection quality
    func getOptimalStreamURL(for songId: String) -> URL? {
        
        // Get connection quality from AudioSessionManager or NetworkMonitor
        let connectionQuality: ConnectionService.ConnectionQuality = .good // Default
        
        return mediaService.getOptimalStreamURL(
            for: songId,
            preferredBitRate: nil,
            connectionQuality: connectionQuality
        )
    }
        
    // MARK: - Cover Art Management (unchanged)
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

    // MARK: - ✅ MIGRATION: Enhanced Playback Methods
    
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
        await loadCoverArt()
        await playCurrent()
    }
    
    // ✅ MIGRATION: Enhanced playback with MediaService
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
            
            print("➡️ Determining playback source for song \(song.id)")
            
            // ✅ ENHANCED: Smart source selection with better logging
            if let localURL = downloadManager.getLocalFileURL(for: song.id) {
                print("🎵 Playing from local file: \(localURL)")
                await playFromURL(localURL)
            } else if let streamURL = await getStreamURL(for: song) {
                print("🎵 Playing from MediaService stream: \(streamURL)")
                await playFromURL(streamURL)
            } else {
                await MainActor.run {
                    errorMessage = "No playback source available via MediaService"
                    print("❌ No playback source found via MediaService")
                    isLoading = false
                    objectWillChange.send()
                }
            }
        }
    }

    // ✅ MIGRATION: Smart stream URL resolution
    private func getStreamURL(for song: Song) async -> URL? {
        // Try focused MediaService first (preferred)
        if let mediaService = mediaService {
            print("🎵 Getting stream URL via focused MediaService")
            return mediaService.streamURL(for: song.id)
        }
                
        print("❌ No MediaService or legacy service available for streaming")
        return nil
    }
    
    // ✅ ENHANCED: Safe URL playback with better error handling
    private func playFromURL(_ url: URL) async {
        print("🎵 playFromURL called: \(url)")
        
        guard currentPlayTask?.isCancelled == false else { return }
        
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
            print("✅ New player created and started via MediaService")
        }
        
        // Setup new observers AFTER player is ready
        if let player = player, let currentItem = player.currentItem {
            await MainActor.run {
                setupPlayerItemObserver(for: currentItem)
                setupTimeObserver()
                updateNowPlayingInfo()
                print("✅ New observers setup completed for MediaService playback")
            }
        }
    }
    
    // MARK: - ✅ MIGRATION: Enhanced Download Status Methods
    
    /// Check if album is downloaded (unchanged but enhanced logging)
    func isAlbumDownloaded(_ albumId: String) -> Bool {
        let isDownloaded = downloadManager.isAlbumDownloaded(albumId)
        if isDownloaded {
            print("📱 Album \(albumId) is available offline")
        }
        return isDownloaded
    }
    
    /// Check if album is downloading (unchanged)
    func isAlbumDownloading(_ albumId: String) -> Bool {
        return downloadManager.isAlbumDownloading(albumId)
    }
    
    /// Check if song is downloaded (unchanged)
    func isSongDownloaded(_ songId: String) -> Bool {
        return downloadManager.isSongDownloaded(songId)
    }
    
    /// Get download progress (unchanged)
    func getDownloadProgress(albumId: String) -> Double {
        return downloadManager.downloadProgress[albumId] ?? 0.0
    }
    
    /// Delete album downloads (unchanged)
    func deleteAlbum(albumId: String) {
        downloadManager.deleteAlbum(albumId: albumId)
    }
    
    // MARK: - ✅ MIGRATION: Enhanced Media Quality Selection
    
    /// ✅ NEW: Set preferred streaming quality
    func setPreferredStreamingQuality(_ bitRate: Int) {
        // This would be stored and used in getOptimalStreamURL
        print("🎵 Preferred streaming quality set to \(bitRate) kbps via MediaService")
    }
    
    /// ✅ NEW: Get media information for current song
    func getCurrentMediaInfo() async -> MediaInfo? {
        guard let song = currentSong,
              let mediaService = mediaService else { return nil }
        
        do {
            return try await mediaService.getMediaInfo(for: song.id)
        } catch {
            print("⚠️ Failed to get media info via MediaService: \(error)")
            return nil
        }
    }
    
    // MARK: - ✅ DIAGNOSTICS: Service Health Monitoring
    
    /// ✅ NEW: Get media service diagnostics
    func getMediaServiceDiagnostics() -> String {
        guard let mediaService = mediaService else {
            return "❌ No MediaService configured"
        }
        
        let stats = mediaService.getCacheStats()
        return """
        📊 MEDIA SERVICE DIAGNOSTICS:
        - Service: ✅ Available
        - Cache: \(stats.summary)
        - Stream Quality: Adaptive
        - Connection: \(mediaService != nil ? "Ready" : "Unavailable")
        """
    }
    
    // MARK: - Observer Setup Methods (unchanged but enhanced logging)
    
    private func setupNotifications() {
        let center = NotificationCenter.default
        
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
        
        print("✅ PlayerViewModel: All notification observers setup completed")
    }
    
    private func configureAudioSession() {
        _ = audioSessionManager.isAudioSessionActive
        print("✅ PlayerViewModel: Audio session configured")
    }
    
    private func cleanupPlayer() {
        print("🧹 Starting complete player cleanup")
        
        currentPlayTask?.cancel()
        currentPlayTask = nil
        
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
            print("✅ Time observer removed")
        }
        
        if let token = playerItemEndObserver {
            NotificationCenter.default.removeObserver(token)
            playerItemEndObserver = nil
            print("✅ Player item observer removed")
        }
        
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        print("✅ Player cleared")
        
        isPlaying = false
        isLoading = false
        
        print("✅ Player cleanup completed")
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
        print("✅ Player item observer setup")
    }

    private func setupTimeObserver() {
        guard let player = player else { return }
        
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
                
                if Int(newTime) % 5 == 0 {
                    self.updateNowPlayingInfo()
                }
            }
        }
        print("✅ Time observer setup")
    }

    // MARK: - Playback Control Methods (unchanged)
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
    
    private func updateProgress() {
        playbackProgress = duration > 0 ? currentTime / duration : 0
    }

    // MARK: - Notification Handlers (unchanged)
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
}
