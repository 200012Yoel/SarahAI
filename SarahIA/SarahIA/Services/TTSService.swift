import Foundation
import Combine

/// Legacy API surface forwarding to the same local neural speech engine.
/// The Apple voice synthesizer is not used, even as a fallback.
@available(iOS 15.0, *)
public final class TTSService: NSObject, ObservableObject {
    public static let shared = TTSService()

    @Published public private(set) var isSpeaking = false
    @Published public private(set) var currentSpokenText: String?

    public var onSpeechStarted: (() -> Void)?
    public var onSpeechFinished: (() -> Void)?
    public var onSpeechInterrupted: (() -> Void)?

    private var token: NSObjectProtocol?
    private override init() {
        super.init()
        token = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SarahNeuralSpeechStateChanged"),
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let wasSpeaking = self.isSpeaking
            self.isSpeaking = NeuralVoiceService.shared.isSpeaking
            self.currentSpokenText = self.isSpeaking
                ? AgentVoiceManager.shared.currentSpokenText : nil
            AudioEngineManager.shared.isTTSCurrentlyActive = self.isSpeaking
            if !wasSpeaking && self.isSpeaking { self.onSpeechStarted?() }
            if wasSpeaking && !self.isSpeaking { self.onSpeechFinished?() }
        }
    }

    deinit {
        if let token { NotificationCenter.default.removeObserver(token) }
    }

    public func speak(
        text: String,
        language: String = "fr-FR",
        rate: Float = 1.0,
        pitch: Float = 1.0
    ) {
        _ = pitch
        let requestedLanguage = language.lowercased()
        // Only fr/en currently supported by the selected Supertonic model.
        // Do not silently present Hebrew as a properly synthesized language.
        if requestedLanguage.hasPrefix("he") {
            print("⚠️ [TTSService] Hebrew neural voice not installed.")
            return
        }
        AgentVoiceManager.shared.speak(text: text, as: .sarah, rate: rate)
    }

    public func stopSpeaking() {
        let wasSpeaking = isSpeaking
        AgentVoiceManager.shared.stop()
        isSpeaking = false
        currentSpokenText = nil
        AudioEngineManager.shared.isTTSCurrentlyActive = false
        if wasSpeaking { onSpeechInterrupted?() }
    }
}
