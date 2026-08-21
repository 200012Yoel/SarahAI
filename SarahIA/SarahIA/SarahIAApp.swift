import UIKit
import SwiftUI
import UserNotifications
import AVFoundation

/// Point d'entrée de l'application Sarah AI compatible iOS 12.0+ à iOS 18.0+.
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    var window: UIWindow?
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        
        let window = UIWindow(frame: UIScreen.main.bounds)
        self.window = window
        
        if #available(iOS 15.0, *) {
            // Mode Moderne SwiftUI Pixel-Perfect
            let contentView = ContentView()
            let hostingController = UIHostingController(rootView: contentView)
            hostingController.view.backgroundColor = .black
            window.rootViewController = hostingController
        } else {
            // Mode Secours UIKit 100% Natif pour iOS 12, 13 et 14 (iPhone 5S, 6, 6 Plus)
            let legacyVC = LegacyChatViewController()
            window.rootViewController = legacyVC
        }
        
        window.makeKeyAndVisible()
        
        // Notifications
        UNUserNotificationCenter.current().delegate = self
        NotificationService.shared.clearBadge()
        
        return true
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        NotificationService.shared.clearBadge()
        completionHandler()
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        if #available(iOS 13.0, *) {
            AppleSpeechRecognizer.shared.stopListening()
        }
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        NotificationService.shared.clearBadge()
    }
}
