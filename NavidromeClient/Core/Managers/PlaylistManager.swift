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
