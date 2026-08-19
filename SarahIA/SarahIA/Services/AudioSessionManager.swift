import Foundation
import AVFoundation

/// Gestionnaire de session audio dédié garantissant le contournement absolu du mode silencieux de l'iPhone.
public final class AudioSessionManager {
    
    public static let shared = AudioSessionManager()
    
    private init() {
        configurePlaybackSession()
    }
    
    /// Active la session audio en mode lecture média prioritaire pour contourner le bouton silencieux de l'iPhone.
    /// Utilise la catégorie .playback avec le mode .spokenAudio et l'option .duckOthers.
    public func configurePlaybackSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.duckOthers]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            print("🔊 [AudioSessionManager] Session .playback configurée (Mode silencieux contourné).")
        } catch {
            print("⚠️ [AudioSessionManager] Erreur configuration .playback: \(error.localizedDescription)")
        }
    }
    
    /// Configure la session audio pour l'enregistrement micro (dictée vocale Whisper / VAD).
    public func configureRecordingSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [
                    .defaultToSpeaker,
                    .allowBluetoothHFP,
                    .allowBluetoothA2DP,
                    .allowAirPlay
                ]
            )
            try session.setPreferredIOBufferDuration(0.02)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            print("🎙️ [AudioSessionManager] Session .playAndRecord activée pour enregistrement.")
        } catch {
            print("⚠️ [AudioSessionManager] Erreur configuration .playAndRecord: \(error.localizedDescription)")
        }
    }
    
    /// Désactive temporairement la session si nécessaire
    public func deactivateSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("⚠️ [AudioSessionManager] Erreur désactivation: \(error.localizedDescription)")
        }
    }
}
