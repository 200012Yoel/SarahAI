import Foundation
import WatchConnectivity

/// Pont léger : la montre fournit le micro ; l'iPhone conserve toute la
/// reconnaissance hébraïque, la traduction et la synthèse française existantes.
final class WatchAudioBridge: NSObject, WCSessionDelegate {
    static let shared = WatchAudioBridge()

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
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

    // Les délégués WatchConnectivity arrivent hors du thread principal.
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            switch message["type"] as? String {
            case "start":
                let live = LiveTranslationSession.shared
                live.setLanguages(LiveLanguagePair(sourceLanguage: "he",
                                                  targetLanguage: "fr",
                                                  isVoiceEnabled: true))
                LiveSpeechTranslationPipeline.shared.onMicrophoneSuspensionChanged = { [weak self] state in
                    self?.sendSpeaking(state)
                }
                live.startFromWatch()
                NotificationCenter.default.post(name: .sarahPresentLiveTranslation, object: nil)
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
}
