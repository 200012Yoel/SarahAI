import Foundation
import AVFoundation
import UIKit

/// Gestionnaire de session audio dédié garantissant :
/// - Le contournement absolu du mode silencieux de l'iPhone (.playback)
/// - La coupure automatique et instantanée du micro de Sarah dès que Siri, un appel ou une alarme se déclenche
public final class AudioSessionManager {
    
    public static let shared = AudioSessionManager()
    
    public var onInterruptionBegan: (() -> Void)?
    public var onInterruptionEnded: (() -> Void)?
    
    private init() {
        setupInterruptionObservers()
        // NOTE: On ne configure PAS la session au démarrage pour laisser iOS gérer par défaut
        // La session est configurée uniquement au moment de parler ou d'écouter
    }
    
    // MARK: - Configuration des Sessions Audio
    
    /// Active une vraie session de lecture pour la voix de Sarah.
    /// .playback contourne le mode silencieux sans garder le micro ouvert.
    public func configurePlaybackSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.duckOthers]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            print("🔊 [AudioSessionManager] Session spokenAudio active.")
        } catch {
            print("⚠️ [AudioSessionManager] Erreur configuration playback: \(error.localizedDescription)")
        }
    }
    
    /// Configure le micro sans imposer le haut-parleur si un casque est connecté.
    public func configureRecordingSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [
                    .defaultToSpeaker,
                    .allowBluetooth
                ]
            )
            try session.setPreferredIOBufferDuration(0.046)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            print("🎙️ [AudioSessionManager] Session micro voiceChat active.")
        } catch {
            print("⚠️ [AudioSessionManager] Erreur configuration micro: \(error.localizedDescription)")
        }
    }
    
    /// Désactive la session audio seulement si aucun moteur Sarah ne l'utilise.
    public func deactivateSession() {
        guard !AppleSpeechRecognizer.shared.isListening,
              !MultiAgentVoiceManager.shared.isSpeaking else {
            return
        }

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("⚠️ [AudioSessionManager] Erreur désactivation: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Gestion de Siri, Appels Téléphoniques et Interruptions Système
    
    private func setupInterruptionObservers() {
        // 1. Détection des interruptions audio iOS (Siri, Appel, Alarme, etc.)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        
        // 2. Détection de l'apparition de Siri / Perte de focus de l'application
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        // 3. Détection de l'indice audio secondaire (quand Siri prend la parole)
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
            print("⚡ [AudioSessionManager] Interruption système débutée (Siri / Appel / Alarme). Coupure immédiate du micro.")
            DispatchQueue.main.async {
                self.onInterruptionBegan?()
            }
        case .ended:
            print("🔄 [AudioSessionManager] Interruption système terminée.")
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    DispatchQueue.main.async {
                        self.onInterruptionEnded?()
                    }
                }
            }
        @unknown default:
            break
        }
    }
    
    @objc private func handleAppWillResignActive() {
        // Ne pas couper le micro quand on passe en arrière-plan :
        // iOS gère lui-même les interruptions audio via AVAudioSession.interruptionNotification.
        // Déclencher onInterruptionBegan ici causait des crashs aléatoires à la fermeture de l'app.
        print("ℹ️ [AudioSessionManager] App en arrière-plan - gestion audio laissée à iOS.")
    }
    
    @objc private func handleSecondaryAudioHint(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionSilenceSecondaryAudioHintTypeKey] as? UInt,
              let type = AVAudioSession.SilenceSecondaryAudioHintType(rawValue: typeValue) else {
            return
        }
        
        if type == .begin {
            print("⚡ [AudioSessionManager] Audio externe prioritaire détecté (Siri parle) -> Coupure du micro de Sarah.")
            DispatchQueue.main.async {
                self.onInterruptionBegan?()
            }
        }
    }
}
