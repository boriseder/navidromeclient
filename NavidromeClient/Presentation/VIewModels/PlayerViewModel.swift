//
//  PlayerViewModel.swift - FIXED: Complete @Published Grouping Implementation
//  NavidromeClient
//
//   FIXED: 3 grouped @Published properties instead of 11 individual ones
//   PRESERVED: All existing functionality and public API
//   IMPROVED: Single state updates for better performance
//

import Foundation
import SwiftUI
import AVFoundation
import MediaPlayer

@MainActor
class PlayerViewModel: NSObject, ObservableObject {
    // MARK: - ✅ GROUPED STATE: 3 structs instead of 11 individual @Published properties
    @Published private(set) var playbackState = PlaybackState()
    @Published private(set) var progressState = ProgressState()
    @Published private(set) var audioState = AudioState()
    
    // MARK: - ✅ PRESERVED: Existing dependencies and playlist management
    @Published var playlistManager = PlaylistManager()
    
    typealias RepeatMode = PlaylistManager.RepeatMode
    
    private weak var mediaService: MediaService?
    let downloadManager: DownloadManager
    private let audioSessionManager = AudioSessionManager.shared

    // MARK: - ✅ PRESERVED: Observer Management
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var playerItemEndObserver: NSObjectProtocol?
    private var currentPlayTask: Task<Void, Never>?
    
    private var notificationObservers: [NSObjectProtocol] = []
    private var lastUpdateTime: Double = 0

    // MARK: - ✅ BACKWARDS COMPATIBLE: Public API preserved through computed properties
    var isPlaying: Bool { playbackState.isPlaying }
    var currentSong: Song? { playbackState.currentSong }
    var currentAlbumId: String? { playbackState.currentAlbumId }
    var coverArt: UIImage? { playbackState.coverArt }
    var isLoading: Bool { playbackState.isLoading }
    var errorMessage: String? { playbackState.errorMessage }
    
    var currentTime: TimeInterval { progressState.currentTime }
    var duration: TimeInterval { progressState.duration }
    var playbackProgress: Double { progressState.progress }
    
    var volume: Float { audioState.volume }
    
    // Convenience accessors for UI (UNCHANGED)
    var isShuffling: Bool { playlistManager.isShuffling }
    var repeatMode: RepeatMode { playlistManager.repeatMode }
    var currentPlaylist: [Song] { playlistManager.currentPlaylist }
    var currentIndex: Int { playlistManager.currentIndex }

    // MARK: - State Structs
    struct PlaybackState {
        var isPlaying = false
        var currentSong: Song?
        var currentAlbumId: String?
        var coverArt: UIImage?
        var isLoading = false
        var errorMessage: String?
        
        // ✅ Convenience computed properties
        var hasActiveSong: Bool { currentSong != nil }
        var isIdle: Bool { !isPlaying && !isLoading }
        var hasError: Bool { errorMessage != nil }
    }
    
    struct ProgressState {
        var currentTime: TimeInterval = 0
        var duration: TimeInterval = 0
        
        // ✅ Computed property eliminates separate @Published playbackProgress
        var progress: Double {
            guard duration > 0 else { return 0 }
            return currentTime / duration
        }
        
        var remainingTime: TimeInterval {
            return max(0, duration - currentTime)
        }
        
        var formattedCurrentTime: String {
            return formatTime(currentTime)
        }
        
        var formattedDuration: String {
            return formatTime(duration)
        }
        
        private func formatTime(_ seconds: TimeInterval) -> String {
            let minutes = Int(seconds) / 60
            let remainingSeconds = Int(seconds) % 60
            return String(format: "%d:%02d", minutes, remainingSeconds)
        }
    }
    
    struct AudioState {
        var volume: Float = 0.7
        var isMuted: Bool = false
        
        // ✅ Convenience computed properties
        var effectiveVolume: Float {
            return isMuted ? 0.0 : volume
        }
        
        var volumeIcon: String {
            if isMuted || volume == 0 { return "speaker.slash.fill" }
            else if volume < 0.3 { return "speaker.fill" }
            else if volume < 0.7 { return "speaker.wave.1.fill" }
            else { return "speaker.wave.3.fill" }
        }
    }

