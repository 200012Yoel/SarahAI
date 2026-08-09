import Foundation
import UserNotifications

/// Gère les notifications locales pour informer l'utilisateur
/// quand une réponse IA est prête (même si l'app est en arrière-plan).
final class NotificationService: NSObject {
    
    static let shared = NotificationService()
    
    private override init() {
        super.init()
    }
    
    /// Demande l'autorisation d'envoyer des notifications à l'utilisateur.
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if let error = error {
                print("❌ Erreur de permission de notification: \(error.localizedDescription)")
                return
            }
            print(granted ? "✅ Notifications autorisées" : "⚠️ Notifications refusées par l'utilisateur")
        }
    }
    
    /// Envoie une notification locale avec la réponse de Sarah IA.
    /// - Parameter message: Le contenu de la réponse à afficher.
    func sendResponseNotification(message: String) {
        let content = UNMutableNotificationContent()
        content.title = "Sarah IA 🤖"
        content.subtitle = "Nouvelle réponse"
        content.body = message
        content.sound = .default
        content.badge = 1
        
        // Déclencher immédiatement (délai de 0.1s minimum requis)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Erreur d'envoi de notification: \(error.localizedDescription)")
            } else {
                print("✅ Notification envoyée: \(message.prefix(50))...")
            }
        }
    }
    
    /// Réinitialise le badge de l'application.
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
    }
}
