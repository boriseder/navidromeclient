//
//  PlayerViewModel.swift - FIXED: Pure Facade Pattern
//  NavidromeClient
//
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
    

    // MARK: - Observer Management
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var playerItemEndObserver: NSObjectProtocol?
    private var currentPlayTask: Task<Void, Never>?
    
    private var notificationObservers: [NSObjectProtocol] = []
    private var lastUpdateTime: Double = 0

    // MARK: - Dependencies
    private let songManager: SongManager
    private let downloadManager: DownloadManager
    private let audioSessionManager = AudioSessionManager.shared
    private let coverArtManager: CoverArtManager

    // MARK: - Initialization
    init(songManager: SongManager, downloadManager: DownloadManager = .shared, coverArtManager: CoverArtManager = .shared) {
        self.songManager = songManager
        self.downloadManager = downloadManager
        self.coverArtManager = coverArtManager
        
        super.init()
        setupNotifications()
        configureAudioSession()
    }
    
    // MARK: - Thread-safe deinit
    deinit {
        currentPlayTask?.cancel()
        
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        
        if let token = playerItemEndObserver {
            NotificationCenter.default.removeObserver(token)
        }
        
        notificationObservers.forEach {
            NotificationCenter.default.removeObserver($0)
        }
        
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        
        Task { @MainActor in
            AudioSessionManager.shared.clearNowPlayingInfo()
        }
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
        print("Requesting stream URL for song: \(song.id)")
        return songManager.getStreamURL(for: song.id, preferredBitRate: 192)
    }
    
    private func playCurrent() async {
        // Cancel previous task
        currentPlayTask?.cancel()
        currentPlayTask = nil
        
        // Create new task
        let task = Task {
            // Early cancellation check
            guard !Task.isCancelled else {
                print("⚠️ playCurrent cancelled before start")
                return
            }
            
            guard let song = playlistManager.currentSong else {
                print("No current song")
                await MainActor.run { stop() }
                return
            }
            
            print("Processing song: \(song.title)")
            
            await MainActor.run {
                currentSong = song
                currentAlbumId = song.albumId
                duration = Double(song.duration ?? 0)
                currentTime = 0
                isLoading = true
            }
            
            // Check cancellation before network call
            guard !Task.isCancelled else {
                print("⚠️ playCurrent cancelled before getting stream URL")
                await MainActor.run { isLoading = false }
                return
            }
            
            print("Getting stream URL...")
            
            if let streamURL = await getSimpleStreamURL(for: song) {
                // Check cancellation before playback
                guard !Task.isCancelled else {
                    print("⚠️ playCurrent cancelled before playback")
                    await MainActor.run { isLoading = false }
                    return
                }
                
                print("Got stream URL: \(streamURL)")
                await playFromURL(streamURL)
            } else {
                print("Failed to get stream URL")
                await MainActor.run {
                    errorMessage = "No playback source available"
                    isLoading = false
                }
            }
        }
        
        currentPlayTask = task
        
        // Wait with proper cancellation handling
        do {
            try await Task.sleep(nanoseconds: 1) // Allow task to start
            await task.value
        } catch {
            print("⚠️ playCurrent task cancelled")
        }
    }

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
        guard currentPlayTask?.isCancelled == false else {
            print("playFromURL cancelled")
            return
        }
        
        // Preload mit Retry-Logik
        var retryCount = 0
        let maxRetries = 2
        var isBufferValid = false
        var finalURL = url
        
        while retryCount <= maxRetries && !isBufferValid {
            // Warte kurz, bevor das Asset geladen wird (Navidrome braucht Zeit zum Transkodieren)
            if retryCount == 0 {
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms initial delay
            }
            
            isBufferValid = await preloadAudioBuffer(for: finalURL)
            
            if !isBufferValid {
                retryCount += 1
                if retryCount <= maxRetries {
                    print("⚠️ Retry \(retryCount)/\(maxRetries) after buffer validation failed")
                    
                    if retryCount == 1, let song = currentSong {
                        print("🔄 Requesting fresh stream URL...")
                        if let freshURL = await getSimpleStreamURL(for: song) {
                            print("✅ Got fresh stream URL")
                            finalURL = freshURL
                        }
                    }
                    
                    try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s delay (vorher 500ms)
                }
            }
        }

        guard isBufferValid else {
            await MainActor.run {
                print("❌ Audio buffer validation failed after \(retryCount) retries")
                errorMessage = "Cannot load audio file"
                isLoading = false
            }
            
            print("⭐️ Skipping to next song due to playback error")
            await playNext()
            return
        }
        
        await setupPlayerOnMainThread(with: finalURL)
    }

    @MainActor
    private func setupPlayerOnMainThread(with url: URL) async {
        // WICHTIG: Erst alte Player-Observer komplett aufräumen
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
            print("⏱️ Old time observer removed")
        }
        
        if let token = playerItemEndObserver {
            NotificationCenter.default.removeObserver(token)
            playerItemEndObserver = nil
            print("📌 Old player item observer removed")
        }
        
        // Kurze Pause, um sicherzustellen, dass alle Observationen entfernt sind
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        // KRITISCH: Alte Player-Instanz komplett ersetzen
        player?.pause()
        player = nil // Alte Instanz freigeben
        
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        // Neue Player-Instanz erstellen
        let item = AVPlayerItem(url: url)
        
        // Status observer für neue Instanz
        setupPlayerItemStatusObserver(for: item)
        
        player = AVPlayer(playerItem: item)
        player?.volume = volume
        player?.automaticallyWaitsToMinimizeStalling = true
        
        isPlaying = true
        isLoading = false
        
        player?.play()
        print("✅ New player created and playing from: \(url.lastPathComponent)")
        
        // Neue Observer für neue Instanz
        setupPlayerItemObserver(for: item)
        setupTimeObserver()
        updateNowPlayingInfo()
        logStreamDiagnostics(for: url)
    }


    private func preloadAudioBuffer(for url: URL) async -> Bool {
        print("🔍 Validating audio buffer for: \(url.lastPathComponent)")
        
        let asset = AVURLAsset(url: url)
        
        do {
            // Nur Tracks laden, NICHT duration
            let tracks = try await withThrowingTaskGroup(of: [AVAssetTrack].self) { group in
                group.addTask {
                    try await asset.loadTracks(withMediaType: .audio)
                }
                
                group.addTask {
                    try await Task.sleep(nanoseconds: 10_000_000_000) // 10s timeout
                    throw URLError(.timedOut)
                }
                
                guard let result = try await group.next() else {
                    throw URLError(.timedOut)
                }
                
                group.cancelAll()
                
                return result
            }
            
            guard let track = tracks.first else {
                print("❌ No audio track found")
                return false
            }
            
            // Format validieren
            let formatDescriptions = try await track.load(.formatDescriptions)
            guard let formatDesc = formatDescriptions.first else {
                print("❌ No format description")
                return false
            }
            
            if let audioFormat = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee {
                guard audioFormat.mSampleRate > 0, audioFormat.mChannelsPerFrame > 0 else {
                    print("❌ Invalid audio format: \(audioFormat.mSampleRate)Hz, \(audioFormat.mChannelsPerFrame) channels")
                    return false
                }
                
                print("✅ Audio validated: \(audioFormat.mSampleRate)Hz, \(audioFormat.mChannelsPerFrame) channels")
                return true
            }
            
            print("❌ Could not read audio format")
            return false
            
        } catch {
            print("❌ Audio buffer preload failed: \(error.localizedDescription)")
            if let urlError = error as? URLError {
                print("   URL Error code: \(urlError.code.rawValue)")
            } else if let avError = error as? AVError {
                print("   AVError code: \(avError.code.rawValue)")
            }
            return false
        }
    }

    private func setupPlayerItemStatusObserver(for item: AVPlayerItem) {
        // Observe status changes
        Task {
            for await status in item.observeStatus() {
                await handlePlayerItemStatusChange(status, for: item)
            }
        }
    }

    private func handlePlayerItemStatusChange(_ status: AVPlayerItem.Status, for item: AVPlayerItem) async {
        switch status {
        case .readyToPlay:
            print("✅ Player item ready to play")
            
            // Duration aktualisieren wenn verfügbar
            if !item.duration.seconds.isNaN && item.duration.seconds.isFinite {
                await MainActor.run {
                    self.duration = item.duration.seconds
                    print("📊 Duration updated: \(item.duration.seconds)s")
                }
            }
            
        case .failed:
            if let error = item.error {
                print("❌ Player item failed: \(error.localizedDescription)")
                await MainActor.run {
                    handlePlaybackError(error)
                }
            }
            
        case .unknown:
            print("⚠️ Player item status unknown")
            
        @unknown default:
            print("⚠️ Player item unknown status: \(status.rawValue)")
        }
    }

    // MARK: - Download Status Methods
    func isAlbumDownloaded(_ albumId: String) -> Bool {
        let isDownloaded = downloadManager.isAlbumDownloaded(albumId)
        if isDownloaded {
            print("Album \(albumId) is available offline")
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
        print("Preferred streaming quality set to \(bitRate) kbps")
    }
    
    func getCurrentMediaInfo() async -> MediaInfo? {
        guard let song = currentSong else {
            print("No current song for media info")
            return nil
        }
        
        // Delegate to SongManager which has service access
        // Note: You'll need to add this method to SongManager
        return nil
    }
        
    // MARK: - Observer Setup Methods
    private func setupNotifications() {
        let center = NotificationCenter.default
        
        notificationObservers.append(
            center.addObserver(
                forName: .audioInterruptionBegan,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleAudioInterruptionBegan()
            }
        )
        
        notificationObservers.append(
            center.addObserver(
                forName: .audioInterruptionEnded,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleAudioInterruptionEnded()
            }
        )
        
        notificationObservers.append(
            center.addObserver(
                forName: .audioInterruptionEndedShouldResume,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleAudioInterruptionEndedShouldResume()
            }
        )
        
        notificationObservers.append(
            center.addObserver(
                forName: .audioDeviceDisconnected,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleAudioDeviceDisconnected()
            }
        )
        
        print("PlayerViewModel: All notification observers setup completed")
    }
    
    private func configureAudioSession() {
        _ = audioSessionManager.isAudioSessionActive
        print("PlayerViewModel: Audio session configured")
    }
    
    private func cleanupPlayer() {
        print("Starting player cleanup")
        
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

    @MainActor
    private func setupTimeObserver() {
        guard let player = player else {
            print("⚠️ Cannot setup time observer: no player")
            return
        }
        
        // Alte Observer entfernen falls vorhanden
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 2, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
            queue: .main
        ) { [weak self] time in
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
        
        print("⏱️ Time observer setup complete")
    }
    
    // MARK: - Error Handling

    private func handlePlaybackError(_ error: Error) {
        print("Playback error: \(error.localizedDescription)")
        errorMessage = "Playback failed"
        
        // Try offline fallback
        if let song = currentSong,
           let localURL = downloadManager.getLocalFileURL(for: song.id) {
            print("Attempting offline fallback")
            Task { await playFromURL(localURL) }
            return
        }
        
        // Skip to next song
        print("Skipping to next song")
        Task { await playNext() }
    }

    // MARK: - Playback Control Methods
    func togglePlayPause() {
        guard let player = player else {
            print("No player available for togglePlayPause")
            return
        }
        
        print("togglePlayPause called - current isPlaying: \(isPlaying)")
        
        if isPlaying {
            player.pause()
            isPlaying = false
            print("Player paused")
        } else {
            player.play()
            isPlaying = true
            print("Player playing")
        }
        
        updateNowPlayingInfo()
        objectWillChange.send()
    }

    func pause() {
        print("Pause called")
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
        objectWillChange.send()
    }
    
    func resume() {
        print("Resume called")
        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
        objectWillChange.send()
    }
    
    func stop() {
        print("Stop called")
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
        print("playNext called")
        currentPlayTask?.cancel()
        playlistManager.advanceToNext()
        await playCurrent()
    }
    
    func playPrevious() async {
        print("playPrevious called")
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
        
        let albumId = currentAlbumId ?? ""
        let artwork = coverArtManager.getAlbumImage(for: albumId, size: 300)
        
        audioSessionManager.updateNowPlayingInfo(
            title: song.title,
            artist: song.artist ?? "Unknown Artist",
            album: song.album,
            artwork: artwork,
            duration: duration,
            currentTime: currentTime,
            playbackRate: isPlaying ? 1.0 : 0.0
        )
    }

    private func updateProgress() {
        playbackProgress = duration > 0 ? currentTime / duration : 0
    }

    // MARK: - Notification Handlers
    private func handleAudioInterruptionBegan() {
        pause()
    }
    
    private func handleAudioInterruptionEnded() {
    }
    
    private func handleAudioInterruptionEndedShouldResume() {
        if currentSong != nil {
            resume()
        }
    }
    
    private func handleAudioDeviceDisconnected() {
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
    
    private func logStreamDiagnostics(for url: URL) {
        // print("Stream URL: \(url)")
        // print("Host: \(url.host ?? "unknown")")
        // print("Path: \(url.path)")
        
        if url.query?.contains("maxBitRate") == true {
            print("Transcoding requested")
        } else {
            print("Direct stream")
        }
    }
}

extension PlayerViewModel {
    
    // MARK: - Queue Navigation
    
    func jumpToSong(at index: Int) async {
        guard playlistManager.currentPlaylist.indices.contains(index) else {
            print("Cannot jump to invalid queue index: \(index)")
            return
        }
        
        playlistManager.jumpToSong(at: index)
        await playCurrent()
    }
    
    // MARK: - Queue Management
    
    func removeQueueSongs(at indices: [Int]) async {
        guard !indices.isEmpty else { return }
        
        let wasCurrentSongRemoved = indices.contains(playlistManager.currentIndex)
        playlistManager.removeSongs(at: indices)
        
        if wasCurrentSongRemoved {
            if playlistManager.currentPlaylist.isEmpty {
                stop()
            } else {
                await playCurrent()
            }
        }
    }
    
    func moveQueueSongs(from sourceIndices: [Int], to destinationIndex: Int) async {
        guard !sourceIndices.isEmpty else { return }
        
        let wasCurrentSongMoved = sourceIndices.contains(playlistManager.currentIndex)
        playlistManager.moveSongs(from: sourceIndices, to: destinationIndex)
        
        if wasCurrentSongMoved && !playlistManager.currentPlaylist.isEmpty {
            await playCurrent()
        }
    }
    
    func shuffleUpNext() async {
        playlistManager.shuffleUpNext()
        objectWillChange.send()
    }
    
    func clearQueue() async {
        playlistManager.clearUpNext()
        objectWillChange.send()
    }
    
    func addToQueue(_ songs: [Song]) async {
        playlistManager.addToQueue(songs)
        objectWillChange.send()
    }
    
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
}

// MARK: - Supporting Types
enum RepeatMode: String, Codable, CaseIterable {
    case off, all, one
}

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

// Extension to observe AVPlayerItem status changes
extension AVPlayerItem {
    func observeStatus() -> AsyncStream<Status> {
        AsyncStream { continuation in
            let observation = observe(\.status, options: [.new]) { item, change in
                if let newStatus = change.newValue {
                    continuation.yield(newStatus)
                }
            }
            
            continuation.onTermination = { _ in
                observation.invalidate()
            }
        }
    }
}

