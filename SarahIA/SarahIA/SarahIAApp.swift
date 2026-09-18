import UIKit
import SwiftUI
import UserNotifications
import AVFoundation
#if canImport(AppIntents)
import AppIntents
#endif

/// Point d'entrée de l'application Sarah AI compatible iOS 12.0+ à iOS 18.0+.
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    var window: UIWindow?
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        // Chaque IPA publiée porte un numéro de build différent. Une installation de build
        // déclenche une remise à zéro des données de test avant que SwiftUI restaure un chat.
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        let didResetUserState = StorageService.shared.resetUserStateForNewBuildIfNeeded(currentBuild: build)
        SessionTimeoutManager.shared.prepareForProcessLaunch(didResetUserStateForNewBuild: didResetUserState)
        
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
        
        // Notifications & Surveillance Batterie
        UNUserNotificationCenter.current().delegate = self
        NotificationService.shared.clearBadge()
        BatteryMonitorManager.shared.startMonitoring()
        
        // Demande de permission Microphone immédiate au premier lancement
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            print("🎙️ [SarahIAApp] Permission microphone accordée : \(granted)")
        }
        
        // Préparation du moteur IA adaptatif au démarrage
        AIResourceManager.shared.bootstrapEngine()
        
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
    }
    
    // MARK: - Finalisation du Téléchargement Background (URLSession GGUF)
    
    public static var backgroundSessionCompletionHandler: (() -> Void)?
    
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        AppDelegate.backgroundSessionCompletionHandler = completionHandler
        print("⚡ [AppDelegate] URLSession Background réveillée pour l'identifiant : \(identifier)")
    }
}


#if canImport(AppIntents)
@available(iOS 16.0, *)
struct OpenSarahVoiceIntent: AppIntent {
    static var title: LocalizedStringResource = "Sarah Intelligence"
    static var description = IntentDescription("Ouvre Sarah directement en mode vocal.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(true, forKey: "sarahOpenVoiceOnNextActivation")

        await MainActor.run {
            NotificationCenter.default.post(
                name: NSNotification.Name("SarahOpenDeepLink"),
                object: "voice"
            )
        }

        return .result()
    }
}

@available(iOS 16.0, *)
struct SarahAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenSarahVoiceIntent(),
            phrases: [
                "Ouvrir \(.applicationName) Intelligence",
                "Parler à \(.applicationName)",
                "Lancer \(.applicationName)"
            ],
            shortTitle: "Sarah Intelligence",
            systemImageName: "waveform.circle.fill"
        )
    }
}
#endif