    // MARK: - ✅ PRESERVED: Initialization
    init(service: UnifiedSubsonicService? = nil, downloadManager: DownloadManager = DownloadManager.shared) {
        self.downloadManager = downloadManager
        
        if let service = service {
            self.mediaService = service.getMediaService()
        }
        
        super.init()
        
        setupNotifications()
        configureAudioSession()
    }

    // MARK: - Thread-safe deinit (UNCHANGED)
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

    // MARK: - ✅ NEW: State Update Methods
    private func updatePlaybackState(_ update: (inout PlaybackState) -> Void) {
        update(&playbackState)
    }
    
    private func updateProgressState(_ update: (inout ProgressState) -> Void) {
        update(&progressState)
    }
    
    private func updateAudioState(_ update: (inout AudioState) -> Void) {
        update(&audioState)
    }

    // MARK: - ✅ PRESERVED: Service Management
    func updateService(_ service: UnifiedSubsonicService?) {
        if let service = service {
            self.mediaService = service.getMediaService()
            print("✅ PlayerViewModel: MediaService updated")
        } else {
            self.mediaService = nil
            print("⚠️ PlayerViewModel: MediaService removed")
        }
    }
    
    func configure(mediaService: MediaService) {
        self.mediaService = mediaService
        print("✅ PlayerViewModel: Configured with focused MediaService directly")
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
            
    func loadCoverArt() async {
        guard let albumId = currentAlbumId else { return }
        
        // ✅ NEU: Access via DownloadManager proxy
        let loadedCoverArt = await downloadManager.getCoverArt(for: albumId, size: 300)
        updatePlaybackState { $0.coverArt = loadedCoverArt }
        
        updateNowPlayingInfo()
    }


    // MARK: - ✅ UPDATED: Enhanced Playback Methods
    func play(song: Song) async {
        await setPlaylist([song], startIndex: 0, albumId: song.albumId)
    }
    
    func setPlaylist(_ songs: [Song], startIndex: Int = 0, albumId: String?) async {
        guard !songs.isEmpty else {
            updatePlaybackState { $0.errorMessage = "Playlist is empty" }
            return
        }
        
        playlistManager.setPlaylist(songs, startIndex: startIndex)
        updatePlaybackState { state in
            state.currentAlbumId = albumId
            state.errorMessage = nil
        }
        await loadCoverArt()
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
                updatePlaybackState { state in
                    state.currentSong = song
                    state.currentAlbumId = song.albumId
                    state.isLoading = true
                    state.errorMessage = nil
                }
                
                updateProgressState { state in
                    state.duration = Double(song.duration ?? 0)
                    state.currentTime = 0
                }
                
                objectWillChange.send()
            }
            
            print("🎵 Playing song: \(song.title)")
            
            guard !Task.isCancelled else {
                await MainActor.run {
                    updatePlaybackState { $0.isLoading = false }
                    objectWillChange.send()
                }
                return
            }
            
            print("➡️ Determining playback source for song \(song.id)")
            
            if let localURL = downloadManager.getLocalFileURL(for: song.id) {
                print("🎵 Playing from local file: \(localURL)")
                await playFromURL(localURL)
            } else if let streamURL = await getStreamURL(for: song) {
                print("🎵 Playing from MediaService stream: \(streamURL)")
                await playFromURL(streamURL)
            } else {
                await MainActor.run {
                    updatePlaybackState { state in
                        state.errorMessage = "No playback source available"
                        state.isLoading = false
                    }
                    print("❌ No playback source found")
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
        
        print("🎵 Getting stream URL via MediaService")
        return mediaService.streamURL(for: song.id)
    }
    
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
            player?.volume = audioState.volume
            
            // Update UI state
            updatePlaybackState { state in
                state.isPlaying = true
                state.isLoading = false
            }
            objectWillChange.send()
            
            // Start playback
            player?.play()
            print("✅ New player created and started")
        }
        
        // Setup new observers AFTER player is ready
        if let player = player, let currentItem = player.currentItem {
            await MainActor.run {
                setupPlayerItemObserver(for: currentItem)
                setupTimeObserver()
                updateNowPlayingInfo()
                print("✅ New observers setup completed")
            }
        }
    }
    
