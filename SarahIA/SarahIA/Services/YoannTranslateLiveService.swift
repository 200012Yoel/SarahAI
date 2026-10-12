import Foundation
import SwiftUI
import AVFoundation
import UIKit
import Combine
#if canImport(Translation)
import Translation
#endif

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
    @Published public private(set) var isPreparingSpeech = false
    @Published public private(set) var isPlayingAudio = false
    @Published public private(set) var isTranslating = false
    @Published public private(set) var status = "Prêt à écouter une personne ou une vidéo."
    @Published public private(set) var lastSource = ""
    @Published public private(set) var provisionalSource = ""
    @Published public private(set) var recentSourceContext = ""
    @Published public private(set) var lastTranslation = ""
    @Published public private(set) var history: [Phrase] = []
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var headphoneConnected = false
    @Published public private(set) var waitingTranslations = 0
    @Published public private(set) var microphoneLevel: Float = 0
    @Published public private(set) var preparingSystemTranslation = false
    @Published public private(set) var isSystemTranslationReady = false

    public private(set) var sourceLanguage = "he"
    public private(set) var targetLanguage = "fr"

    private let whisper = WhisperService.shared
    private let neural = NeuralVoiceService.shared
    private var sessionToken = UUID()
    private var previousPlaybackFinished: (() -> Void)?
    private var previousPlaybackStarted: (() -> Void)?
    private var previousGenerationStarted: (() -> Void)?
    private var previousPlaybackError: ((String) -> Void)?
    private var previousWhisperTranslation = false
    private var previousWhisperLanguage: String?
    private var customTranslationServerURL = ""
    private var localEnglishTranslation = false
    private var nativeTranslator: ((String) async throws -> String)?
    private var nativeTranslationUnavailable = false

    /// Apple Translation supplies Hebrew→French entirely on iPhone if the
    /// language pack is available, without requiring the user's Debian server.
    public var shouldAttemptSystemTranslation: Bool {
        sourceLanguage == "he" && targetLanguage == "fr"
    }

    private var incoming: [String] = []
    private var outgoing: [Segment] = []
    private var translationBusy = false
    private var contextBuffer = TranslateLiveContextBuffer()
    private var routeObserver: NSObjectProtocol?
    private var lastAcceptedChunk = ""
    private var lastAcceptedAt = Date.distantPast
    private var micLevelSubscription: AnyCancellable?

    public init() {}

    /// Audible diagnostic: speak a known French phrase with the real bundled
    /// Supertonic voice, WITHOUT a translation server or input TV audio.
    /// Useful to distinguish a broken TTS / audio route from missing MT models.
    public func testFrenchSpeaker() {
        guard isActive, !isSpeakingTranslation else { return }
        errorMessage = nil
        isSpeakingTranslation = true
        neural.speak(
            text: "Bonjour. Je suis Yoann. Si tu m'entends, le haut-parleur fonctionne.",
            for: .yohan, language: "fr", qualitySteps: 5,
            dedicatedInterpreter: true
        )
        updateStatus()
    }

    public func start(from source: String, to target: String, serverURL: String = "") {
        stop()
        guard TranslateLiveLanguages.engineCode(for: source)
                != TranslateLiveLanguages.engineCode(for: target),
              TranslateLiveLanguages.isRecognized(source),
              TranslateLiveLanguages.isSelectableTarget(target) else {
            errorMessage = "Choisis deux langues valides et différentes."
            return
        }

        sourceLanguage = source
        targetLanguage = target
        customTranslationServerURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        localEnglishTranslation = TranslateLiveLanguages.isEnglish(target)
            && !TranslateLiveLanguages.isEnglish(source)
        errorMessage = nil
        lastSource = ""
        provisionalSource = ""
        recentSourceContext = ""
        contextBuffer.reset()
        lastTranslation = ""
        history.removeAll()
        incoming.removeAll()
        outgoing.removeAll()
        translationBusy = false
        isTranslating = false
        isSpeakingTranslation = false
        waitingTranslations = 0
        isPreparingSpeech = false
        isPlayingAudio = false
        lastAcceptedChunk = ""
        lastAcceptedAt = .distantPast
        nativeTranslator = nil
        nativeTranslationUnavailable = false
        preparingSystemTranslation = false
        isSystemTranslationReady = false
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
        previousPlaybackStarted = neural.onPlaybackStarted
        previousGenerationStarted = neural.onGenerationStarted
        previousPlaybackError = neural.onPlaybackError
        previousWhisperTranslation = whisper.translateSpeechToEnglish
        previousWhisperLanguage = whisper.preferredLanguageCode
        whisper.translateSpeechToEnglish = localEnglishTranslation
        whisper.preferredLanguageCode = source == "auto"
            ? nil : TranslateLiveLanguages.engineCode(for: source)

        // A live input meter distinguishes "microphone is open" from actual
        // captured sound, without recording private audio samples in logs.
        micLevelSubscription = whisper.$micEnergyLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.microphoneLevel = value
            }

        updateAudioRoute()
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.updateAudioRoute() }
        }

        let token = sessionToken
        whisper.onLiveInterpretationChunk = { [weak self] chunk, paused in
            guard let self, self.isActive, self.sessionToken == token else { return }
            self.receive(chunk: chunk, paused: paused, token: token)
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
        neural.onGenerationStarted = { [weak self] in
            guard let self, self.isActive, self.sessionToken == token else { return }
            self.isPreparingSpeech = true
            self.isPlayingAudio = false
            self.updateStatus()
        }
        neural.onPlaybackStarted = { [weak self] in
            guard let self, self.isActive, self.sessionToken == token else { return }
            self.isPreparingSpeech = false
            self.isPlayingAudio = true
            self.updateStatus()
        }
        neural.onPlaybackFinished = { [weak self] in
            guard let self, self.sessionToken == token else { return }
            self.isSpeakingTranslation = false
            self.isPreparingSpeech = false
            self.isPlayingAudio = false
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
        isPreparingSpeech = false
        isPlayingAudio = false
        incoming.removeAll()
        outgoing.removeAll()
        waitingTranslations = 0
        translationBusy = false
        nativeTranslator = nil
        preparingSystemTranslation = false
        isSystemTranslationReady = false
        nativeTranslationUnavailable = true
        micLevelSubscription?.cancel()
        micLevelSubscription = nil
        microphoneLevel = 0
        provisionalSource = ""
        recentSourceContext = ""
        contextBuffer.reset()

        if let routeObserver {
            NotificationCenter.default.removeObserver(routeObserver)
            self.routeObserver = nil
        }
        // Restore listeners BEFORE canceling playback so an old session
        // cannot receive a synthetic "speech finished" event.
        neural.onPlaybackFinished = previousPlaybackFinished
        neural.onPlaybackStarted = previousPlaybackStarted
        neural.onGenerationStarted = previousGenerationStarted
        neural.onPlaybackError = previousPlaybackError
        previousPlaybackFinished = nil
        previousPlaybackStarted = nil
        previousGenerationStarted = nil
        previousPlaybackError = nil
        neural.stop()
        whisper.stopLiveInterpretation()
        whisper.translateSpeechToEnglish = previousWhisperTranslation
        whisper.preferredLanguageCode = previousWhisperLanguage
        AudioSessionManager.shared.endContinuousVoiceSession()
        status = "Translate Live arrêté."
    }

    private func receive(chunk: String, paused: Bool, token: UUID) {
        guard isActive, sessionToken == token else { return }
        if TranslateLiveContextBuffer.isUnreliableTranscript(chunk) {
            // Music and long repeated token loops are Whisper hypotheses,
            // not a verified translation of the TV broadcast.
            errorMessage = "Whisper entend de la musique ou répète des mots. Vérifie que la chaîne parle réellement la langue choisie."
            provisionalSource = ""
            return
        }
        let cleaned = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned == lastAcceptedChunk && Date().timeIntervalSince(lastAcceptedAt) < 1.6 {
            return
        }
        lastAcceptedChunk = cleaned
        lastAcceptedAt = Date()
        let update = contextBuffer.receive(cleaned, paused: paused)

        // The caption may change while the next words are understood.
        // Spoken output NEVER consumes this provisional text.
        provisionalSource = update.provisional
        recentSourceContext = update.recentContext

        // Only committed source text feeds subsequent Whisper prompts.
        // Context remains short to avoid repetitions and hallucinations.
        whisper.liveRecognitionContext = update.recentContext

        for stable in update.committed {
            lastSource = stable
            if localEnglishTranslation {
                // Whisper has already produced a stable English rendering.
                appendTranslated(
                    text: stable, original: "Voix → anglais via Whisper", token: token
                )
                continue
            }
            if incoming.count >= 8 {
                incoming.removeFirst()
                errorMessage = "Le modèle n'arrive pas à suivre : un ancien passage a été ignoré."
            }
            incoming.append(stable)
        }
        waitingTranslations = incoming.count
        translateNext(token: token)
        updateStatus()
    }

    // MARK: - Native iOS Translation (installed language packs; no server)

    #if canImport(Translation)
    @available(iOS 18.0, *)
    public func useSystemTranslation(_ session: TranslationSession) async {
        let token = sessionToken
        guard isActive, shouldAttemptSystemTranslation else { return }

        preparingSystemTranslation = true
        updateStatus()
        do {
            // SwiftUI's translationTask allows iOS to request permission to
            // download the Hebrew/French pair once. The user chooses whether.
            try await session.prepareTranslation()
            guard isActive, sessionToken == token, !Task.isCancelled else { return }

            nativeTranslator = { text in
                let result = try await session.translate(text)
                return result.targetText
            }
            nativeTranslationUnavailable = false
            preparingSystemTranslation = false
            isSystemTranslationReady = true
            errorMessage = nil
            translateNext(token: token)
            updateStatus()

            // TranslationSession supplied by translationTask is valid only
            // while the task/view is alive. Never retain it after this exits.
            while !Task.isCancelled && isActive && sessionToken == token {
                do {
                    try await Task.sleep(nanoseconds: 500_000_000)
                } catch { break }
            }
        } catch {
            guard isActive, sessionToken == token else { return }
            nativeTranslationUnavailable = true
            preparingSystemTranslation = false
            isSystemTranslationReady = false
            errorMessage = "Traduction iOS indisponible : \(error.localizedDescription). Vérifie les langues hébreu/français ou configure ton serveur dans ⚙️."
            translateNext(token: token)
            updateStatus()
        }
        guard sessionToken == token else { return }
        nativeTranslator = nil
        isSystemTranslationReady = false
        preparingSystemTranslation = false
    }
    #endif

    private func translateNext(token: UUID) {
        guard isActive, sessionToken == token, !translationBusy, !incoming.isEmpty else { return }

        // On iOS 27, don't discard real broadcast sentences before the
        // system has had a chance to install and prepare its translation pack.
        if shouldAttemptSystemTranslation && nativeTranslator == nil
                && !nativeTranslationUnavailable
                && customTranslationServerURL.isEmpty {
            // When a user-owned translator is configured, do not stall every
            // TV sentence while Apple's optional language pack prepares.
            if #available(iOS 18.0, *) {
                preparingSystemTranslation = true
                updateStatus()
                return
            }
        }
        translationBusy = true
        isTranslating = true
        let fragment = incoming.removeFirst()
        waitingTranslations = incoming.count

        if shouldAttemptSystemTranslation, let native = nativeTranslator {
            Task { [weak self] in
                guard let self, self.isActive, self.sessionToken == token else { return }
                do {
                    let output = try await native(fragment)
                    self.finishTranslation(.translated(output), original: fragment, token: token)
                } catch {
                    // Don't silently label a failed system translation as a
                    // valid French answer. An explicitly configured server
                    // remains the fallback for other language combinations.
                    self.nativeTranslator = nil
                    self.nativeTranslationUnavailable = true
                    self.isSystemTranslationReady = false
                    if !self.customTranslationServerURL.isEmpty {
                        // The user's local server is a second, independent
                        // engine if iOS cannot translate this fragment.
                        self.translationBusy = false
                        self.isTranslating = false
                        self.incoming.insert(fragment, at: 0)
                        self.translateNext(token: token)
                    } else {
                        self.finishTranslation(
                            .unavailable("Traduction iOS : \(error.localizedDescription). Autorise le téléchargement hébreu/français ou configure un serveur dans ⚙️."),
                            original: fragment, token: token
                        )
                    }
                }
            }
            return
        }

        TranslateLiveTranslationBackend.translate(
            text: fragment,
            from: TranslateLiveLanguages.engineCode(for: sourceLanguage),
            to: TranslateLiveLanguages.engineCode(for: targetLanguage),
            serverURL: customTranslationServerURL
        ) { [weak self] outcome in
            DispatchQueue.main.async {
                self?.finishTranslation(outcome, original: fragment, token: token)
            }
        }
        updateStatus()
    }

    private func finishTranslation(
        _ outcome: TranslateLiveTranslationBackend.Outcome,
        original: String,
        token: UUID
    ) {
        guard isActive, sessionToken == token else { return }
        translationBusy = false
        isTranslating = false
        switch outcome {
        case .translated(let output):
            appendTranslated(text: output, original: original, token: token)
        case .unavailable(let reason):
            errorMessage = reason
        }
        translateNext(token: token)
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

        guard TranslateLiveLanguages.spokenOutputCodes.contains(
            TranslateLiveLanguages.engineCode(for: targetLanguage)
        ) else {
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
            language: TranslateLiveLanguages.engineCode(for: targetLanguage),
            qualitySteps: 5,
            dedicatedInterpreter: true
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
        } else if isPlayingAudio {
            status = "🔊 Voix française en lecture, le micro continue d'écouter…"
        } else if isPreparingSpeech {
            status = "⌛ Préparation de la voix neuronale…"
        } else if preparingSystemTranslation {
            status = "⌛ Préparation de la traduction hébreu → français sur l’iPhone…"
        } else if translationBusy {
            status = "🎙️ Écoute continue, traduction en cours…"
        } else {
            status = "🎙️ Interprétation en direct : écoute continue"
        }
    }
}
