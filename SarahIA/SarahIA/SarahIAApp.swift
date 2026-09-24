import UIKit
import SwiftUI
import UserNotifications
import AVFoundation

/// Point d'entrée UIKit de Sarah IA.
///
/// Xcode 27 / iOS 27 exige désormais le cycle de vie UIScene pour les applications
/// construites avec le SDK moderne. L'AppDelegate reste responsable des services
/// globaux, tandis que SceneDelegate crée et affiche la fenêtre principale.
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    /// Conservé uniquement pour compatibilité avec certains appels hérités.
    /// La fenêtre active appartient maintenant à SceneDelegate.
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // HOTFIX démarrage : aucune migration lourde, aucun modèle IA, aucun moteur
        // audio et aucune base secondaire ne sont initialisés avant le premier écran.
        SessionTimeoutManager.shared.prepareForProcessLaunch(
            didResetUserStateForNewBuild: false
        )

        UNUserNotificationCenter.current().delegate = self

        DispatchQueue.main.async {
            NotificationService.shared.clearBadge()
        }

        return true
    }

    // MARK: - UIScene lifecycle (obligatoire avec le SDK iOS 27)

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    func application(
        _ application: UIApplication,
        didDiscardSceneSessions sceneSessions: Set<UISceneSession>
    ) {
        // Aucune ressource persistante attachée à une scène.
    }

    // MARK: - Notifications

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

    // MARK: - Deep links

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        Self.handleDeepLink(url)
        return true
    }

    static func handleDeepLink(_ url: URL) {
        guard let host = url.host?.lowercased() else { return }

        NotificationCenter.default.post(
            name: NSNotification.Name("SarahOpenDeepLink"),
            object: host
        )

        if host == "torch" {
            _ = DeviceController.shared.toggleTorch(enable: nil)
        }
    }

    // MARK: - Finalisation du téléchargement Background (URLSession GGUF)

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

/// Gère la fenêtre principale et le cycle de vie visible de Sarah IA.
/// Déclaré dans ce même fichier afin d'éviter tout risque de cible Xcode oubliée.
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        let contentView = ContentView()
        let hostingController = UIHostingController(rootView: contentView)
        hostingController.view.backgroundColor = .black

        window.rootViewController = hostingController
        self.window = window
        window.makeKeyAndVisible()

        // Un deep link peut être à l'origine même de la création de la scène.
        if let url = connectionOptions.urlContexts.first?.url {
            AppDelegate.handleDeepLink(url)
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        SessionTimeoutManager.shared.checkAndResetSessionIfNeeded()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        SessionTimeoutManager.shared.recordAppBackgroundTime()
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        AppDelegate.handleDeepLink(url)
    }
}
