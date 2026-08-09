import SwiftUI
import UserNotifications

/// Point d'entrée de l'application Sarah IA.
@main
struct SarahIAApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Demander la permission de notification au premier lancement
                    NotificationService.shared.requestPermission()
                    // Réinitialiser le badge
                    NotificationService.shared.clearBadge()
                }
        }
    }
}

// MARK: - AppDelegate pour gérer les notifications au premier plan

/// AppDelegate nécessaire pour afficher les notifications même quand l'app est active.
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // S'enregistrer comme délégué pour les notifications
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    
    /// Permet d'afficher les notifications même quand l'app est au premier plan.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Afficher la notification en bannière + son même si l'app est active
        completionHandler([.banner, .sound, .badge])
    }
    
    /// Gère le tap sur une notification.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Réinitialiser le badge quand l'utilisateur ouvre via la notification
        NotificationService.shared.clearBadge()
        completionHandler()
    }
}
