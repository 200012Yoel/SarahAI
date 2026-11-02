import Foundation
import WatchConnectivity
import UIKit
import UserNotifications

/// La montre transmet le son, tandis que l'iPhone utilise la paire de langues
/// réellement sélectionnée dans la traduction en direct.
final class WatchAudioBridge: NSObject, WCSessionDelegate {
    static let shared = WatchAudioBridge()

    private static let pendingCallKey = "sarah.watch.translate.pendingOpen"
    private var recentCallIDs = [String]()
    private static let notificationIdentifierPrefix = "sarah.watch.translate."
    private static let incomingCallNotification = Notification.Name("SarahWatchIncomingCall")
    private var acceptedCallWaitingForWatch = false

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Synchronise les langues de la vue iPhone avec la Watch, même si
    /// son application n'est pas actuellement ouverte (applicationContext).
    func sendLanguagePair(_ pair: LiveLanguagePair) {
        guard WCSession.isSupported() else { return }
        let values: [String: Any] = [
            "type": "languages",
            "source": pair.sourceLanguage,
            "target": pair.targetLanguage
        ]
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        do {
            try session.updateApplicationContext(values)
        } catch {
            print("⚠️ [Sarah Watch] Synchronisation différée : \(error.localizedDescription)")
        }
        if session.isReachable {
            session.sendMessage(values, replyHandler: nil, errorHandler: nil)
        }
    }

    /// Après un appui sur la notification, iOS affiche Sarah IA. La montre
    /// commence le micro seulement lorsque l'interface de traduction est ouverte.
    func sendPhoneReady() {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(
            ["type": "phoneReady"],
            replyHandler: nil,
            errorHandler: nil
        )
    }

    /// Affiche la vraie interface plein écran de Sarah, uniquement lorsque
    /// l'app est au premier plan après le déverrouillage système d'iOS.
    /// CallKit ne peut pas être utilisé pour simuler un appel VoIP inexistant.
    func presentPendingCallIfNeeded() {
        guard UIApplication.shared.applicationState == .active,
              UserDefaults.standard.bool(forKey: Self.pendingCallKey) else { return }
        NotificationCenter.default.post(name: Self.incomingCallNotification, object: nil)
    }

    /// L'utilisateur a décroché dans Sarah IA (jamais automatiquement).
    func acceptPendingCall() {
        guard UIApplication.shared.applicationState == .active,
              UserDefaults.standard.bool(forKey: Self.pendingCallKey) else { return }
        UserDefaults.standard.removeObject(forKey: Self.pendingCallKey)
        acceptedCallWaitingForWatch = true
        LiveTranslationSession.shared.prepareForWatchCall()
        NotificationCenter.default.post(name: .sarahPresentLiveTranslation, object: nil)
    }

