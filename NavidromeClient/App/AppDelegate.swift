//
//  AppDelegate.swift
//  NavidromeClient
//
//  Created by Boris Eder on 11.09.25.
//


import UIKit
import AVFoundation
import MediaPlayer

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Initialize Audio Session Manager früh
        _ = AudioSessionManager.shared
        
        // Configure background app refresh
        application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        
        print("✅ App launched with audio session configured")
        return true
    }
    
    // MARK: - Background App Refresh
    
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Hier könntest du z.B. Playlists aktualisieren
        print("📱 Background fetch triggered")
        completionHandler(.noData)
    }
    
    // MARK: - App Lifecycle for Audio
    
    func applicationWillResignActive(_ application: UIApplication) {
        // App wird inaktiv (z.B. Control Center öffnet sich)
        print("📱 App will resign active")
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // App geht in Hintergrund - Audio sollte weiterlaufen
        print("📱 App entered background - audio should continue")
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // App kommt zurück in Vordergrund
        print("📱 App will enter foreground")
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // App wird wieder aktiv
        print("📱 App became active")
        
        // Audio Session reaktivieren falls nötig
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ Failed to reactivate audio session: \(error)")
        }
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // App wird beendet
        print("📱 App will terminate")
        
        // Clean up audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("❌ Failed to deactivate audio session: \(error)")
        }
        
        // Clear now playing info
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}