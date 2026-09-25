import Foundation
import AVFoundation
import UIKit

/// Gestion centralisée de la session audio de Sarah.
///
/// Le mode vocal continu garde UNE seule session `.playAndRecord / .voiceChat`
/// du début à la fin. On ne change plus de catégorie entre l'écoute et la
/// synthèse, ce qui évite les bascules de volume, de haut-parleur et de profil
/// Bluetooth à chaque tour de conversation.
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
        setupInterruptionObservers()
    }

    // MARK: - Mode vocal continu

    /// Ouvre une session audio stable pour tout le cycle écouter -> répondre -> écouter.
    public func beginContinuousVoiceSession() {
        stateLock.lock()
        continuousVoiceSessionActive = true
        stateLock.unlock()
        configureVoiceConversationSession()
    }

    /// Ferme réellement la session lorsque l'écran vocal est quitté.
    public func endContinuousVoiceSession() {
        stateLock.lock()
        continuousVoiceSessionActive = false
        stateLock.unlock()
        forceDeactivateSession()
    }

    /// Réactive la même route après une interruption iOS sans changer de profil.
    public func restoreContinuousVoiceSessionIfNeeded() {
        guard isContinuousVoiceSessionActive else { return }
        configureVoiceConversationSession()
    }

    private func configureVoiceConversationSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // Ne pas ajouter allowBluetoothA2DP ici : A2DP est une sortie haute
            // fidélité sans micro et provoque des changements de profil pendant
            // une conversation bidirectionnelle.
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
            try session.setPreferredIOBufferDuration(0.02)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            print("🎙️🔊 [AudioSessionManager] Session vocale continue stable active.")
        } catch {
            print("⚠️ [AudioSessionManager] Configuration vocale continue: \(error.localizedDescription)")
        }
    }

    // MARK: - Sessions ponctuelles

    /// Lecture ponctuelle hors mode vocal. En mode vocal, conserve la session
    /// conversationnelle existante au lieu de la reconfigurer.
    public func configurePlaybackSession() {
        if isContinuousVoiceSessionActive {
            configureVoiceConversationSession()
            return
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.allowBluetoothA2DP, .allowAirPlay]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            print("🔊 [AudioSessionManager] Lecture ponctuelle active.")
        } catch {
            print("⚠️ [AudioSessionManager] Erreur configuration playback: \(error.localizedDescription)")
        }
    }

    /// Dictée ponctuelle hors mode vocal. En mode vocal, réutilise exactement
    /// la même session bidirectionnelle.
    public func configureRecordingSession() {
        if isContinuousVoiceSessionActive {
            configureVoiceConversationSession()
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
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            print("🎙️ [AudioSessionManager] Dictée ponctuelle active.")
        } catch {
            print("⚠️ [AudioSessionManager] Erreur configuration micro: \(error.localizedDescription)")
        }
    }

    /// Désactive une session ponctuelle. Pendant le mode vocal continu, cet
    /// appel devient volontairement un no-op pour éviter les coupures entre
    /// reconnaissance et synthèse.
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

    // MARK: - Interruptions système

    private func setupInterruptionObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSecondaryAudioHint(_:)),
            name: AVAudioSession.silenceSecondaryAudioHintNotification,
            object: nil
        )
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

    @objc private func handleAppWillResignActive() {
        // Les vraies interruptions sont traitées par AVAudioSession. Ne pas
        // arrêter/reconfigurer la session simplement parce que l'app perd le focus.
    }

    @objc private func handleSecondaryAudioHint(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionSilenceSecondaryAudioHintTypeKey] as? UInt,
              let type = AVAudioSession.SilenceSecondaryAudioHintType(rawValue: typeValue),
              type == .begin else {
            return
        }

        DispatchQueue.main.async {
            self.onInterruptionBegan?()
        }
    }
}
