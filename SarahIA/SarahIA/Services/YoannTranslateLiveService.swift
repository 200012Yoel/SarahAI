import Foundation
import SwiftUI
import AVFoundation
import UIKit

/// A dedicated one-way microphone interpreter.
/// Input: iPhone built-in microphone pointed at an EXTERNAL computer/TV.
/// Output: French (or English) neural speech on the iPhone.
/// Critically, microphone capture is stopped for the ENTIRE translated playback
/// and resumes only after a short tail delay. No internal iOS loopback or
/// other application's audio is accessed.
@available(iOS 16.2, *)
@MainActor
public final class YoannTranslateLiveService: ObservableObject {
    public typealias Language = TranslateLiveLanguages.Language

    public struct Phrase: Identifiable {
        public let id = UUID()
        public let source: String
        public let translation: String
    }

    /// Spoken commands are parsed across the multilingual Whisper catalog.
    public static func commandPair(_ text: String) -> (from: String, to: String)? {
        TranslateLiveLanguages.pairFromCommand(text)
    }

    @Published public private(set) var isActive = false
    @Published public private(set) var isListening = false
    @Published public private(set) var isSpeakingTranslation = false
    @Published public private(set) var status = "Prêt à écouter le haut-parleur de votre ordinateur."
    @Published public private(set) var lastSource = ""
    @Published public private(set) var lastTranslation = ""
    @Published public private(set) var history: [Phrase] = []
    @Published public private(set) var errorMessage: String?

    public private(set) var sourceLanguage = "he"
    public private(set) var targetLanguage = "fr"

    private let whisper = WhisperSpeechRecognizer.shared
    private let neural = NeuralVoiceService.shared
    private var sessionToken = UUID()
    private var previousFinal: ((String) -> Void)?
    private var previousPartial: ((String) -> Void)?
    private var previousVoiceActivity: (() -> Void)?
    private var previousPlaybackFinished: (() -> Void)?
    private var previousPlaybackError: ((String) -> Void)?
    private var nextListenGeneration = UUID()
    private var translating = false
    private var localEnglishTranslation = false
    private var previousWhisperTranslation = false
    private var previousWhisperLanguage: String?
    private var customTranslationServerURL = ""

    public init() {}

    public func start(from source: String, to target: String, serverURL: String = "") {
        stop()
        guard source != target else {
            errorMessage = "Choisissez deux langues différentes."
            return
        }
        guard TranslateLiveLanguages.isRecognized(source),
              TranslateLiveLanguages.isSelectableTarget(target) else {
            errorMessage = "Cette combinaison de langues n'est pas disponible."
            return
        }

        sourceLanguage = source
        targetLanguage = target
        customTranslationServerURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        localEnglishTranslation = target == "en" && source != "en"
        errorMessage = nil
        history.removeAll()
        lastSource = ""
        lastTranslation = ""
        sessionToken = UUID()
        isActive = true
        translating = false

        // No chatbot callback may capture the television/computer audio.
        whisper.stopListening()
        AgentVoiceManager.shared.stop()
        AudioSessionManager.shared.beginContinuousVoiceSession()
        previousFinal = whisper.onFinalTranscription
        previousPartial = whisper.onPartialTranscription
        previousVoiceActivity = whisper.onVoiceActivity
        previousPlaybackFinished = neural.onPlaybackFinished
        previousPlaybackError = neural.onPlaybackError
        previousWhisperTranslation = WhisperService.shared.translateSpeechToEnglish
        previousWhisperLanguage = WhisperService.shared.preferredLanguageCode
        WhisperService.shared.translateSpeechToEnglish = localEnglishTranslation
        WhisperService.shared.preferredLanguageCode = source == "auto" ? nil : source

        let token = sessionToken
        whisper.onPartialTranscription = { [weak self] fragment in
            guard let self, self.isActive, self.sessionToken == token else { return }
            self.lastSource = fragment
        }
        whisper.onVoiceActivity = nil
        whisper.onFinalTranscription = { [weak self] transcript in
            self?.receivedFinal(transcript, token: token)
        }
        neural.onPlaybackFinished = { [weak self] in
            self?.playbackComplete(token: token)
        }
        neural.onPlaybackError = { [weak self] message in
            guard let self, self.isActive, self.sessionToken == token else { return }
            self.errorMessage = "Voix indisponible : " + message
            self.playbackComplete(token: token)
        }
        beginListening(token: token)
    }

