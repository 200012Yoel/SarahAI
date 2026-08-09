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
                    // Initialiser la session audio full-duplex
                    AudioEngineManager.shared.setupAudioSession()
                    // Demander la permission de notification
                    NotificationService.shared.requestPermission()
                    // Réinitialiser le badge
                    NotificationService.shared.clearBadge()
                }
        }
    }
}

// MARK: - AppDelegate pour gérer les notifications et l'audio en arrière-plan

/// AppDelegate nécessaire pour afficher les notifications même quand l'app est active.
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        AudioEngineManager.shared.setupAudioSession()
        return true
    }
    
    /// Permet d'afficher les notifications même quand l'app est au premier plan.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
    
    /// Gère le tap sur une notification.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        NotificationService.shared.clearBadge()
        completionHandler()
    }
}

