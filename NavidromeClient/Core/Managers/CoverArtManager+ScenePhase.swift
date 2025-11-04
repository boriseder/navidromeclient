//
//  CoverArtManager+ScenePhase.swift
//  NavidromeClient
//
//  Detects app backgrounding and triggers cache check on activation
//

import SwiftUI

extension CoverArtManager {
    func setupScenePhaseObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                AppLogger.general.debug("App will resign active")
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleAppActivation()
            }
        }
    }
    
    func handleAppActivation() async {
        AppLogger.general.info("App became active - triggering cache refresh")
        
        // Increment cache generation to force views to reload
        incrementCacheGeneration()
        
        AppLogger.general.info("Cache generation incremented - views will reload")
    }
}
