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
    
    @Published private var cachedNowPlayingCoverArt: UIImage?
    private var cachedNowPlayingAlbumId: String?

    @Published private(set) var audioErrors: [AudioError] = []
    private var errorObserver: NSObjectProtocol?
    
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
    init(service: UnifiedSubsonicService? = nil) {
        // Access shared instance from main actor context
        self.downloadManager = DownloadManager.shared
        
        if let service = service {
            self.mediaService = service.getMediaService()
        }
        
        super.init()
        
        setupNotifications()
        configureAudioSession()
    }
    // MARK: - Thread-safe deinit
    deinit {
        // Cancel ongoing tasks first
        currentPlayTask?.cancel()
        
        // Clean up observers synchronously
        if let observer = errorObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.forEach {
            NotificationCenter.default.removeObserver($0)
        }
        
        // Schedule cleanup on main actor without capturing self
        let player = self.player
        let timeObserver = self.timeObserver
        let playerItemEndObserver = self.playerItemEndObserver
        
        Task { @MainActor in
            if let observer = timeObserver, let player = player {
                player.removeTimeObserver(observer)
            }
            
            if let token = playerItemEndObserver {
                NotificationCenter.default.removeObserver(token)
            }
            
            player?.pause()
            player?.replaceCurrentItem(with: nil)
            
            AudioSessionManager.shared.clearNowPlayingInfo()
        }
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
    
    private func getSimpleStreamURL(for song: Song) async -> URL? {
        guard let mediaService = mediaService else {
            print("No MediaService available")
            return nil
        }
        
        print("Requesting optimal stream URL for song: \(song.id)")
        
        // Use transcoded stream without timeout wrapper
        return await mediaService.getOptimalStreamURL(
            for: song.id,
            preferredBitRate: 192,
            connectionQuality: .good
        )
    }
    private func playCurrent() async {
        print("🎵 playCurrent called")
        
        // Simple cancellation
        currentPlayTask?.cancel()
        
        currentPlayTask = Task {
            guard !Task.isCancelled else {
                print("❌ Task cancelled before start")
                return
            }
            
            guard let song = playlistManager.currentSong else {
                print("❌ No current song")
                await MainActor.run { stop() }
                return
            }
            
            print("🎵 Processing song: \(song.title)")
            
            await MainActor.run {
                currentSong = song
                currentAlbumId = song.albumId
                cachedNowPlayingCoverArt = nil
                cachedNowPlayingAlbumId = nil
                duration = Double(song.duration ?? 0)
                currentTime = 0
                isLoading = true
            }
            
            print("🔍 Getting stream URL...")
            
            // Simple stream URL without timeout wrapper
            if let streamURL = await getSimpleStreamURL(for: song) {
                print("Got stream URL: \(streamURL)")
                await playFromURL(streamURL)
            } else {
                print("❌ Failed to get stream URL")
                await MainActor.run {
                    errorMessage = "No playback source available"
                    isLoading = false
                }
            }
        }
        
        await currentPlayTask?.value
    }
    
    private func getStreamURL(for song: Song) async -> URL? {
        guard let mediaService = mediaService else {
            print("No MediaService available for streaming")
            return nil
        }
        
        // Add timeout and retry logic
        for attempt in 1...3 {
            do {
                return try await withTimeout(seconds: 10) {
                    return await mediaService.getOptimalStreamURL(
                        for: song.id,
                        preferredBitRate: 256,
                        connectionQuality: .good
                    )
                }
            } catch {
                print("Attempt \(attempt) failed: \(error)")
                if attempt < 3 {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                }
            }
        }
        
        return nil
    }

    // Helper function for timeout
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async -> T?) async throws -> T? {
        return try await withThrowingTaskGroup(of: T?.self) { group in
            group.addTask {
                return await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return nil
            }
            
            guard let result = try await group.next() else {
                throw URLError(.timedOut)
            }
            
            group.cancelAll()
            return result
        }
    }


    private func playFromURL(_ url: URL) async {
        print("🎮 playFromURL called with: \(url)")
        
        guard currentPlayTask?.isCancelled == false else {
            print("❌ playFromURL cancelled")
            return
        }
                
        // Preload and validate
        guard await preloadAudioBuffer(for: url) else {
            await MainActor.run {
                errorMessage = "Cannot load audio file"
                isLoading = false
            }
            return
        }
        
        await MainActor.run {
            // Clean up old player first
            if let observer = timeObserver {
                player?.removeTimeObserver(observer)
                timeObserver = nil
            }
            
            if let token = playerItemEndObserver {
                NotificationCenter.default.removeObserver(token)
                playerItemEndObserver = nil
            }
            
            // Stop current player gracefully
            player?.pause()
            
            // Brief pause to allow audio system to stabilize
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                
                await MainActor.run {
                    player?.replaceCurrentItem(with: nil)
                    
                    let item = AVPlayerItem(url: url)
                    player = AVPlayer(playerItem: item)
                    player?.volume = volume
                    
                    // Wait for player to be ready
                    player?.automaticallyWaitsToMinimizeStalling = true
                    
                    isPlaying = true
                    isLoading = false
                    
                    player?.play()
                    print("New player created with buffer optimization")
                    
                    setupPlayerItemObserver(for: item)
                    setupTimeObserver()
                    updateNowPlayingInfo()
                   
                    logStreamDiagnostics(for: url)

                }
            }
        }
    }
    private func preloadAudioBuffer(for url: URL) async -> Bool {
        let asset = AVURLAsset(url: url)
        
        do {
            let duration = try await asset.load(.duration)
            return duration.seconds > 0
        } catch {
            print("Failed to preload audio: \(error)")
            return false
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
        
        // FIXED: Cancel current task first
        currentPlayTask?.cancel()
        currentPlayTask = nil
        
        // FIXED: Thread-safe observer cleanup
        Task { @MainActor in
            if let observer = timeObserver, let player = player {
                player.removeTimeObserver(observer)
                timeObserver = nil
                print("Time observer removed")
            }
            
            if let token = playerItemEndObserver {
                NotificationCenter.default.removeObserver(token)
                playerItemEndObserver = nil
                print("Player item observer removed")
            }
            
            // FIXED: Proper cleanup sequence
            player?.pause()
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms grace period
            player?.replaceCurrentItem(with: nil)
            player = nil
            print("Player cleared")
            
            isPlaying = false
            isLoading = false
            
            print("Player cleanup completed")
        }
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

    @MainActor
    private func setupTimeObserver() {
        guard let player = player else { return }
        
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 2, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self = self else { return }
                let newTime = time.seconds
                
                if abs(newTime - self.lastUpdateTime) > 0.1 {
                    self.lastUpdateTime = newTime
                    self.currentTime = newTime
                    self.updateProgress()
                    
                    if Int(newTime) % 60 == 0 {
                        self.updateNowPlayingInfo()
                    }
                }
            }
        }
    }

    private func validateAudioFormat(for url: URL) async -> Bool {
        let asset = AVURLAsset(url: url)
        
        do {
            let tracks = try await asset.loadTracks(withMediaType: .audio)
            guard let track = tracks.first else {
                print("No audio track found")
                return false
            }
            
            let formatDescriptions = try await track.load(.formatDescriptions)
            if let formatDesc = formatDescriptions.first {
                let audioFormat = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)
                if let format = audioFormat?.pointee {
                    print("Audio format: \(format.mSampleRate)Hz, \(format.mChannelsPerFrame) channels")
                    return format.mSampleRate > 0 && format.mChannelsPerFrame > 0
                }
            }
        } catch {
            print("Audio validation failed: \(error)")
            return false
        }
        
        return false
    }
    
    // MARK: - Error Handling
    @MainActor
    private func setupAudioErrorMonitoring() {
        errorObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handlePlayerError(notification)
            }
        }
    }

    private func handlePlayerError(_ notification: Notification) {
        if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
            let audioError = AudioError.playbackFailed(underlying: error)
            audioErrors.append(audioError)
            
            // Log structured error
            print("🔴 Audio Error: \(audioError.localizedDescription)")
            
            // Attempt recovery based on error type
            attemptErrorRecovery(for: audioError)
        }
    }
    
    private func attemptErrorRecovery(for error: AudioError) {
        switch error {
        case .playbackFailed(let underlying):
            if let nsError = underlying as NSError? {
                switch nsError.code {
                case -12864: // Common FigFilePlayer error
                    handleStreamingError()
                case -11819: // Cannot decode
                    handleCodecError()
                default:
                    handleGenericPlaybackError()
                }
            }
        case .streamInterrupted:
            handleStreamInterruption()
        case .audioSessionError:
            handleAudioSessionError()
        case .codecError:
            handleCodecError()
        }
    }
    
    private func handleStreamingError() {
        print("🔄 Attempting to recover from streaming error")
        
        // Try to use local file if available
        if let song = currentSong,
           let localURL = downloadManager.getLocalFileURL(for: song.id) {
            Task {
                await playFromURL(localURL)
            }
        } else {
            // Fallback: skip to next song
            Task {
                await playNext()
            }
        }
    }
    
    private func handleCodecError() {
        print("🔄 Codec error - skipping to next song")
        Task {
            await playNext()
        }
    }
    
    private func handleGenericPlaybackError() {
        print("🔄 Generic playback error - attempting restart")
        
        // Simple restart strategy
        if let song = currentSong {
            Task {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                    await play(song: song)
                } catch {
                    print("⚠️ Restart failed with error: \(error)")
                }            }
        }
    }
    
    private func handleStreamInterruption() {
        print("🔄 Stream interrupted - pausing playback")
        pause()
    }
    
    private func handleAudioSessionError() {
        print("🔄 Audio session error - reconfiguring")
        audioSessionManager.setupAudioSession()
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
            cachedNowPlayingCoverArt = nil
            cachedNowPlayingAlbumId = nil
            return
        }
        
        // Only fetch cover art if album changed
        let albumId = currentAlbumId ?? ""
        if albumId != cachedNowPlayingAlbumId {
            cachedNowPlayingCoverArt = coverArtManager?.getAlbumImage(for: albumId, size: 300)
            cachedNowPlayingAlbumId = albumId
        }
        
        audioSessionManager.updateNowPlayingInfo(
            title: song.title,
            artist: song.artist ?? "Unknown Artist",
            album: song.album,
            artwork: cachedNowPlayingCoverArt,
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

extension PlayerViewModel {
    
    // MARK: - Queue Navigation
    
    /// Jump to a specific song in the queue
    func jumpToSong(at index: Int) async {
        guard playlistManager.currentPlaylist.indices.contains(index) else {
            print("⚠️ Cannot jump to invalid queue index: \(index)")
            return
        }
        
        playlistManager.jumpToSong(at: index)
        await playCurrent()
    }
    
    // MARK: - Queue Management
    
    /// Remove songs from the queue
    func removeQueueSongs(at indices: [Int]) async {
        guard !indices.isEmpty else { return }
        
        let wasCurrentSongRemoved = indices.contains(playlistManager.currentIndex)
        playlistManager.removeSongs(at: indices)
        
        // If current song was removed, play the new current song
        if wasCurrentSongRemoved {
            if playlistManager.currentPlaylist.isEmpty {
                stop()
            } else {
                await playCurrent()
            }
        }
    }
    
    /// Move songs within the queue
    func moveQueueSongs(from sourceIndices: [Int], to destinationIndex: Int) async {
        guard !sourceIndices.isEmpty else { return }
        
        let wasCurrentSongMoved = sourceIndices.contains(playlistManager.currentIndex)
        playlistManager.moveSongs(from: sourceIndices, to: destinationIndex)
        
        // Update current song if it was moved
        if wasCurrentSongMoved && !playlistManager.currentPlaylist.isEmpty {
            await playCurrent()
        }
    }
    
    /// Shuffle upcoming songs in the queue
    func shuffleUpNext() async {
        playlistManager.shuffleUpNext()
        objectWillChange.send()
    }
    
    /// Clear all upcoming songs from the queue
    func clearQueue() async {
        playlistManager.clearUpNext()
        objectWillChange.send()
    }
    
    /// Add songs to the end of the queue
    func addToQueue(_ songs: [Song]) async {
        playlistManager.addToQueue(songs)
        objectWillChange.send()
    }
    
    /// Insert songs to play next
    func playNext(_ songs: [Song]) async {
        playlistManager.playNext(songs)
        objectWillChange.send()
    }
    
    // MARK: - Queue Information
    func getQueueStats() -> QueueStats {
    return QueueStats(
        totalSongs: playlistManager.currentPlaylist.count,
        currentIndex: playlistManager.currentIndex,
        upNextCount: playlistManager.getUpNextSongs().count,
        totalDuration: playlistManager.getTotalDuration(),
        remainingDuration: playlistManager.getRemainingDuration(),
        isShuffling: playlistManager.isShuffling,
        repeatMode: playlistManager.repeatMode
    )
}
    
    private func logStreamDiagnostics(for url: URL) {
        print("### logStreamDiagnostics ###")
        print("Stream URL: \(url)")
        print("Host: \(url.host ?? "unknown")")
        print("Path: \(url.path)")
        
        if url.query?.contains("maxBitRate") == true {
            print("Transcoding requested")
        } else {
            print("Direct stream")
        }
    }
}

// MARK: - Supporting Types

struct QueueStats {
    let totalSongs: Int
    let currentIndex: Int
    let upNextCount: Int
    let totalDuration: Int
    let remainingDuration: Int
    let isShuffling: Bool
    let repeatMode: PlaylistManager.RepeatMode
    
    var currentPosition: String {
        return "\(currentIndex + 1) of \(totalSongs)"
    }
    
    var formattedTotalDuration: String {
        return formatDuration(totalDuration)
    }
    
    var formattedRemainingDuration: String {
        return formatDuration(remainingDuration)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        
        if hours > 0 {
            return String(format: "%d:%02d:00", hours, minutes)
        } else {
            return String(format: "%d:00", minutes)
        }
    }
}

// Add structured error types
enum AudioError: Error, LocalizedError {
    case playbackFailed(underlying: Error)
    case streamInterrupted
    case audioSessionError(underlying: Error)
    case codecError
    
    var errorDescription: String? {
        switch self {
        case .playbackFailed(let error):
            return "Playback failed: \(error.localizedDescription)"
        case .streamInterrupted:
            return "Audio stream was interrupted"
        case .audioSessionError(let error):
            return "Audio session error: \(error.localizedDescription)"
        case .codecError:
            return "Audio codec error - unsupported format"
        }
    }
    
    var recoveryAction: String {
        switch self {
        case .playbackFailed:
            return "Attempting to use offline version or skip to next song"
        case .streamInterrupted:
            return "Pausing playback until stream recovers"
        case .audioSessionError:
            return "Reconfiguring audio session"
        case .codecError:
            return "Skipping to next compatible song"
        }
    }
}


// MARK: - Queue Actions for Context Menus

struct QueueContextActions {
    let playerVM: PlayerViewModel
    
    func playNext(song: Song) {
        Task {
            await playerVM.playNext([song])
        }
    }
    
    func addToQueue(song: Song) {
        Task {
            await playerVM.addToQueue([song])
        }
    }
    
    func addToQueue(album: Album, songs: [Song]) {
        Task {
            await playerVM.addToQueue(songs)
        }
    }
    
    func playNext(album: Album, songs: [Song]) {
        Task {
            await playerVM.playNext(songs)
        }
    }
}
