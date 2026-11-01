import Foundation
import WatchConnectivity

/// La montre transmet le son, tandis que l'iPhone utilise la paire de langues
/// réellement sélectionnée dans la traduction en direct.
final class WatchAudioBridge: NSObject, WCSessionDelegate {
    static let shared = WatchAudioBridge()

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
        NotificationCenter.default.post(name: .sarahPresentLiveTranslation, object: nil)
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
            case "stop":
                if LiveTranslationSession.shared.isUsingWatchMicrophone {
                    LiveTranslationSession.shared.stop()
                }
            default:
                break
            }
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
