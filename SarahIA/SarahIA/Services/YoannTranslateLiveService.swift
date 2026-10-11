import Foundation
import SwiftUI
import AVFoundation
import UIKit

/// Simultaneous-style interpreter for external speech (person/TV/PC) heard
/// through the iPhone microphone. Whisper records continuously on device,
/// including during transcription and neural playback. Chunks are processed
/// on independent bounded queues. The user explicitly stops the session.
///
/// An earbud is strongly recommended: iOS voiceChat echo suppression exists,
/// but speaker playback in the same room cannot guarantee perfect isolation.
@available(iOS 16.2, *)
@MainActor
public final class YoannTranslateLiveService: ObservableObject {
    public typealias Language = TranslateLiveLanguages.Language

    public struct Phrase: Identifiable {
        public let id = UUID()
        public let source: String
        public let translation: String
    }

    private struct Segment {
        let source: String
        let translation: String
    }

    public static func commandPair(_ text: String) -> (from: String, to: String)? {
        TranslateLiveLanguages.pairFromCommand(text)
    }

    @Published public private(set) var isActive = false
    @Published public private(set) var isListening = false
    @Published public private(set) var isSpeakingTranslation = false
    @Published public private(set) var isTranslating = false
    @Published public private(set) var status = "Prêt à écouter une personne ou une vidéo."
    @Published public private(set) var lastSource = ""
    @Published public private(set) var lastTranslation = ""
    @Published public private(set) var history: [Phrase] = []
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var headphoneConnected = false
    @Published public private(set) var waitingTranslations = 0

    public private(set) var sourceLanguage = "he"
    public private(set) var targetLanguage = "fr"

    private let whisper = WhisperService.shared
    private let neural = NeuralVoiceService.shared
    private var sessionToken = UUID()
    private var previousPlaybackFinished: (() -> Void)?
    private var previousPlaybackError: ((String) -> Void)?
    private var previousWhisperTranslation = false
    private var previousWhisperLanguage: String?
    private var customTranslationServerURL = ""
    private var localEnglishTranslation = false

    private var incoming: [String] = []
    private var outgoing: [Segment] = []
    private var translationBusy = false
    private var lastChunk = ""
    private var routeObserver: NSObjectProtocol?

    public init() {}

