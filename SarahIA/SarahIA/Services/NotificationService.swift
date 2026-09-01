import Foundation                                        
import UserNotifications
import UIKit

// Manage local notifications
// when AI response is ready
final class NotificationService: NSObject {
        static let shared = NotificationService()

        private override init() {
                    super.init()
        }

        // Request permission
        func requestPermission() {
                    UNUserNotificationCenter.current().requestAuthorization(
                                    options: [.alert, .sound, .badge]
                    ) { granted, error in
                                   if let error = error {
                                                       print("Notification permission error: \(error.localizedDescription)")
                                                       return
                                   }
                                   print(granted ? "Notifications allowed" : "Notifications denied")
                      }
        }

        // Send response notification
        func sendResponseNotification(message: String) {
                    let content = UNMutableNotificationContent()
                    content.title = "Sarah IA"
                    content.subtitle = "New response"
                    content.body = message
                    content.sound = .default
                    content.badge = 1

                    // Trigger immediately
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)

                    let request = UNNotificationRequest(
                                    identifier: UUID().uuidString,
                                    content: content,
                                    trigger: trigger
                    )

                    UNUserNotificationCenter.current().add(request) { error in
                        if let error = error {
                            print("Notification send error: \(error.localizedDescription)")
                        } else {
                            print("Notification sent: \(message.prefix(50))...")
                        }
                    }
        }
        
        // Show in-app / local alert notification
        func showInAppNotification(title: String, message: String) {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = message
            content.sound = .default
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        }

        // Reset app badge
        func clearBadge() {
                    if #available(iOS 16.0, *) {
                                    UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
                    } else {
                                    UIApplication.shared.applicationIconBadgeNumber = 0
                    }
        }
}
