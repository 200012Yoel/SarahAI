import Foundation
import AVFoundation

/// Call translation uses OpenAI Whisper through whisper.cpp.
/// No Apple Speech recognition or Apple voice synthesis is permitted here.
public final class LiveSpeechTranslationPipeline: NSObject {
    public static let shared = LiveSpeechTranslationPipeline()

    public var onTranscriptItemUpdated: ((CallTranscriptItem) -> Void)?
    /// Kept for source compatibility. No fabricated PCM buffers are emitted.
    public var onSynthesizedAudioReady: ((Data, String) -> Void)?
    public var onAudioEnergyLevel: ((Float) -> Void)?

    private let recognizer = WhisperSpeechRecognizer.shared
    private var previousFinalCallback: ((String) -> Void)?
    private var currentLanguagePair = CallLanguagePair()
    private var isPipelineRunning = false
    private var generation = UUID()
    private var currentLocalSegmentId = UUID().uuidString
    private var lastRecognizedText = ""
    private var silenceDebounceTimer: Timer?

    private override init() { super.init() }

    public func startPipeline(with languagePair: CallLanguagePair) {
        stopPipeline()
        currentLanguagePair = languagePair
        isPipelineRunning = true
        generation = UUID()
        lastRecognizedText = ""
        currentLocalSegmentId = UUID().uuidString
        let token = generation
        previousFinalCallback = recognizer.onFinalTranscription
        recognizer.onFinalTranscription = { [weak self] text in
            guard let self, self.isPipelineRunning, self.generation == token else { return }
            self.handleLocalTranscription(text: text, isFinal: true)
        }
        // One capture engine for the call. No second AVAudioEngine microphone tap.
        recognizer.startListening(autoFinalizeOnSilence: true, preserveActiveSpeech: true)
    }

    public func updateLanguagePair(_ newPair: CallLanguagePair) {
        currentLanguagePair = newPair
    }

    public func stopPipeline() {
        guard isPipelineRunning else { return }
        isPipelineRunning = false
        generation = UUID()
        silenceDebounceTimer?.invalidate()
        silenceDebounceTimer = nil
        recognizer.stopListening()
        recognizer.onFinalTranscription = previousFinalCallback
        previousFinalCallback = nil
        AgentVoiceManager.shared.stop()
    }

    /// Kept as a meter-only compatibility method; Whisper owns actual capture.
    public func processMicrophoneBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isPipelineRunning, buffer.frameLength > 0,
              let samples = buffer.floatChannelData?[0] else { return }
        let count = Int(buffer.frameLength)
        let sum = (0..<count).reduce(Float(0)) { $0 + samples[$1] * samples[$1] }
        let level = min(1, sqrt(sum / Float(count)) * 10)
        DispatchQueue.main.async { [weak self] in self?.onAudioEnergyLevel?(level) }
    }

    private func handleLocalTranscription(text: String, isFinal: Bool) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized != lastRecognizedText else { return }
        lastRecognizedText = normalized
        let token = generation
        let source = currentLanguagePair.localLanguage
        let target = currentLanguagePair.remoteLanguage
        let targetEnum: TranslationEngine.TargetLanguage = {
            switch target {
            case "en": return .english
            case "he": return .hebrew
            default: return .french
            }
        }()
        TranslationEngine.shared.translate(
            text: normalized, sourceLang: source, targetLang: targetEnum
        ) { [weak self] translatedText in
            DispatchQueue.main.async {
                guard let self, self.isPipelineRunning, self.generation == token else { return }
                let item = CallTranscriptItem(
                    id: self.currentLocalSegmentId,
                    isLocalSpeaker: true,
                    originalText: normalized,
                    originalLanguage: source,
                    translatedText: translatedText,
                    targetLanguage: target,
                    isFinal: isFinal
                )
                self.onTranscriptItemUpdated?(item)
                self.silenceDebounceTimer?.invalidate()
                if self.currentLanguagePair.isVoiceTranslationEnabled {
                    self.silenceDebounceTimer = Timer.scheduledTimer(
                        withTimeInterval: 0.45, repeats: false
                    ) { [weak self] _ in
                        guard let self, self.isPipelineRunning,
                              self.generation == token else { return }
                        self.speakTranslatedText(translatedText, language: target)
                    }
                }
                self.currentLocalSegmentId = UUID().uuidString
            }
        }
    }

    private func speakTranslatedText(_ text: String, language: String) {
        guard !text.isEmpty else { return }
        if language == "he" {
            // Hebrew TTS needs its own commercially cleared voice model.
            // Do not silently substitute an inaccurate French speaker.
            print("⚠️ [Sarah] Traduction écrite disponible, voix hébraïque non installée.")
            return
        }
        AgentVoiceManager.shared.speak(text: text, for: .yohan)
    }

    public func handleRemoteIncomingText(_ remoteText: String) {
        let source = currentLanguagePair.remoteLanguage
        let target = currentLanguagePair.localLanguage
        let targetEnum: TranslationEngine.TargetLanguage = {
            switch target {
            case "he": return .hebrew
            case "en": return .english
            default: return .french
            }
        }()
        let token = generation
        TranslationEngine.shared.translate(
            text: remoteText, sourceLang: source, targetLang: targetEnum
        ) { [weak self] translatedText in
            DispatchQueue.main.async {
                guard let self, self.isPipelineRunning, self.generation == token else { return }
                self.onTranscriptItemUpdated?(CallTranscriptItem(
                    id: UUID().uuidString,
                    isLocalSpeaker: false,
                    originalText: remoteText,
                    originalLanguage: source,
                    translatedText: translatedText,
                    targetLanguage: target,
                    isFinal: true
                ))
            }
        }
    }
}
