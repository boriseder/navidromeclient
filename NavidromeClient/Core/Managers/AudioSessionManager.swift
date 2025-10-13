//
//  AudioSessionManager.swift
//  NavidromeClient
//
//  Created by Boris Eder on 11.09.25.
//

import Foundation
import AVFoundation
import MediaPlayer

@MainActor
class AudioSessionManager: NSObject, ObservableObject {
    static let shared = AudioSessionManager()
    
    @Published var isAudioSessionActive = false
    @Published var isHeadphonesConnected = false
    @Published var audioRoute: String = ""
    
    private let observerQueue = DispatchQueue(label: "audio.observers", attributes: .concurrent)
    private var audioObservers: [NSObjectProtocol] = []

    private let audioSession = AVAudioSession.sharedInstance()
    
    weak var playerViewModel: PlayerViewModel?
    
    private override init() {
        super.init()
        setupAudioSession()
        setupNotifications()
        setupRemoteCommandCenter()
        checkAudioRoute()
    }
        
    deinit {
        Task { @MainActor in
            performCleanup()
        }
    }

    // MARK: - Cleanup

    func performCleanup() {
        observerQueue.async(flags: .barrier) {
            let observers = self.audioObservers
            self.audioObservers.removeAll()
            
            DispatchQueue.main.async {
                observers.forEach { NotificationCenter.default.removeObserver($0) }
            }
        }
    }

    // MARK: - Audio Session Setup
    
