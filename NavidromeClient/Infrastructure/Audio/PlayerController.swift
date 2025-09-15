import Foundation
import SwiftUI
import AVFoundation

@MainActor
class PlayerController: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackProgress: Double = 0
    @Published var volume: Float = 0.7

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var lastUpdateTime: Double = 0

    func play(url: URL) {
        cleanup()
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player?.volume = volume
        player?.play()
        isPlaying = true
        
        // Enhanced duration loading for iOS 16+
        Task {
            do {
                if #available(iOS 16.0, *) {
                    let loadedDuration = try await item.asset.load(.duration)
                    await MainActor.run {
                        self.duration = loadedDuration.seconds
                    }
                } else {
                    // Fallback für iOS < 16
                    await MainActor.run {
                        self.duration = item.asset.duration.seconds
                    }
                }
            } catch {
                print("Failed to load duration: \(error)")
            }
        }
        
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
    
    func stop() { cleanup() }
    
    func seek(to time: TimeInterval) {
        guard let player = player, duration > 0 else { return }
        let clamped = max(0, min(time, duration))
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
        currentTime = clamped
        updateProgress()
    }
    
    func setVolume(_ volume: Float) {
        self.volume = volume
        player?.volume = volume
    }

    private func cleanup() {
        if let obs = timeObserver {
            player?.removeTimeObserver(obs)
            timeObserver = nil
        }
        player?.pause()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        playbackProgress = 0
    }
    
    private func setupTimeObserver() {
        guard let player = player else { return }
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self = self else { return }
                let newTime = time.seconds
                if abs(newTime - self.lastUpdateTime) > 0.1 {
                    self.lastUpdateTime = newTime
                    self.currentTime = newTime
                    self.updateProgress()
                }
            }
        }
    }

    private func updateProgress() {
        playbackProgress = duration > 0 ? currentTime / duration : 0
    }
}
