import UIKit
import AVFoundation
import MediaPlayer
import BackgroundTasks

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
                
        // Configure background tasks
        registerBackgroundTasks()
        
        AppLogger.general.info(" App launched with audio session configured")
        return true
    }
    
    // MARK: - Background Tasks
    
    private func registerBackgroundTasks() {
        
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.navidrome.client.refresh", using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }
    
    private func handleAppRefresh(task: BGAppRefreshTask) {
        
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        // Hier könntest du z.B. Playlists aktualisieren
        AppLogger.general.info("Background refresh triggered")
        task.setTaskCompleted(success: true)
    }
    
    // MARK: - App Lifecycle for Audio
    
    func applicationWillResignActive(_ application: UIApplication) {
        
        AppLogger.general.info("App will resign active")
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        
        AppLogger.general.info("App entered background - audio should continue")
        
        // Schedule background refresh
        scheduleAppRefresh()
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {

        AppLogger.general.info("App will enter foreground")
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {

        AppLogger.general.info("App became active")
        
        // Delegate audio session management to AudioSessionManager
        AudioSessionManager.shared.handleAppBecameActive()

    }
    
    func applicationWillTerminate(_ application: UIApplication) {

        AppLogger.general.info("App will terminate")
        
        // Delegate cleanup to AudioSessionManager
        AudioSessionManager.shared.handleAppWillTerminate()
    }
    
    private func scheduleAppRefresh() {
        
        let request = BGAppRefreshTaskRequest(identifier: "at.amtabor.navidromeclient.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        try? BGTaskScheduler.shared.submit(request)
    }
}
