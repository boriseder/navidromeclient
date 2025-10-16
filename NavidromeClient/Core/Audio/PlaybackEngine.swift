import Foundation
import AVFoundation

// MARK: - PlaybackEngine Delegate Protocol

protocol PlaybackEngineDelegate: AnyObject {
    func playbackEngine(_ engine: PlaybackEngine, didUpdateTime time: TimeInterval)
    func playbackEngine(_ engine: PlaybackEngine, didUpdateDuration duration: TimeInterval)
    func playbackEngine(_ engine: PlaybackEngine, didChangePlayingState isPlaying: Bool)
    func playbackEngine(_ engine: PlaybackEngine, didFinishPlaying successfully: Bool)
    func playbackEngine(_ engine: PlaybackEngine, didEncounterError error: String)
}

// MARK: - PlaybackEngine

@MainActor
class PlaybackEngine {
    
    // MARK: - Properties
    
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var playerItemObserver: NSObjectProtocol?
    
    weak var delegate: PlaybackEngineDelegate?
    
    var volume: Float {
        get { player?.volume ?? 0.7 }
        set { player?.volume = newValue }
    }
    
    var currentTime: TimeInterval {
        player?.currentTime().seconds ?? 0
    }
    
    var duration: TimeInterval {
        player?.currentItem?.duration.seconds ?? 0
    }
    
    var isPlaying: Bool {
        player?.timeControlStatus == .playing
    }
    
    // MARK: - Initialization
    
    init() {}
    
    deinit {
        // Synchronous cleanup for deinit
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        
        if let observer = playerItemObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        player?.pause()
        player?.replaceCurrentItem(with: nil)
    }
    
    // MARK: - Playback Control
    
    func play(url: URL) async {
        cleanup()
        
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player?.automaticallyWaitsToMinimizeStalling = true
        
        setupObservers()
        
        player?.play()
        delegate?.playbackEngine(self, didChangePlayingState: true)
        
        AppLogger.general.info("PlaybackEngine: Started playback for \(url.lastPathComponent)")
    }
    
    func pause() {
        player?.pause()
        delegate?.playbackEngine(self, didChangePlayingState: false)
        AppLogger.general.info("PlaybackEngine: Paused")
    }
    
    func resume() {
        player?.play()
        delegate?.playbackEngine(self, didChangePlayingState: true)
        AppLogger.general.info("PlaybackEngine: Resumed")
    }
    
    func stop() {
        cleanup()
        delegate?.playbackEngine(self, didChangePlayingState: false)
        AppLogger.general.info("PlaybackEngine: Stopped")
    }
    
    func seek(to time: TimeInterval) {
        guard let player = player else { return }
        
        let clampedTime = max(0, min(time, duration))
        let cmTime = CMTime(seconds: clampedTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        player.seek(to: cmTime) { [weak self] finished in
            if finished, let self = self {
                Task { @MainActor in
                    self.delegate?.playbackEngine(self, didUpdateTime: clampedTime)
                }
            }
        }
    }
    
    // MARK: - Observer Setup
    
    private func setupObservers() {
        guard let playerItem = player?.currentItem else { return }
        
        setupTimeObserver()
        setupPlayerItemObserver(for: playerItem)
        setupStatusObserver(for: playerItem)
    }
    
    private func setupTimeObserver() {
        guard let player = player else { return }
        
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
            queue: .main
        ) { [weak self] time in
            guard let self = self else { return }
            self.delegate?.playbackEngine(self, didUpdateTime: time.seconds)
        }
    }
    
    private func setupPlayerItemObserver(for item: AVPlayerItem) {
        playerItemObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            AppLogger.general.info("PlaybackEngine: Playback finished")
            self.delegate?.playbackEngine(self, didFinishPlaying: true)
        }
    }
    
    private func setupStatusObserver(for item: AVPlayerItem) {
        Task {
            for await status in item.observeStatus() {
                await handlePlayerStatus(status, for: item)
            }
        }
    }
    
    private func handlePlayerStatus(_ status: AVPlayerItem.Status, for item: AVPlayerItem) async {
        switch status {
        case .readyToPlay:
            let duration = item.duration.seconds
            if !duration.isNaN && duration.isFinite {
                delegate?.playbackEngine(self, didUpdateDuration: duration)
                AppLogger.general.info("PlaybackEngine: Ready to play, duration: \(duration)s")
            }
            
        case .failed:
            if let error = item.error {
                AppLogger.general.info("PlaybackEngine: Failed with error: \(error.localizedDescription)")
                delegate?.playbackEngine(self, didEncounterError: "Playback failed")
                delegate?.playbackEngine(self, didFinishPlaying: false)
            }
            
        case .unknown:
            break
            
        @unknown default:
            break
        }
    }
    
    // MARK: - Cleanup
    
    private func cleanup() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        if let observer = playerItemObserver {
            NotificationCenter.default.removeObserver(observer)
            playerItemObserver = nil
        }
        
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
    }
}

// MARK: - AVPlayerItem Extension

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
