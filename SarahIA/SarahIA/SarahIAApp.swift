import UIKit
import SwiftUI
import UserNotifications
import AVFoundation

/// Point d'entrée de Sarah IA.
///
/// Les SDK iOS récents exigent désormais le cycle de vie UIScene. L'ancienne
/// version créait directement UIWindow depuis AppDelegate, ce qui provoquait
/// un SIGTRAP avant même l'affichage du premier écran avec le SDK iOS 27.
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        SessionTimeoutManager.shared.prepareForProcessLaunch(
            didResetUserStateForNewBuild: false
        )

        UNUserNotificationCenter.current().delegate = self

        DispatchQueue.main.async {
            NotificationService.shared.clearBadge()
        }

        // iOS 13+ : UIKit crée désormais l'interface via SceneDelegate.
        // iOS 12 : conserver le chemin historique pour compatibilité source.
        if #available(iOS 13.0, *) {
            return true
        }

        let window = UIWindow(frame: UIScreen.main.bounds)
        self.window = window
        let legacyVC = LegacyChatViewController()
        window.rootViewController = legacyVC
        window.makeKeyAndVisible()

        return true
    }

    @available(iOS 13.0, *)
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

    @available(iOS 13.0, *)
    func application(
        _ application: UIApplication,
        didDiscardSceneSessions sceneSessions: Set<UISceneSession>
    ) {
        // Aucune ressource de scène supplémentaire à libérer.
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
        handleDeepLink(url)
        return true
    }

    // MARK: - Compatibilité cycle de vie pré-UIScene

    func applicationDidEnterBackground(_ application: UIApplication) {
        if #available(iOS 13.0, *), !application.connectedScenes.isEmpty {
            return
        }
        SessionTimeoutManager.shared.recordAppBackgroundTime()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        if #available(iOS 13.0, *), !application.connectedScenes.isEmpty {
            return
        }
        SessionTimeoutManager.shared.checkAndResetSessionIfNeeded()
    }

    // MARK: - Finalisation du téléchargement background

    public static var backgroundSessionCompletionHandler: (() -> Void)?

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        AppDelegate.backgroundSessionCompletionHandler = completionHandler
        print("⚡ [AppDelegate] URLSession Background réveillée pour l'identifiant : \(identifier)")
    }

    fileprivate func handleDeepLink(_ url: URL) {
        guard let host = url.host?.lowercased() else { return }

        NotificationCenter.default.post(
            name: NSNotification.Name("SarahOpenDeepLink"),
            object: host
        )

        if host == "torch" {
            _ = DeviceController.shared.toggleTorch(enable: nil)
        }
    }
}

/// Cycle de vie de la fenêtre requis par les SDK iOS modernes.
@available(iOS 13.0, *)
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }

        let window = UIWindow(windowScene: windowScene)
        self.window = window

        if #available(iOS 15.0, *) {
            let contentView = ContentView()
            let hostingController = UIHostingController(rootView: contentView)
            hostingController.view.backgroundColor = .black
            window.rootViewController = hostingController
        } else {
            window.rootViewController = LegacyChatViewController()
        }

        window.backgroundColor = .black
        window.makeKeyAndVisible()

        if let url = connectionOptions.urlContexts.first?.url {
            handleDeepLink(url)
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        SessionTimeoutManager.shared.checkAndResetSessionIfNeeded()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        SessionTimeoutManager.shared.recordAppBackgroundTime()
    }

    func scene(
        _ scene: UIScene,
        openURLContexts URLContexts: Set<UIOpenURLContext>
    ) {
        guard let url = URLContexts.first?.url else { return }
        handleDeepLink(url)
    }

    private func handleDeepLink(_ url: URL) {
        guard let host = url.host?.lowercased() else { return }

        NotificationCenter.default.post(
            name: NSNotification.Name("SarahOpenDeepLink"),
            object: host
        )

        if host == "torch" {
            _ = DeviceController.shared.toggleTorch(enable: nil)
        }
    }
}