    // MARK: - ✅ PRESERVED: Download Status Methods
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
    
    // MARK: - Media Quality Selection (UNCHANGED)
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
    
    // MARK: - Service Health Monitoring (UNCHANGED)
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
        - Connection: Ready
        """
    }
    
    // MARK: - Observer Setup Methods (UNCHANGED)
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
        
        updatePlaybackState { state in
            state.isPlaying = false
            state.isLoading = false
        }
        
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

    // ✅ IMPROVED: Single state update in time observer
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
                
                // ✅ SINGLE state update instead of multiple @Published changes
                self.updateProgressState { state in
                    state.currentTime = newTime
                }
                
                if Int(newTime) % 5 == 0 {
                    self.updateNowPlayingInfo()
                }
            }
        }
        print("✅ Time observer setup")
    }

    // MARK: - ✅ UPDATED: Playback Control Methods
    func togglePlayPause() {
        guard let player = player else {
            print("❌ No player available for togglePlayPause")
            return
        }
        
        print("🎵 togglePlayPause called - current isPlaying: \(playbackState.isPlaying)")
        
        if playbackState.isPlaying {
            player.pause()
            updatePlaybackState { $0.isPlaying = false }
            print("⏸️ Player paused")
        } else {
            player.play()
            updatePlaybackState { $0.isPlaying = true }
            print("▶️ Player playing")
        }
        
        updateNowPlayingInfo()
        objectWillChange.send()
    }

    func pause() {
        print("⏸️ Pause called")
        player?.pause()
        updatePlaybackState { $0.isPlaying = false }
        updateNowPlayingInfo()
        objectWillChange.send()
    }
    
    func resume() {
        print("▶️ Resume called")
        player?.play()
        updatePlaybackState { $0.isPlaying = true }
        updateNowPlayingInfo()
        objectWillChange.send()
    }
    
    func stop() {
        print("⏹️ Stop called")
        cleanupPlayer()
        updatePlaybackState { state in
            state.currentSong = nil
            state.errorMessage = nil
        }
        updateProgressState { state in
            state.currentTime = 0
            state.duration = 0
        }
        audioSessionManager.clearNowPlayingInfo()
        objectWillChange.send()
    }

    func seek(to time: TimeInterval) {
        guard let player = player, progressState.duration > 0 else { return }
        let clampedTime = max(0, min(time, progressState.duration))
        let cmTime = CMTime(seconds: clampedTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: cmTime)
        updateProgressState { $0.currentTime = clampedTime }
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
        playlistManager.moveToPrevious(currentTime: progressState.currentTime)
        await playCurrent()
    }

    func skipForward(seconds: TimeInterval = 15) {
        let newTime = progressState.currentTime + seconds
        seek(to: newTime)
    }
    
    func skipBackward(seconds: TimeInterval = 15) {
        let newTime = progressState.currentTime - seconds
        seek(to: newTime)
    }
    
    // MARK: - Playlist Controls (UNCHANGED)
    func toggleShuffle() {
        playlistManager.toggleShuffle()
    }
    
    func toggleRepeat() {
        playlistManager.toggleRepeat()
    }
    
    // MARK: - ✅ UPDATED: Volume Control
    func setVolume(_ volume: Float) {
        updateAudioState { $0.volume = volume }
        player?.volume = audioState.effectiveVolume
    }
    
    func toggleMute() {
        updateAudioState { $0.isMuted.toggle() }
        player?.volume = audioState.effectiveVolume
    }
    
    // MARK: - Now Playing Info (UNCHANGED)
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
            duration: progressState.duration,
            currentTime: progressState.currentTime,
            playbackRate: playbackState.isPlaying ? 1.0 : 0.0
        )
    }

    // MARK: - Notification Handlers (UNCHANGED)
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