    public func start(from source: String, to target: String, serverURL: String = "") {
        stop()
        guard source != target,
              TranslateLiveLanguages.isRecognized(source),
              TranslateLiveLanguages.isSelectableTarget(target) else {
            errorMessage = "Choisis deux langues valides et différentes."
            return
        }

        sourceLanguage = source
        targetLanguage = target
        customTranslationServerURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        localEnglishTranslation = target == "en" && source != "en"
        errorMessage = nil
        lastSource = ""
        lastTranslation = ""
        history.removeAll()
        incoming.removeAll()
        outgoing.removeAll()
        translationBusy = false
        isTranslating = false
        isSpeakingTranslation = false
        waitingTranslations = 0
        lastChunk = ""
        sessionToken = UUID()
        isActive = true

        // Ownership of the mic must never be shared with regular assistant chat.
        WhisperSpeechRecognizer.shared.stopListening()
        AgentVoiceManager.shared.stop()
        // Set an interpreter-specific route BEFORE starting the input tap.
        // This prefers the iPhone microphone while AirPods/earbuds can play
        // translated speech through an output route that supports it.
        AudioSessionManager.shared.beginContinuousInterpreterSession()

        previousPlaybackFinished = neural.onPlaybackFinished
        previousPlaybackError = neural.onPlaybackError
        previousWhisperTranslation = whisper.translateSpeechToEnglish
        previousWhisperLanguage = whisper.preferredLanguageCode
        whisper.translateSpeechToEnglish = localEnglishTranslation
        whisper.preferredLanguageCode = source == "auto" ? nil : source

        updateAudioRoute()
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.updateAudioRoute() }
        }

        let token = sessionToken
        whisper.onLiveInterpretationChunk = { [weak self] chunk in
            guard let self, self.isActive, self.sessionToken == token else { return }
            self.receive(chunk: chunk, token: token)
        }
        whisper.onLiveInterpretationError = { [weak self] message in
            guard let self, self.isActive, self.sessionToken == token else { return }
            self.errorMessage = message
            self.updateStatus()
        }
        whisper.onLiveMicrophoneChanged = { [weak self] listening in
            guard let self, self.isActive, self.sessionToken == token else { return }
            self.isListening = listening
            self.updateStatus()
        }
        neural.onPlaybackFinished = { [weak self] in
            guard let self, self.sessionToken == token else { return }
            self.isSpeakingTranslation = false
            self.playNextSpeech(token: token)
        }
        neural.onPlaybackError = { [weak self] message in
            guard let self, self.sessionToken == token else { return }
            self.errorMessage = "La voix n'a pas pu être générée : " + message
            // NeuralVoiceService signals onPlaybackFinished after the error,
            // which will drain the next queued segment once.
        }

        status = "Initialisation de Whisper… Le micro reste actif tant que ce mode est ouvert."
        whisper.startLiveInterpretation()
    }

    public func stop() {
        sessionToken = UUID()
        guard isActive else { return }
        isActive = false
        isListening = false
        isTranslating = false
        isSpeakingTranslation = false
        incoming.removeAll()
        outgoing.removeAll()
        waitingTranslations = 0
        translationBusy = false
        lastChunk = ""

        if let routeObserver {
            NotificationCenter.default.removeObserver(routeObserver)
            self.routeObserver = nil
        }
        // Restore listeners BEFORE canceling playback so an old session
        // cannot receive a synthetic "speech finished" event.
        neural.onPlaybackFinished = previousPlaybackFinished
        neural.onPlaybackError = previousPlaybackError
        previousPlaybackFinished = nil
        previousPlaybackError = nil
        neural.stop()
        whisper.stopLiveInterpretation()
        whisper.translateSpeechToEnglish = previousWhisperTranslation
        whisper.preferredLanguageCode = previousWhisperLanguage
        AudioSessionManager.shared.endContinuousVoiceSession()
        status = "Translate Live arrêté."
    }

    private func receive(chunk: String, token: UUID) {
        guard isActive, sessionToken == token else { return }
        let clean = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        // Speech recognizers can repeat a partial hypothesis. Drop identical
        // consecutive completed segments, never strip arbitrary words.
        guard clean != lastChunk else { return }
        lastChunk = clean
        lastSource = clean

        if localEnglishTranslation {
            // Whisper itself generated English in the background.
            appendTranslated(text: clean, original: "Voix reconnue → anglais (Whisper)", token: token)
            return
        }

        if incoming.count >= 8 {
            incoming.removeFirst()
            errorMessage = "Parole trop rapide pour ce modèle : un segment en attente a été ignoré."
        }
        incoming.append(clean)
        waitingTranslations = incoming.count
        translateNext(token: token)
    }

    private func translateNext(token: UUID) {
        guard isActive, sessionToken == token, !translationBusy, !incoming.isEmpty else { return }
        translationBusy = true
        isTranslating = true
        let fragment = incoming.removeFirst()
        waitingTranslations = incoming.count

        TranslateLiveTranslationBackend.translate(
            text: fragment,
            from: sourceLanguage,
            to: targetLanguage,
            serverURL: customTranslationServerURL
        ) { [weak self] outcome in
            DispatchQueue.main.async {
                guard let self, self.isActive, self.sessionToken == token else { return }
                self.translationBusy = false
                self.isTranslating = false
                switch outcome {
                case .translated(let output):
                    self.appendTranslated(text: output, original: fragment, token: token)
                case .unavailable(let reason):
                    self.errorMessage = reason
                }
                self.translateNext(token: token)
                self.updateStatus()
            }
        }
        updateStatus()
    }

    private func appendTranslated(text: String, original: String, token: UUID) {
        guard isActive, sessionToken == token else { return }
        let result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { return }
        errorMessage = nil
        lastTranslation = result
        history.insert(Phrase(source: original, translation: result), at: 0)
        if history.count > 40 { history.removeLast(history.count - 40) }

        guard TranslateLiveLanguages.spokenOutputCodes.contains(targetLanguage) else {
            updateStatus()
            return
        }

        if outgoing.count >= 10 {
            outgoing.removeFirst()
            errorMessage = "La lecture vocale a du retard : un ancien passage a été ignoré."
        }
        outgoing.append(Segment(source: original, translation: result))
        playNextSpeech(token: token)
    }

    private func playNextSpeech(token: UUID) {
        guard isActive, sessionToken == token, !isSpeakingTranslation else { return }
        guard !outgoing.isEmpty else {
            updateStatus()
            return
        }
        let part = outgoing.removeFirst()
        isSpeakingTranslation = true
        updateStatus()
        // IMPORTANT: DO NOT STOP THE MICROPHONE. Headphones separate playback
        // acoustically; AVAudioSession.voiceChat supplies system echo control.
        neural.speak(
            text: part.translation, for: .yohan,
            language: targetLanguage, qualitySteps: 5
        )
    }

    private func updateAudioRoute() {
        let types = AVAudioSession.sharedInstance().currentRoute.outputs.map(\.portType)
        headphoneConnected = types.contains(.headphones)
            || types.contains(.bluetoothHFP)
            || types.contains(.bluetoothA2DP)
            || types.contains(.bluetoothLE)
        updateStatus()
    }

    private func updateStatus() {
        guard isActive else { return }
        if !isListening {
            status = whisper.isModelLoading ? "Whisper se charge…" : "Ouverture du microphone…"
        } else if isSpeakingTranslation {
            status = "🎧 Yoann parle, le micro continue d'écouter…"
        } else if translationBusy {
            status = "🎙️ Écoute continue, traduction en cours…"
        } else {
            status = "🎙️ Interprétation en direct : écoute continue"
        }
    }
}
