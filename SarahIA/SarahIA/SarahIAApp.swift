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

        // HOTFIX démarrage : aucune migration lourde, aucun modèle IA et aucune base
        // de données secondaire ne sont initialisés avant le premier écran.
        // Cela évite qu'un composant optionnel puisse faire tomber le processus au lancement.
        SessionTimeoutManager.shared.prepareForProcessLaunch(
            didResetUserStateForNewBuild: false
        )
        
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
        
        // Le premier écran est rendu avant tout service optionnel.
        // Les permissions audio sont demandées uniquement lorsqu'un mode vocal est lancé.
        UNUserNotificationCenter.current().delegate = self

        DispatchQueue.main.async {
            NotificationService.shared.clearBadge()
        }

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
    
    // MARK: - Cycle de Vie & Session Timeout (Inactivité > 1h)
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        SessionTimeoutManager.shared.recordAppBackgroundTime()
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        SessionTimeoutManager.shared.checkAndResetSessionIfNeeded()
        WidgetDataBridge.shared.refreshHealthSnapshot()
    }
    
    // MARK: - Finalisation du Téléchargement Background (URLSession GGUF)
    
    private static var backgroundSessionCompletionHandlers: [String: () -> Void] = [:]

    public static func completeBackgroundSession(identifier: String?) {
        guard let identifier else { return }

        DispatchQueue.main.async {
            let handler = backgroundSessionCompletionHandlers.removeValue(forKey: identifier)
            handler?()
        }
    }
    
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        AppDelegate.backgroundSessionCompletionHandlers[identifier] = completionHandler
        print("⚡ [AppDelegate] URLSession Background réveillée pour l'identifiant : \(identifier)")
    }
}
