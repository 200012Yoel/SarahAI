import Foundation
import AVFoundation
import UIKit
import Combine

/// Service de synthèse vocale léger utilisé par les anciens écrans de Sarah.
/// Toute l'ancienne logique de visage et de visèmes a été retirée : ce service
/// ne gère plus que la parole Apple et son cycle de vie audio.
@available(iOS 13.0, *)
public final class TTSService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {

    public static let shared = TTSService()

    @Published public private(set) var isSpeaking: Bool = false
    @Published public private(set) var currentSpokenText: String? = nil

    public var onSpeechStarted: (() -> Void)?
    public var onSpeechFinished: (() -> Void)?
    public var onSpeechInterrupted: (() -> Void)?

    private let synthesizer = AVSpeechSynthesizer()
    private var speechBgTask: UIBackgroundTaskIdentifier = .invalid

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    public func speak(
        text: String,
        language: String = "fr-FR",
        rate: Float = AVSpeechUtteranceDefaultSpeechRate,
        pitch: Float = 1.0
    ) {
        stopSpeaking(notifyInterruption: false)

        let cleanedText = MultiAgentVoiceManager.shared.cleanTextForSpeech(text)
        guard !cleanedText.isEmpty else { return }

        AudioSessionManager.shared.configurePlaybackSession()

        let utterance = MultiAgentVoiceManager.shared.makeUtterance(text: cleanedText)
        let normalizedLanguage = language.replacingOccurrences(of: "_", with: "-")
        utterance.voice = normalizedLanguage.lowercased() == "fr-fr"
            ? MultiAgentVoiceManager.shared.getVoice(for: .sarah)
            : (AVSpeechSynthesisVoice(language: normalizedLanguage)
                ?? MultiAgentVoiceManager.shared.getVoice(for: .sarah))
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
        utterance.volume = 1.0

        currentSpokenText = cleanedText
        isSpeaking = true
        AudioEngineManager.shared.isTTSCurrentlyActive = true
        beginSpeechBackgroundTask()
        synthesizer.speak(utterance)
    }

    public func stopSpeaking() {
        stopSpeaking(notifyInterruption: true)
    }

    private func stopSpeaking(notifyInterruption: Bool) {
        let wasSpeaking = synthesizer.isSpeaking || isSpeaking
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        isSpeaking = false
        currentSpokenText = nil
        AudioEngineManager.shared.isTTSCurrentlyActive = false
        endSpeechBackgroundTask()

        if notifyInterruption && wasSpeaking {
            onSpeechInterrupted?()
        }
    }

    private func beginSpeechBackgroundTask() {
        if speechBgTask != .invalid {
            UIApplication.shared.endBackgroundTask(speechBgTask)
        }
        speechBgTask = UIApplication.shared.beginBackgroundTask(withName: "SarahAI_TTS") { [weak self] in
            self?.endSpeechBackgroundTask()
        }
    }

    private func endSpeechBackgroundTask() {
        if speechBgTask != .invalid {
            UIApplication.shared.endBackgroundTask(speechBgTask)
            speechBgTask = .invalid
        }
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = true
            self.onSpeechStarted?()
        }
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.currentSpokenText = nil
            AudioEngineManager.shared.isTTSCurrentlyActive = false
            self.endSpeechBackgroundTask()
            self.onSpeechFinished?()
        }
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.currentSpokenText = nil
            AudioEngineManager.shared.isTTSCurrentlyActive = false
            self.endSpeechBackgroundTask()
            self.onSpeechInterrupted?()
        }
    }
}
