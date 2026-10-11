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
    public struct Language: Identifiable, Hashable {
        public let id: String
        public let label: String
        public static let available = [
            Language(id: "he", label: "Hébreu"),
            Language(id: "fr", label: "Français"),
            Language(id: "en", label: "Anglais")
        ]
        public static func label(for id: String) -> String {
            available.first(where: { $0.id == id })?.label ?? id
        }
    }

    public struct Phrase: Identifiable {
        public let id = UUID()
        public let source: String
        public let translation: String
    }

    /// A spoken chat command such as "active Translate Live hébreu français".
    public static func commandPair(_ text: String) -> (from: String, to: String)? {
        let normalized = text.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "fr_FR")
        ).lowercased()
        guard normalized.contains("translate live"),
              ["active", "lance", "demarre", "ouvre", "mets"].contains(where: normalized.contains) else {
            return nil
        }
        let terms: [(word: String, lang: String)] = [
            ("hebreu", "he"), ("francais", "fr"), ("anglais", "en")
        ]
        let matches: [(index: Int, language: String)] = terms.compactMap { item in
            guard let range = normalized.range(of: item.word) else { return nil }
            return (index: normalized.distance(from: normalized.startIndex, to: range.lowerBound),
                    language: item.lang)
        }.sorted { $0.index < $1.index }
        guard matches.count >= 2 else { return ("he", "fr") }
        return (matches[0].language, matches[1].language)
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

    public init() {}

    public func start(from source: String, to target: String) {
        stop()
        guard source != target else {
            errorMessage = "Choisissez deux langues différentes."
            return
        }
        guard Language.available.contains(where: { $0.id == source }),
              Language.available.contains(where: { $0.id == target }) else {
            errorMessage = "Cette combinaison de langues n'est pas disponible."
            return
        }

        sourceLanguage = source
        targetLanguage = target
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
        AudioSessionManager.shared.endContinuousVoiceSession()
        status = "Translate Live arrêté."
    }

    private func beginListening(token: UUID) {
        guard isActive, sessionToken == token, !translating, !isSpeakingTranslation else { return }
        status = "J'écoute l'hébreu ou la langue choisie depuis le microphone…"
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
        let desired = TranslationEngine.TargetLanguage(rawValue: targetLanguage)
        guard let target = desired else {
            translating = false
            scheduleNextListen(token: token, delay: 0.2)
            return
        }

        TranslationEngine.shared.translate(text: clean, sourceLang: sourceLanguage, targetLang: target) { [weak self] translated in
            DispatchQueue.main.async {
                guard let self, self.isActive, self.sessionToken == token else { return }
                self.translating = false
                let output = translated.trimmingCharacters(in: .whitespacesAndNewlines)
                if output.isEmpty || output.caseInsensitiveCompare(clean) == .orderedSame {
                    // TranslationEngine's legacy error fallback returns the ORIGINAL input.
                    // Never read a fake 'French translation' in Hebrew.
                    self.errorMessage = "Traduction indisponible pour ce passage. Le moteur actuel a besoin d'un véritable modèle de traduction pour les phrases longues."
                    self.status = "Passage non traduit. Reprise de l'écoute…"
                    self.scheduleNextListen(token: token, delay: 0.2)
                    return
                }
                self.errorMessage = nil
                self.lastTranslation = output
                self.history.insert(Phrase(source: clean, translation: output), at: 0)
                if self.history.count > 30 { self.history.removeLast() }

                guard self.targetLanguage != "he" else {
                    // Supertonic 3 cannot synthesize Hebrew. Show text, no fake voice.
                    self.status = "Traduction écrite prête. Voix hébraïque non installée."
                    self.scheduleNextListen(token: token, delay: 0.2)
                    return
                }
                self.status = "Yoann prononce la traduction sur l'iPhone…"
                self.isSpeakingTranslation = true
                self.neural.speak(text: output, for: .yohan, language: self.targetLanguage)
            }
        }
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