    func setupAudioSession() {
        do {
            // Setze Audio Category für Hintergrund-Playback
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: [
                    .allowAirPlay,
                    .allowBluetoothHFP,
                    .allowBluetoothA2DP
                ]
            )
            
            // Aktiviere Audio Session
            try audioSession.setActive(true)
            isAudioSessionActive = true
            
            print(" Audio Session configured successfully")
            
        } catch {
            print("❌ Audio Session setup failed: \(error)")
            isAudioSessionActive = false
        }
    }
    
    // MARK: - Thread-safe Notifications Setup
    
    private func setupNotifications() {
        let center = NotificationCenter.default
        
        let interruptionObserver = center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: audioSession,
            queue: .main
        ) { [weak self] notification in
            self?.handleInterruptionNotification(notification)
        }
        
        audioObservers.append(interruptionObserver)
    }
    
    // MARK: - Enhanced Command Center Setup
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Play Command
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.handleRemotePlay()
            return .success
        }
        
        // Pause Command
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.handleRemotePause()
            return .success
        }
        
        // Toggle Play/Pause
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.handleRemoteTogglePlayPause()
            return .success
        }
        
        // Next Track
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.handleRemoteNextTrack()
            return .success
        }
        
        // Previous Track
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.handleRemotePreviousTrack()
            return .success
        }
        
        // Seeking
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                self?.handleRemoteSeek(to: event.positionTime)
                return .success
            }
            return .commandFailed
        }
        
        // Skip Forward/Backward
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [NSNumber(value: 15)]
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            if let event = event as? MPSkipIntervalCommandEvent {
                self?.handleRemoteSkipForward(interval: event.interval)
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [NSNumber(value: 15)]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            if let event = event as? MPSkipIntervalCommandEvent {
                self?.handleRemoteSkipBackward(interval: event.interval)
                return .success
            }
            return .commandFailed
        }
    }
    
    // MARK: - Now Playing Info (Lock Screen Display)

    func updateNowPlayingInfo(
        title: String,
        artist: String,
        album: String? = nil,
        artwork: UIImage? = nil,
        duration: TimeInterval,
        currentTime: TimeInterval,
        playbackRate: Float = 1.0
    ) {
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: playbackRate
        ]
        
        if let album = album {
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = album
        }
        
        if let artwork = artwork {
            let artworkItem = MPMediaItemArtwork(boundsSize: CGSize(width: 300, height: 300)) { _ in
                return artwork
            }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artworkItem
        }
        
        DispatchQueue.main.async {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        }
        print("Updated Now Playing Info: \(title) - \(artist)")
    }
    
    func handleAppBecameActive() {
        do {
            try audioSession.setActive(true)
            print("Audio session reactivated")
        } catch {
            print("❌ Failed to reactivate audio session: \(error)")
        }
    }

    func handleAppWillTerminate() {
        performCleanup()
        
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("❌ Failed to deactivate audio session: \(error)")
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        print("🔇 Cleared Now Playing Info")
    }
    
    // MARK: - Audio Route Management
    private func checkAudioRoute() {
        let route = audioSession.currentRoute
        audioRoute = route.outputs.first?.portName ?? "Unknown"
        
        // Check for headphones
        isHeadphonesConnected = route.outputs.contains { output in
            output.portType == .headphones ||
            output.portType == .bluetoothA2DP ||
            output.portType == .bluetoothHFP ||
            output.portType == .bluetoothLE
        }
        
        print("🎧 Audio Route: \(audioRoute), Headphones: \(isHeadphonesConnected)")
    }
    
    // MARK: - Notification Handlers
    private func handleInterruptionNotification(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            print("🔴 Audio Interruption BEGAN (e.g., phone call)")
            NotificationCenter.default.post(name: .audioInterruptionBegan, object: nil)
            
        case .ended:
            print("🟢 Audio Interruption ENDED")
            
            // Check if we should resume
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    print("➡️ Should resume playback")
                    NotificationCenter.default.post(name: .audioInterruptionEndedShouldResume, object: nil)
                } else {
                    print("⏸️ Should NOT resume playback")
                    NotificationCenter.default.post(name: .audioInterruptionEnded, object: nil)
                }
            }
            
        @unknown default:
            print("⚠️ Unknown interruption type")
        }
    }
    
    private func handleRouteChangeNotification(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        checkAudioRoute()
        
        switch reason {
        case .newDeviceAvailable:
            print("🎧 New audio device connected: \(audioRoute)")
            
        case .oldDeviceUnavailable:
            print("🔌 Audio device disconnected")
            // Pause playback when headphones are removed
            if let previousRoute = info[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
                let wasHeadphones = previousRoute.outputs.contains { output in
                    output.portType == .headphones || output.portType == .bluetoothA2DP
                }
                
                if wasHeadphones {
                    print("⏸️ Headphones removed - pausing playback")
                    NotificationCenter.default.post(name: .audioDeviceDisconnected, object: nil)
                }
            }
            
        case .categoryChange:
            print("📂 Audio category changed")
            
        case .override:
            print("🔄 Audio route overridden")
            
        case .wakeFromSleep:
            print("😴 Audio woke from sleep")
            
        case .noSuitableRouteForCategory:
            print("❌ No suitable route for category")
            
        case .routeConfigurationChange:
            print("⚙️ Route configuration changed")
            
        @unknown default:
            print("⚠️ Unknown route change reason: \(reason.rawValue)")
        }
    }
    
    private func handleMediaServicesResetNotification() {
        print("🔄 Media services were reset - reconfiguring audio session")
        setupAudioSession()
        setupRemoteCommandCenter()
    }
    
    private func handleSilenceSecondaryAudioNotification(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionSilenceSecondaryAudioHintTypeKey] as? UInt,
              let type = AVAudioSession.SilenceSecondaryAudioHintType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .begin:
            print("🔇 Other apps requested to lower volume")
        case .end:
            print("🔊 Other apps stopped requesting volume reduction")
        @unknown default:
            print("⚠️ Unknown silence hint type: \(type.rawValue)")
        }
    }
    
    // MARK: - Remote Command Handlers (zu PlayerViewModel weiterleiten)
    private func handleRemotePlay() {
        print("▶️ Remote Play Command")
        playerViewModel?.handleRemotePlay()
    }

    private func handleRemotePause() {
        print("⏸️ Remote Pause Command")
        playerViewModel?.handleRemotePause()
    }

    private func handleRemoteTogglePlayPause() {
        print("⏯️ Remote Toggle Play/Pause Command")
        playerViewModel?.handleRemoteTogglePlayPause()
    }

    private func handleRemoteNextTrack() {
        print("⏭️ Remote Next Track Command")
        playerViewModel?.handleRemoteNextTrack()
    }

    private func handleRemotePreviousTrack() {
        print("⏮️ Remote Previous Track Command")
        playerViewModel?.handleRemotePreviousTrack()
    }

    private func handleRemoteSeek(to time: TimeInterval) {
        print("⏩ Remote Seek Command: \(time)s")
        playerViewModel?.handleRemoteSeek(to: time)
    }

    private func handleRemoteSkipForward(interval: TimeInterval) {
        print("⏭️ Remote Skip Forward: \(interval)s")
        playerViewModel?.handleRemoteSkipForward(interval: interval)
    }

    private func handleRemoteSkipBackward(interval: TimeInterval) {
        print("⏮️ Remote Skip Backward: \(interval)s")
        playerViewModel?.handleRemoteSkipBackward(interval: interval)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    // Audio Interruptions
    static let audioInterruptionBegan = Notification.Name("audioInterruptionBegan")
    static let audioInterruptionEnded = Notification.Name("audioInterruptionEnded")
    static let audioInterruptionEndedShouldResume = Notification.Name("audioInterruptionEndedShouldResume")
    static let audioDeviceDisconnected = Notification.Name("audioDeviceDisconnected")
    }
