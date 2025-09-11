//
//  CarPlaySceneDelegate.swift
//  NavidromeClient
//
//  Created by Boris Eder on 11.09.25.
//


import Foundation
import CarPlay
import MediaPlayer

// MARK: - CarPlay Support (Optional - für zukünftige Erweiterung)

@available(iOS 14.0, *)
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    
    var interfaceController: CPInterfaceController?
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        
        // Root Template erstellen
        let rootTemplate = createRootTemplate()
        interfaceController.setRootTemplate(rootTemplate, animated: true, completion: nil)
        
        print("🚗 CarPlay connected")
    }
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didDisconnect interfaceController: CPInterfaceController) {
        self.interfaceController = nil
        print("🚗 CarPlay disconnected")
    }
    
    private func createRootTemplate() -> CPTabBarTemplate {
        // Beispiel für CarPlay Interface
        let musicTab = CPListTemplate(title: "Music", sections: [
            CPListSection(items: [
                CPListItem(text: "Recent Albums", detailText: "Recently played music"),
                CPListItem(text: "Artists", detailText: "Browse by artist"),
                CPListItem(text: "Now Playing", detailText: "Current track")
            ])
        ])
        
        musicTab.tabImage = UIImage(systemName: "music.note")
        
        return CPTabBarTemplate(templates: [musicTab])
    }
}

// MARK: - CarPlay Integration für PlayerViewModel

extension PlayerViewModel {
    
    @available(iOS 14.0, *)
    func setupCarPlayIntegration() {
        // Zusätzliche CarPlay-spezifische Now Playing Info
        guard let song = currentSong else { return }
        
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artist ?? "Unknown Artist",
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            // CarPlay-spezifische Properties
            MPNowPlayingInfoPropertyIsLiveStream: false,
            MPNowPlayingInfoPropertyAvailableLanguageOptions: [],
            MPNowPlayingInfoPropertyCurrentLanguageOptions: []
        ]
        
        if let album = song.album {
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = album
        }
        
        if let artwork = coverArt {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in
                return artwork
            }
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}