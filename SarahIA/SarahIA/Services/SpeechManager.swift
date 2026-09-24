import Foundation
import AVFoundation
import UIKit
#if canImport(Combine)
import Combine
#endif

/// Gestionnaire historique de synthèse vocale de Sarah.
/// Les anciennes données d'animation faciale/3D ont été supprimées : ce service
/// se concentre uniquement sur une lecture vocale Apple fiable.
public final class SpeechManager: NSObject, AVSpeechSynthesizerDelegate {

    public static let shared = SpeechManager()

    public private(set) var isSpeaking: Bool = false {
        didSet {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("SarahSpeechStateDidChange"), object: nil)
            }
        }
    }

    public private(set) var currentSpokenText: String? = nil {
        didSet {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("SarahSpeechStateDidChange"), object: nil)
            }
        }
    }

    public var onSpeechStarted: (() -> Void)?
    public var onSpeechFinished: (() -> Void)?
    public var onSpeechInterrupted: (() -> Void)?

    private let synthesizer = AVSpeechSynthesizer()
    private var speechBgTask: UIBackgroundTaskIdentifier = .invalid

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Synthèse vocale

    public func speak(
        text: String,
        pitch: Float = 1.0,
        rate: Float = AVSpeechUtteranceDefaultSpeechRate
    ) {
        stopSpeaking(notifyInterruption: false)
        AppleSpeechRecognizer.shared.stopListening()

        let cleaned = MultiAgentVoiceManager.shared.cleanTextForSpeech(text)
        guard !cleaned.isEmpty else { return }

        AudioSessionManager.shared.configurePlaybackSession()

        let utterance = MultiAgentVoiceManager.shared.makeUtterance(text: cleaned)
        utterance.voice = MultiAgentVoiceManager.shared.getVoice(for: .sarah)
        utterance.pitchMultiplier = pitch
        utterance.rate = rate
        utterance.volume = 1.0

        currentSpokenText = cleaned
        isSpeaking = true
        beginBackgroundTask()

        DispatchQueue.main.async {
            self.synthesizer.speak(utterance)
        }
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
        endBackgroundTask()

        if notifyInterruption && wasSpeaking {
            onSpeechInterrupted?()
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

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
            self.endBackgroundTask()
            self.onSpeechFinished?()
        }
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.currentSpokenText = nil
            self.endBackgroundTask()
            self.onSpeechInterrupted?()
        }
    }

    // MARK: - Background Task

    private func beginBackgroundTask() {
        if speechBgTask != .invalid {
            UIApplication.shared.endBackgroundTask(speechBgTask)
        }
        speechBgTask = UIApplication.shared.beginBackgroundTask(withName: "Sarah_Speech") { [weak self] in
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        if speechBgTask != .invalid {
            UIApplication.shared.endBackgroundTask(speechBgTask)
            speechBgTask = .invalid
        }
    }
}

#if canImport(Combine)
@available(iOS 13.0, *)
public final class ObservableSpeechManager: ObservableObject {
    public static let shared = ObservableSpeechManager()

    @Published public var isSpeaking: Bool = SpeechManager.shared.isSpeaking
    @Published public var currentSpokenText: String? = SpeechManager.shared.currentSpokenText

    private var cancellables = Set<AnyCancellable>()

    private init() {
        NotificationCenter.default.publisher(for: NSNotification.Name("SarahSpeechStateDidChange"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isSpeaking = SpeechManager.shared.isSpeaking
                self?.currentSpokenText = SpeechManager.shared.currentSpokenText
            }
            .store(in: &cancellables)
    }
}
#endif
