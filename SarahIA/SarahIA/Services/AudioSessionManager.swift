import Foundation
import AVFoundation
import UIKit

/// Gestion centralisée de la session audio de Sarah.
///
/// Le mode vocal continu ouvre UNE seule session `.playAndRecord / .voiceChat`
/// au début, puis la conserve pendant écouter -> répondre -> écouter.
/// Les changements de volume système ne doivent jamais être interprétés comme
/// une interruption de conversation et aucun autre composant ne doit changer
/// la catégorie ou la route pendant ce cycle.
public final class AudioSessionManager {

    public static let shared = AudioSessionManager()

    public var onInterruptionBegan: (() -> Void)?
    public var onInterruptionEnded: (() -> Void)?

    private let stateLock = NSLock()
    private var continuousVoiceSessionActive = false

    public var isContinuousVoiceSessionActive: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return continuousVoiceSessionActive
    }

    private init() {
        setupObservers()
    }

    // MARK: - Mode vocal continu

    /// Ouvre la session audio une seule fois pour tout le cycle vocal.
    public func beginContinuousVoiceSession() {
        stateLock.lock()
        let wasAlreadyActive = continuousVoiceSessionActive
        continuousVoiceSessionActive = true
        stateLock.unlock()

        if wasAlreadyActive {
            ensureContinuousSessionActive()
            ensureAudibleOutputRouteIfNeeded()
            return
        }

        configureVoiceConversationSession()
    }

    /// Ferme réellement la session uniquement lorsque l'utilisateur quitte le vocal.
    public func endContinuousVoiceSession() {
        stateLock.lock()
        let wasActive = continuousVoiceSessionActive
        continuousVoiceSessionActive = false
        stateLock.unlock()

        guard wasActive else { return }
        forceDeactivateSession()
    }

    /// Après une vraie interruption iOS ou un changement de route, on réactive
    /// seulement la session existante. On ne refait jamais `setCategory` pendant
    /// une conversation, ce qui évite les bugs lors des changements de volume.
    public func restoreContinuousVoiceSessionIfNeeded() {
        guard isContinuousVoiceSessionActive else { return }
        ensureContinuousSessionActive()
        ensureAudibleOutputRouteIfNeeded()
    }

    /// Réactive la session sans changer catégorie, mode ou route. Utilisé pour
    /// les passages micro <-> voix et les changements de volume système.
    private func ensureContinuousSessionActive() {
        guard isContinuousVoiceSessionActive else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("⚠️ [AudioSessionManager] Réactivation session vocale: \(error.localizedDescription)")
        }
    }

    private func configureVoiceConversationSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
            )
            try session.setPreferredIOBufferDuration(0.02)
            try session.setActive(true)
            ensureAudibleOutputRouteIfNeeded()
            print("🎙️🔊 [AudioSessionManager] Session vocale continue active.")
        } catch {
            print("⚠️ [AudioSessionManager] Configuration vocale continue: \(error.localizedDescription)")
        }
    }

    /// `AVSpeechSynthesizer` peut démarrer alors que la route courante reste sur
    /// l'écouteur interne. On ne force le haut-parleur que dans ce cas précis,
    /// afin de préserver les casques Bluetooth/AirPlay et le contrôle de volume iOS.
    private func ensureAudibleOutputRouteIfNeeded() {
        let session = AVAudioSession.sharedInstance()
        let outputs = session.currentRoute.outputs
        let isReceiverOnly = outputs.count == 1 && outputs.first?.portType == .builtInReceiver
        guard isReceiverOnly else { return }

        do {
            try session.overrideOutputAudioPort(.speaker)
            print("🔊 [AudioSessionManager] Sortie vocale replacée sur le haut-parleur.")
        } catch {
            print("⚠️ [AudioSessionManager] Route haut-parleur: \(error.localizedDescription)")
        }
    }

    // MARK: - Sessions ponctuelles

    /// En conversation continue, on garde exactement la même session et on
    /// vérifie seulement que la sortie est audible. Aucun changement de catégorie.
    public func configurePlaybackSession() {
        if isContinuousVoiceSessionActive {
            ensureContinuousSessionActive()
            ensureAudibleOutputRouteIfNeeded()
            return
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.allowBluetoothA2DP, .allowAirPlay]
            )
            try session.setActive(true)
            print("🔊 [AudioSessionManager] Lecture ponctuelle active.")
        } catch {
            print("⚠️ [AudioSessionManager] Erreur configuration playback: \(error.localizedDescription)")
        }
    }

    /// En conversation continue, le micro garde exactement la même session.
    public func configureRecordingSession() {
        if isContinuousVoiceSessionActive {
            ensureContinuousSessionActive()
            return
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
            try session.setPreferredIOBufferDuration(0.02)
            try session.setActive(true)
            print("🎙️ [AudioSessionManager] Dictée ponctuelle active.")
        } catch {
            print("⚠️ [AudioSessionManager] Erreur configuration micro: \(error.localizedDescription)")
        }
    }

    /// En mode vocal continu, cet appel devient volontairement un no-op.
    public func deactivateSession() {
        guard !isContinuousVoiceSessionActive else { return }
        forceDeactivateSession()
    }

    private func forceDeactivateSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("🔇 [AudioSessionManager] Session audio rendue à iOS.")
        } catch {
            print("⚠️ [AudioSessionManager] Erreur désactivation: \(error.localizedDescription)")
        }
    }

    // MARK: - Interruptions et changements de route système

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )

        // Important : `silenceSecondaryAudioHintNotification` n'est PAS une vraie
        // interruption. Les boutons de volume ne doivent jamais couper la voix.
    }

    @objc private func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            DispatchQueue.main.async {
                self.onInterruptionBegan?()
            }

        case .ended:
            let shouldResume: Bool
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                shouldResume = AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume)
            } else {
                shouldResume = false
            }

            guard shouldResume else { return }
            restoreContinuousVoiceSessionIfNeeded()
            DispatchQueue.main.async {
                self.onInterruptionEnded?()
            }

        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard isContinuousVoiceSessionActive else { return }

        // Ne jamais refaire setCategory lors d'un changement de route. On garde
        // la session existante et on ne corrige que le cas écouteur interne.
        ensureContinuousSessionActive()
        ensureAudibleOutputRouteIfNeeded()
    }

    @objc private func handleAppWillResignActive() {
        // Ne pas toucher à la session seulement parce que l'app perd le focus.
    }
}