    public func stop() {
        sessionToken = UUID()
        nextListenGeneration = UUID()
        guard isActive else { return }
        isActive = false
        translating = false
        isListening = false
        isSpeakingTranslation = false
        neural.onPlaybackFinished = previousPlaybackFinished
        neural.onPlaybackError = previousPlaybackError
        neural.stop()
        whisper.stopListening()
        whisper.onFinalTranscription = previousFinal
        whisper.onPartialTranscription = previousPartial
        whisper.onVoiceActivity = previousVoiceActivity
        previousFinal = nil
        previousPartial = nil
        previousVoiceActivity = nil
        previousPlaybackFinished = nil
        previousPlaybackError = nil
        WhisperService.shared.translateSpeechToEnglish = previousWhisperTranslation
        WhisperService.shared.preferredLanguageCode = previousWhisperLanguage
        AudioSessionManager.shared.endContinuousVoiceSession()
        status = "Translate Live arrêté."
    }

    private func beginListening(token: UUID) {
        guard isActive, sessionToken == token, !translating, !isSpeakingTranslation else { return }
        status = "Micro iPhone : j'écoute en \(TranslateLiveLanguages.label(for: sourceLanguage))…"
        if !whisper.isListening {
            whisper.startListening(autoFinalizeOnSilence: true, preserveActiveSpeech: true)
        }
        isListening = whisper.isListening
    }

    private func receivedFinal(_ transcript: String, token: UUID) {
        guard isActive, sessionToken == token, !translating, !isSpeakingTranslation else { return }
        let clean = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            scheduleNextListen(token: token, delay: 0.1)
            return
        }

        // Half duplex is intentional: no interpreted French should go back
        // into Whisper's microphone and trigger another interpretation.
        whisper.stopListening()
        isListening = false
        translating = true
        lastSource = clean
        status = "Traduction en cours…"
        if localEnglishTranslation {
            // Whisper's translate task already produced English directly on
            // the phone. No networking, no external MT server required.
            publishTranslation(clean, source: "(Whisper → English)", token: token)
            return
        }

        TranslateLiveTranslationBackend.translate(
            text: clean, from: sourceLanguage, to: targetLanguage,
            serverURL: customTranslationServerURL
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.isActive, self.sessionToken == token else { return }
                switch result {
                case .translated(let translated):
                    self.publishTranslation(translated, source: clean, token: token)
                case .unavailable(let reason):
                    self.translating = false
                    self.errorMessage = reason
                    self.status = "Traduction indisponible, je reprends l'écoute…"
                    self.scheduleNextListen(token: token, delay: 0.20)
                }
            }
        }
    }

    private func publishTranslation(_ text: String, source: String, token: UUID) {
        guard isActive, sessionToken == token else { return }
        translating = false
        let output = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !output.isEmpty else {
            scheduleNextListen(token: token, delay: 0.20)
            return
        }
        errorMessage = nil
        lastTranslation = output
        if localEnglishTranslation {
            lastSource = "Traduction directe via Whisper (la transcription source n'est pas conservée)"
        } else {
            lastSource = source
        }
        history.insert(Phrase(source: lastSource, translation: output), at: 0)
        if history.count > 30 { history.removeLast(history.count - 30) }

        guard TranslateLiveLanguages.spokenOutputCodes.contains(targetLanguage) else {
            status = "Traduction écrite prête. Pas de voix intégrée en \(TranslateLiveLanguages.label(for: targetLanguage))."
            scheduleNextListen(token: token, delay: 0.20)
            return
        }
        status = "Yoann prononce en \(TranslateLiveLanguages.label(for: targetLanguage))…"
        isSpeakingTranslation = true
        neural.speak(text: output, for: .yohan, language: targetLanguage)
    }

    private func playbackComplete(token: UUID) {
        guard isActive, sessionToken == token else { return }
        isSpeakingTranslation = false
        // Silence tail protects against speaker reverberation, especially in
        // a room where the computer and the iPhone both have loudspeakers.
        scheduleNextListen(token: token, delay: 0.55)
    }

    private func scheduleNextListen(token: UUID, delay: TimeInterval) {
        let next = UUID()
        nextListenGeneration = next
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.isActive, self.sessionToken == token,
                  self.nextListenGeneration == next else { return }
            self.beginListening(token: token)
        }
    }
}
