import Foundation
import SwiftUI
import AVFoundation

@MainActor
class PlaylistManager: ObservableObject {
    @Published private(set) var currentPlaylist: [Song] = []
    @Published private(set) var currentIndex: Int = 0
    @Published var isShuffling: Bool = false
    @Published var repeatMode: RepeatMode = .off

    enum RepeatMode { case off, all, one }

    var currentSong: Song? { currentPlaylist.indices.contains(currentIndex) ? currentPlaylist[currentIndex] : nil }

    func setPlaylist(_ songs: [Song], startIndex: Int = 0) {
        currentPlaylist = songs
        currentIndex = max(0, min(startIndex, songs.count - 1))
    }

    func nextIndex() -> Int? {
        switch repeatMode {
        case .one: return currentIndex
        case .off: let next = currentIndex + 1; return next < currentPlaylist.count ? next : nil
        case .all: return (currentIndex + 1) % currentPlaylist.count
        }
    }

    func previousIndex(currentTime: TimeInterval) -> Int {
        if currentTime > 5 { return currentIndex }
        else { return currentIndex > 0 ? currentIndex - 1 : (repeatMode == .all ? currentPlaylist.count - 1 : 0) }
    }

    func advanceToNext() { if let next = nextIndex() { currentIndex = next } }
    func moveToPrevious(currentTime: TimeInterval) { currentIndex = previousIndex(currentTime: currentTime) }
    func toggleShuffle() { isShuffling.toggle(); if isShuffling { currentPlaylist.shuffle() } }
    func toggleRepeat() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }
}

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
        duration = item.asset.duration.seconds
        setupTimeObserver()
    }

    func togglePlayPause() { guard let player = player else { return }; if isPlaying { player.pause() } else { player.play() }; isPlaying.toggle() }
    func stop() { cleanup() }
    func seek(to time: TimeInterval) { guard let player = player, duration > 0 else { return }; let clamped = max(0, min(time, duration)); player.seek(to: CMTime(seconds: clamped, preferredTimescale: CMTimeScale(NSEC_PER_SEC))); currentTime = clamped; updateProgress() }
    func setVolume(_ volume: Float) { self.volume = volume; player?.volume = volume }

    private func cleanup() { if let obs = timeObserver { player?.removeTimeObserver(obs); timeObserver = nil }; player?.pause(); player = nil; isPlaying = false; currentTime = 0; duration = 0; playbackProgress = 0 }
    private func setupTimeObserver() {
        guard let player = player else { return }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), queue: .main) { [weak self] time in
            guard let self = self else { return }
            let newTime = time.seconds
            if abs(newTime - self.lastUpdateTime) > 0.1 { self.lastUpdateTime = newTime; self.currentTime = newTime; self.updateProgress() }
        }
    }

    private func updateProgress() { playbackProgress = duration > 0 ? currentTime / duration : 0 }
}
