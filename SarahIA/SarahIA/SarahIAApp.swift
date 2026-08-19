import SwiftUI
import UserNotifications
import AVFoundation

/// Point d'entrée de l'application Sarah AI.
@main
struct SarahIAApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .onAppear {
                    // Configuration initiale de la session audio
                    AudioSessionManager.shared.configurePlaybackSession()
                    // Réinitialiser le badge de notification
                    NotificationService.shared.clearBadge()
                }
        }
    }
}

// MARK: - AppDelegate pour gérer les notifications et le cycle de vie propre

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        AudioSessionManager.shared.configurePlaybackSession()
        return true
    }
    
    /// Permet d'afficher les notifications quand l'app est active.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
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
        // Arrêter l'écoute pour libérer les ressources et éviter les blocages
        AppleSpeechRecognizer.shared.stopListening()
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        AudioSessionManager.shared.configurePlaybackSession()
    }
}

