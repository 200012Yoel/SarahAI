import Foundation
import AVFoundation
import UIKit

/// Gestion centralisée de la session audio de Sarah.
///
/// Le mode vocal continu ouvre UNE seule session `.playAndRecord / .voiceChat`
/// au début, puis la conserve pendant écouter -> répondre -> écouter.
/// Les changements de volume système ne doivent jamais être interprétés comme
/// une interruption de conversation et ne doivent pas reconfigurer la route.
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

    /// Ouvre la session audio une seule fois pour tout le cycle vocal.
    public func beginContinuousVoiceSession() {
        stateLock.lock()
        let wasAlreadyActive = continuousVoiceSessionActive
        continuousVoiceSessionActive = true
        stateLock.unlock()

        if wasAlreadyActive {
            ensureContinuousSessionActive()
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

    /// Après une vraie interruption iOS, réapplique la configuration de conversation.
    public func restoreContinuousVoiceSessionIfNeeded() {
        guard isContinuousVoiceSessionActive else { return }
        configureVoiceConversationSession()
    }

    /// Réactive la session sans changer catégorie, mode ou route. Cette méthode est
    /// utilisée au passage micro <-> voix afin d'éviter les sauts de son.
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
                options: [.defaultToSpeaker, .allowBluetooth]
            )
            try session.setPreferredIOBufferDuration(0.02)
            try session.setActive(true)
            print("🎙️🔊 [AudioSessionManager] Session vocale continue active.")
        } catch {
            print("⚠️ [AudioSessionManager] Configuration vocale continue: \(error.localizedDescription)")
        }
    }

    // MARK: - Sessions ponctuelles

    /// En conversation continue, on réactive seulement la session existante sans
    /// modifier sa catégorie ni sa route. Hors conversation, on configure une lecture.
    public func configurePlaybackSession() {
        if isContinuousVoiceSessionActive {
            ensureContinuousSessionActive()
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

        // Important : `silenceSecondaryAudioHintNotification` n'est PAS une vraie
        // interruption. L'ancien code la traitait pourtant comme telle et pouvait
        // couper Sarah à tort lors de changements audio système.
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
        // Ne pas toucher à la session seulement parce que l'app perd le focus.
    }
}
