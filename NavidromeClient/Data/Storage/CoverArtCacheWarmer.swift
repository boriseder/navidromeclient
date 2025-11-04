//
//  CoverArtCacheWarmer.swift
//  NavidromeClient
//
//  Created by Boris Eder on 04.11.25.
//


//
//  CoverArtCacheWarmer.swift
//  NavidromeClient
//
//  Warms image cache on app activation from disk cache
//

import SwiftUI

@MainActor
class CoverArtCacheWarmer: ObservableObject {
    private let coverArtManager: CoverArtManager
    private var warmingTask: Task<Void, Never>?
    
    init(coverArtManager: CoverArtManager) {
        self.coverArtManager = coverArtManager
        setupScenePhaseObserver()
    }
    
    private func setupScenePhaseObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.warmCacheFromDisk()
        }
    }
    
    private func warmCacheFromDisk() {
        warmingTask?.cancel()
        
        warmingTask = Task { @MainActor in
            AppLogger.general.info("Warming cache from disk after activation")
            
            // The existing loadCoverArt method already checks disk cache first
            // So we don't need to do anything special here
            // The views' .task(id:) will trigger reload automatically
            
            // Just trigger a UI refresh to re-evaluate all view states
            self.coverArtManager.objectWillChange.send()
            
            AppLogger.general.info("Cache warming completed")
        }
    }
    
    deinit {
        warmingTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }
}