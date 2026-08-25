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
        
        if #available(iOS 14.0, *) {
            // Mode Moderne SwiftUI Pixel-Perfect
            let contentView = ContentView()
            let hostingController = UIHostingController(rootView: contentView)
            hostingController.view.backgroundColor = .black
            window.rootViewController = hostingController
        } else {
            // Mode Secours UIKit 100% Natif pour iOS 12 et 13 (iPhone 5S, 6, 6 Plus)
            let legacyVC = LegacyChatViewController()
            window.rootViewController = legacyVC
        }
        
        window.makeKeyAndVisible()
        
        // Notifications & Surveillance Batterie
        UNUserNotificationCenter.current().delegate = self
        NotificationService.shared.clearBadge()
        BatteryMonitorManager.shared.startMonitoring()
        
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
    
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        guard let host = url.host?.lowercased() else { return true }
        
        NotificationCenter.default.post(name: NSNotification.Name("SarahOpenDeepLink"), object: host)
        
        if host == "torch" {
            _ = DeviceController.shared.toggleTorch(enable: nil)
        }
        
        return true
    }
}