    func declinePendingCall() {
        UserDefaults.standard.removeObject(forKey: Self.pendingCallKey)
        acceptedCallWaitingForWatch = false
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: recentCallIDs.map { Self.notificationIdentifierPrefix + $0 }
        )
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["type": "phoneDeclined"], replyHandler: nil, errorHandler: nil)
    }

    /// Message watchOS depuis une app active : wake opportuniste d'iOS possible.
    /// Cela NE déverrouille pas l'iPhone et NE force pas l'UI au premier plan.
    private func requestTranslateFromWatch(
        _ requestId: String,
        reply: (([String: Any]) -> Void)? = nil
    ) {
        guard !requestId.isEmpty else {
            reply?(["accepted": false, "reason": "invalidRequest"])
            return
        }
        if recentCallIDs.contains(requestId) {
            reply?(["accepted": true, "deduplicated": true])
            return
        }
        recentCallIDs.append(requestId)
        if recentCallIDs.count > 32 { recentCallIDs.removeFirst() }

        UserDefaults.standard.set(true, forKey: Self.pendingCallKey)
        if UIApplication.shared.applicationState == .active {
            reply?(["accepted": true, "method": "foreground"])
            // Sarah IA affiche Décrocher / Refuser. Elle ne lance pas le micro
            // avant que l'utilisateur choisisse explicitement Décrocher.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.presentPendingCallIfNeeded()
            }
            return
        }

        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            let enabled: Bool
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral: enabled = true
            default: enabled = false
            }
            guard enabled else {
                DispatchQueue.main.async {
                    UserDefaults.standard.removeObject(forKey: Self.pendingCallKey)
                    self.recentCallIDs.removeAll(where: { $0 == requestId })
                    reply?(["accepted": false, "reason": "notificationsDisabled"])
                }
                return
            }
            let content = UNMutableNotificationContent()
            content.title = "Sarah IA Watch"
            content.body = "Ouvrir Translate Live sur cet iPhone ?"
            content.sound = .default
            content.userInfo = ["sarahWatchTranslate": true]
            let request = UNNotificationRequest(
                identifier: Self.notificationIdentifierPrefix + requestId,
                content: content,
                trigger: nil
            )
            center.add(request) { error in
                DispatchQueue.main.async {
                    if error != nil {
                        UserDefaults.standard.removeObject(forKey: Self.pendingCallKey)
                        self.recentCallIDs.removeAll(where: { $0 == requestId })
                    }
                    reply?(error == nil
                        ? ["accepted": true, "method": "notification"]
                        : ["accepted": false, "reason": "notificationError"])
                }
            }
        }
    }

    func sendSpeaking(_ speaking: Bool) {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(
            ["type": "speaking", "active": speaking],
            replyHandler: nil,
            errorHandler: nil
        )
    }

    func sendStop() {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["type": "stop"], replyHandler: nil, errorHandler: nil)
    }

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if activationState == .activated {
            DispatchQueue.main.async {
                self.sendLanguagePair(LiveTranslationSession.shared.languagePair)
            }
        }
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        guard session.activationState == .activated else { return }
        DispatchQueue.main.async {
            self.sendLanguagePair(LiveTranslationSession.shared.languagePair)
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    /// Les callbacks WatchConnectivity peuvent arriver sur un thread secondaire.
    private func beginWatchTranslation() -> [String: Any] {
        let live = LiveTranslationSession.shared
        // Ne pas remplacer la paire choisie sur iPhone : EN/FR, FR/HE, etc.
        LiveSpeechTranslationPipeline.shared.onMicrophoneSuspensionChanged = { [weak self] state in
            self?.sendSpeaking(state)
        }
        live.startFromWatch()
        acceptedCallWaitingForWatch = false
        if UIApplication.shared.applicationState == .active {
            NotificationCenter.default.post(name: .sarahPresentLiveTranslation, object: nil)
        }
        return [
            "started": live.isActive && live.isUsingWatchMicrophone,
            "source": live.languagePair.sourceLanguage,
            "target": live.languagePair.targetLanguage
        ]
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            switch message["type"] as? String {
            case "start":
                _ = self.beginWatchTranslation()
            case "callTranslateLive":
                self.requestTranslateFromWatch(message["requestId"] as? String ?? "")
            case "cancelTranslateCall":
                UserDefaults.standard.removeObject(forKey: Self.pendingCallKey)
                self.acceptedCallWaitingForWatch = false
                UNUserNotificationCenter.current().removePendingNotificationRequests(
                    withIdentifiers: self.recentCallIDs.map { Self.notificationIdentifierPrefix + $0 }
                )
                NotificationCenter.default.post(
                    name: Notification.Name("SarahWatchCallCancelled"), object: nil
                )
            case "stop":
                if LiveTranslationSession.shared.isUsingWatchMicrophone {
                    LiveTranslationSession.shared.stop()
                }
            default:
                break
            }
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard userInfo["type"] as? String == "callTranslateLive" else { return }
        DispatchQueue.main.async {
            self.requestTranslateFromWatch(userInfo["requestId"] as? String ?? "")
        }
    }

    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        guard messageData.count <= 16_000, messageData.count.isMultiple(of: 2) else { return }
        DispatchQueue.main.async {
            LiveTranslationSession.shared.receiveWatchPCM(messageData)
        }
    }

    func session(_ session: WCSession,
                 didReceiveMessageData messageData: Data,
                 replyHandler: @escaping (Data) -> Void) {
        guard messageData.count <= 16_000, messageData.count.isMultiple(of: 2) else {
            replyHandler(Data())
            return
        }
        DispatchQueue.main.async {
            LiveTranslationSession.shared.receiveWatchPCM(messageData)
            replyHandler(Data())
        }
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async {
            switch message["type"] as? String {
            case "probe":
                let pair = LiveTranslationSession.shared.languagePair
                replyHandler([
                    "foreground": UIApplication.shared.applicationState == .active,
                    "ready": self.acceptedCallWaitingForWatch,
                    "source": pair.sourceLanguage,
                    "target": pair.targetLanguage
                ])
            case "callTranslateLive":
                self.requestTranslateFromWatch(message["requestId"] as? String ?? "", reply: replyHandler)
            case "start":
                replyHandler(self.beginWatchTranslation())
            case "stop":
                if LiveTranslationSession.shared.isUsingWatchMicrophone {
                    LiveTranslationSession.shared.stop()
                }
                replyHandler(["stopped": true])
            default:
                replyHandler(["unsupported": true])
            }
        }
    }
}
