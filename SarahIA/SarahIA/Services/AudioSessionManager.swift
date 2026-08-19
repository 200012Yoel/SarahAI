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
        configurePlaybackSession()
        setupInterruptionObservers()
    }
    
    // MARK: - Configuration des Sessions Audio
    
    /// Active la session audio avec routage forcé vers le haut-parleur principal (Loudspeaker).
    public func configurePlaybackSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
            print("🔊 [AudioSessionManager] Mode .playback activé (Mode silencieux contourné, haut-parleur garanti).")
        } catch {
            print("⚠️ [AudioSessionManager] Erreur configuration playback: \(error.localizedDescription)")
        }
    }
    
    /// Configure la session audio pour l'enregistrement micro natif sans déclencher de mode appel téléphonique.
    public func configureRecordingSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [
                    .defaultToSpeaker,
                    .allowBluetooth,
                    .allowBluetoothA2DP
                ]
            )
            try session.setPreferredIOBufferDuration(0.02)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            try session.overrideOutputAudioPort(.speaker)
            print("🎙️ [AudioSessionManager] Session micro active.")
        } catch {
            print("⚠️ [AudioSessionManager] Erreur configuration micro: \(error.localizedDescription)")
        }
    }
    
    /// Désactive la session audio proprement
    public func deactivateSession() {
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
        print("⚡ [AudioSessionManager] App en arrière-plan / Siri activé -> Coupure du micro.")
        DispatchQueue.main.async {
            self.onInterruptionBegan?()
        }
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
