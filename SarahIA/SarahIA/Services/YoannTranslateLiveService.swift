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

    private struct PendingTranslation {
        let source: String
        let input: String
        let fromEnglishPivot: Bool
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
    @Published public private(set) var needsEnglishPivotTranslation = false
    @Published public private(set) var isUsingLocalQwen = false
    @Published public private(set) var isUsingEnglishPivot = false
    @Published public private(set) var translationSetupMessage = "Vérification du moteur hébreu → français…"

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
    private var nativeEnglishToFrenchTranslator: ((String) async throws -> String)?
    private var nativeTranslationUnavailable = false

    /// Apple Translation supplies Hebrew→French entirely on iPhone if the
    /// language pack is available, without requiring the user's Debian server.
    public var shouldAttemptSystemTranslation: Bool {
        sourceLanguage == "he" && targetLanguage == "fr"
    }

    private var isHebrewFrenchPair: Bool {
        let source = TranslateLiveLanguages.engineCode(for: sourceLanguage)
        let target = TranslateLiveLanguages.engineCode(for: targetLanguage)
        return (source == "he" && target == "fr") ||
               (source == "fr" && target == "he")
    }

    private var incoming: [PendingTranslation] = []
    private var outgoing: [Segment] = []
    private var translationBusy = false
    private var contextBuffer = TranslateLiveContextBuffer()
    private var routeObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var qwenDownloadObserver: NSObjectProtocol?
    private var lastAcceptedChunk = ""
    private var lastAcceptedAt = Date.distantPast
    private var lastEnglishIntermediate = ""
    private var lastEnglishIntermediateSource = ""
    private var lastEnglishIntermediateAt = Date.distantPast
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
        lastEnglishIntermediate = ""
        lastEnglishIntermediateSource = ""
        lastEnglishIntermediateAt = .distantPast
        nativeTranslator = nil
        nativeEnglishToFrenchTranslator = nil
        nativeTranslationUnavailable = false
        needsEnglishPivotTranslation = false
        isUsingEnglishPivot = false
        isUsingLocalQwen = false
        whisper.liveDualDecodeEnglish = false
        preparingSystemTranslation = false
        isSystemTranslationReady = false
        translationSetupMessage = "Vérification du pack de traduction hébreu → français…"
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
            Task { @MainActor in
                guard let self else { return }
                self.updateAudioRoute()
                self.scheduleMicrophoneRecovery(token: self.sessionToken)
            }
        }
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let value = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  value == AVAudioSession.InterruptionType.ended.rawValue else { return }
            Task { @MainActor in
                guard let self else { return }
                self.scheduleMicrophoneRecovery(token: self.sessionToken)
            }
        }

        let token = sessionToken
        whisper.onLiveInterpretationChunk = { [weak self] chunk, paused in
            guard let self, self.isActive, self.sessionToken == token,
                  !self.isUsingEnglishPivot else { return }
            self.receive(chunk: chunk, paused: paused, token: token)
        }
        whisper.onLiveEnglishPivotChunk = { [weak self] source, english, paused in
            guard let self, self.isActive, self.sessionToken == token,
                  self.isUsingEnglishPivot else { return }
            self.receiveEnglishPivot(source: source, english: english, paused: paused, token: token)
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

        // An installed Qwen3 GGUF translates Hebrew↔French directly.
        // Qwen model WEIGHTS are downloaded into Application Support; the IPA
        // only contains the llama.cpp inference runtime.
        if isHebrewFrenchPair && customTranslationServerURL.isEmpty {
            if TranslateLiveTranslationBackend.isLocalQwenReady {
                activateLocalQwen(token: token)
            } else {
                if ModelSelectionEngine.shared.isLocalGGUFAllowed() {
                    // Existing BackgroundModelDownloader uses Wi-Fi only and
                    // resumes downloads. Never silently use cellular data.
                    BackgroundModelDownloader.shared.startQwenModelDownload()
                    translationSetupMessage = "Téléchargement Wi-Fi de Qwen3 en cours. Un moteur direct hébreu ↔ français sera disponible après installation."
                }
                if shouldAttemptSystemTranslation {
                    requestEnglishPivot(token: token)
                } else {
                    errorMessage = "Installe d'abord Qwen3 depuis le Wi-Fi pour traduire français → hébreu sans serveur."
                }
            }
            qwenDownloadObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("SarahModelDownloadCompleted"),
                object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.activateLocalQwen(token: self.sessionToken)
                }
            }
        }

        status = "Initialisation de Whisper… Le micro reste actif tant que ce mode est ouvert."
        whisper.startLiveInterpretation()

        // If the SwiftUI English translationTask is not attached, explain
        // why captions cannot yet appear instead of simulating responses.
        if shouldAttemptSystemTranslation && customTranslationServerURL.isEmpty
           && !isUsingLocalQwen {
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 12_000_000_000)
                guard let self, self.isActive, self.sessionToken == token,
                      self.nativeEnglishToFrenchTranslator == nil,
                      !self.isUsingEnglishPivot else { return }
                self.preparingSystemTranslation = false
                self.translationSetupMessage = "Le moteur anglais → français n'a pas démarré. Vérifie les langues anglais et français de Traduire sur cet iPhone."
                self.errorMessage = self.translationSetupMessage
                self.updateStatus()
            }
        }
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
        nativeEnglishToFrenchTranslator = nil
        needsEnglishPivotTranslation = false
        isUsingEnglishPivot = false
        isUsingLocalQwen = false
        whisper.liveDualDecodeEnglish = false
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
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
            self.interruptionObserver = nil
        }
        if let qwenDownloadObserver {
            NotificationCenter.default.removeObserver(qwenDownloadObserver)
            self.qwenDownloadObserver = nil
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
            if needsEnglishPivotTranslation && !isUsingEnglishPivot {
                // Hold off instead of passing raw Hebrew text into an
                // unsupported iOS translation pair.
                continue
            }
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
            incoming.append(PendingTranslation(
                source: stable, input: stable, fromEnglishPivot: false
            ))
        }
        waitingTranslations = incoming.count
        translateNext(token: token)
        updateStatus()
    }

    /// Fallback that preserves Hebrew captions while using the offline
    /// Whisper speech-to-English decoder and Apple's English→French pack.
    /// Input is paired on the *same microphone audio*, not guessed from
    /// the Hebrew transcription.
    private func receiveEnglishPivot(
        source: String, english: String, paused: Bool, token: UUID
    ) {
        guard isActive, sessionToken == token, isUsingEnglishPivot else { return }
        let hebrew = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let intermediate = english.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !TranslateLiveContextBuffer.isUnreliableTranscript(hebrew),
              (sourceLanguage != "he" || TranslateLiveContextBuffer.isMostlyHebrew(hebrew)),
              !TranslateLiveContextBuffer.isSuspiciousEnglishPivot(
                intermediate, hebrewSource: hebrew
              ),
              intermediate.range(of: "[A-Za-z]", options: .regularExpression) != nil,
              !hebrew.isEmpty else {
            errorMessage = "Traduction incertaine ignorée : Whisper n'a pas compris cet extrait de la chaîne."
            return
        }
        if hebrew == lastAcceptedChunk && Date().timeIntervalSince(lastAcceptedAt) < 1.6 {
            return
        }
        let normalizedEnglish = intermediate.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        // Repeated stock translations for *different* Hebrew clauses
        // are not evidence of real interpretation. Drop them before iOS TTS.
        if normalizedEnglish == lastEnglishIntermediate,
           hebrew != lastEnglishIntermediateSource,
           Date().timeIntervalSince(lastEnglishIntermediateAt) < 25 {
            errorMessage = "Whisper répète une traduction anglaise sans rapport avec le nouvel hébreu. Extrait ignoré."
            return
        }
        lastEnglishIntermediate = normalizedEnglish
        lastEnglishIntermediateSource = hebrew
        lastEnglishIntermediateAt = Date()
        lastAcceptedChunk = hebrew
        lastAcceptedAt = Date()
        lastSource = hebrew
        provisionalSource = ""
        recentSourceContext = hebrew
        if incoming.count >= 8 {
            incoming.removeFirst()
            errorMessage = "Le téléphone traduit moins vite que la chaîne. Un extrait ancien a été ignoré."
        }
        incoming.append(PendingTranslation(
            source: hebrew, input: intermediate, fromEnglishPivot: true
        ))
        waitingTranslations = incoming.count
        translateNext(token: token)
        updateStatus()
    }

    /// Model-backed bidirectional translation. Never reuse English pivot
    /// captions after Qwen3 becomes available or produce canned phrases.
    private func activateLocalQwen(token: UUID) {
        guard isActive, sessionToken == token, isHebrewFrenchPair,
              customTranslationServerURL.isEmpty,
              TranslateLiveTranslationBackend.isLocalQwenReady else { return }
        needsEnglishPivotTranslation = false
        isUsingEnglishPivot = false
        isUsingLocalQwen = true
        whisper.liveDualDecodeEnglish = false
        preparingSystemTranslation = false
        isSystemTranslationReady = true
        incoming.removeAll()
        waitingTranslations = 0
        translationSetupMessage = "Traduction neuronale locale Qwen3 active : hébreu ↔ français direct, sans anglais ni réseau."
        errorMessage = nil
        updateStatus()
    }

    private func requestEnglishPivot(token: UUID) {
        guard isActive, sessionToken == token,
              shouldAttemptSystemTranslation,
              !isUsingLocalQwen,
              customTranslationServerURL.isEmpty else { return }
        nativeTranslationUnavailable = true
        nativeTranslator = nil
        isSystemTranslationReady = false
        incoming.removeAll()
        waitingTranslations = 0
        preparingSystemTranslation = false
        needsEnglishPivotTranslation = true
        translationSetupMessage = "Démarrage de Whisper hébreu → anglais et du traducteur neuronal anglais → français (aucun pack hébreu Apple nécessaire)…"
        errorMessage = nil
        activateEnglishPivotIfReady(token: token)
    }

    private func activateEnglishPivotIfReady(token: UUID) {
        guard isActive, sessionToken == token, needsEnglishPivotTranslation,
              nativeEnglishToFrenchTranslator != nil else { return }
        whisper.liveDualDecodeEnglish = true
        isUsingEnglishPivot = true
        isSystemTranslationReady = true
        preparingSystemTranslation = false
        translationSetupMessage = "Moteur réel actif : Whisper hébreu → anglais, puis Traduire anglais → français hors ligne."
        errorMessage = nil
        updateStatus()
    }

    // MARK: - Native iOS Translation (installed language packs; no server)

    #if canImport(Translation)
    @available(iOS 18.0, *)
    public func useSystemTranslation(_ session: TranslationSession) async {
        let token = sessionToken
        guard isActive, shouldAttemptSystemTranslation else { return }

        preparingSystemTranslation = true
        translationSetupMessage = "Vérification des langues hébreu et français…"
        updateStatus()
        do {
            let source = Locale.Language(identifier: "he")
            let target = Locale.Language(identifier: "fr")
            let availability = LanguageAvailability()
            let available = await availability.status(from: source, to: target)
            guard isActive, sessionToken == token, !Task.isCancelled else { return }
            switch available {
            case .unsupported:
                // Native Hebrew→French is absent on this particular iOS.
                // Never ask the user to repeatedly install an unsupported
                // language pack. Try offline Whisper→English→French instead.
                preparingSystemTranslation = false
                requestEnglishPivot(token: token)
                updateStatus()
                return
            case .supported:
                translationSetupMessage = "Téléchargement du pack iOS requis une seule fois : accepte la demande d'iOS."
            case .installed:
                translationSetupMessage = "Pack de traduction déjà installé sur l'iPhone."
            @unknown default:
                translationSetupMessage = "Vérification du pack de traduction iOS…"
            }

            // This may prompt for a one-time download. An offline iPhone
            // cannot install Apple's language assets for the first time.
            try await session.prepareTranslation()
            guard isActive, sessionToken == token, !Task.isCancelled else { return }
            // prepareTranslation() can return while language assets are
            // still downloading, so do not report "ready" prematurely.
            var installed = false
            for _ in 0..<20 {
                let state = await availability.status(from: source, to: target)
                guard isActive, sessionToken == token, !Task.isCancelled else { return }
                if state == .installed {
                    installed = true
                    break
                }
                translationSetupMessage = "Téléchargement du pack hébreu/français en cours…"
                try await Task.sleep(nanoseconds: 1_500_000_000)
            }
            guard installed else {
                throw NSError(domain: "SarahTranslateLive", code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "Le pack hébreu/français n'est pas encore installé. Vérifie la connexion, puis relance."])
            }
            guard isActive, sessionToken == token, !Task.isCancelled else { return }

            nativeTranslator = { text in
                let result = try await session.translate(text)
                return result.targetText
            }
            nativeTranslationUnavailable = false
            preparingSystemTranslation = false
            isSystemTranslationReady = true
            translationSetupMessage = "Traduction hébreu → français installée, utilisable hors connexion."
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
            translationSetupMessage = "Traduction iOS directe indisponible : \(error.localizedDescription)"
            requestEnglishPivot(token: token)
            updateStatus()
        }
        guard sessionToken == token else { return }
        nativeTranslator = nil
        isSystemTranslationReady = false
        preparingSystemTranslation = false
    }
    /// English→French is a widely supported offline Apple Translation pair.
    /// This view-hosted session is activated only if native Hebrew→French is
    /// rejected. Whisper provides the English intermediate locally.
    @available(iOS 18.0, *)
    public func useEnglishPivotTranslation(_ session: TranslationSession) async {
        let token = sessionToken
        guard isActive, needsEnglishPivotTranslation else { return }
        translationSetupMessage = "Vérification du pack anglais → français sur l'iPhone…"
        do {
            let source = Locale.Language(identifier: "en")
            let target = Locale.Language(identifier: "fr")
            let availability = LanguageAvailability()
            let state = await availability.status(from: source, to: target)
            guard isActive, sessionToken == token, !Task.isCancelled else { return }
            switch state {
            case .unsupported:
                translationSetupMessage = "Même la paire anglais → français est indisponible dans le framework iOS."
                errorMessage = translationSetupMessage + " Un autre modèle de traduction hors ligne est nécessaire."
                return
            case .supported:
                translationSetupMessage = "Installe une seule fois les langues anglais → français demandées par iOS."
            case .installed:
                translationSetupMessage = "Pack anglais → français déjà installé."
            @unknown default:
                translationSetupMessage = "Vérification des langues anglaise et française…"
            }
            try await session.prepareTranslation()
            guard isActive, sessionToken == token, !Task.isCancelled else { return }
            var installed = false
            for _ in 0..<20 {
                let current = await availability.status(from: source, to: target)
                guard isActive, sessionToken == token, !Task.isCancelled else { return }
                if current == .installed {
                    installed = true
                    break
                }
                translationSetupMessage = "Téléchargement initial du pack anglais → français…"
                try await Task.sleep(nanoseconds: 1_500_000_000)
            }
            guard installed else {
                throw NSError(domain: "SarahTranslateLive", code: 4,
                    userInfo: [NSLocalizedDescriptionKey: "Pack anglais → français non installé. Une connexion initiale est nécessaire."])
            }
            nativeEnglishToFrenchTranslator = { text in
                let result = try await session.translate(text)
                return result.targetText
            }
            activateEnglishPivotIfReady(token: token)
            while !Task.isCancelled && isActive && sessionToken == token,
                  needsEnglishPivotTranslation {
                do {
                    try await Task.sleep(nanoseconds: 500_000_000)
                } catch { break }
            }
        } catch {
            guard isActive, sessionToken == token else { return }
            translationSetupMessage = "Relais anglais → français : \(error.localizedDescription)"
            errorMessage = translationSetupMessage
        }
        guard sessionToken == token else { return }
        nativeEnglishToFrenchTranslator = nil
        isSystemTranslationReady = false
        isUsingEnglishPivot = false
        whisper.liveDualDecodeEnglish = false
    }
    #endif

    private func translateNext(token: UUID) {
        guard isActive, sessionToken == token, !translationBusy, !incoming.isEmpty else { return }

        if shouldAttemptSystemTranslation && customTranslationServerURL.isEmpty
            && !isUsingLocalQwen {
            if needsEnglishPivotTranslation && !isUsingEnglishPivot {
                // Wait for the English→French pack rather than sending Hebrew
                // to a demonstrably unsupported local translation backend.
                updateStatus()
                return
            }
            if !needsEnglishPivotTranslation && nativeTranslator == nil
                && !nativeTranslationUnavailable {
                if #available(iOS 18.0, *) {
                    preparingSystemTranslation = true
                    updateStatus()
                    return
                }
            }
        }

        translationBusy = true
        isTranslating = true
        let fragment = incoming.removeFirst()
        waitingTranslations = incoming.count

        let native: ((String) async throws -> String)?
        if fragment.fromEnglishPivot {
            native = nativeEnglishToFrenchTranslator
        } else if shouldAttemptSystemTranslation {
            native = nativeTranslator
        } else {
            native = nil
        }

        if isUsingLocalQwen && !fragment.fromEnglishPivot {
            TranslateLiveTranslationBackend.translateWithLocalQwen(
                text: fragment.input,
                from: TranslateLiveLanguages.engineCode(for: sourceLanguage),
                to: TranslateLiveLanguages.engineCode(for: targetLanguage)
            ) { [weak self] outcome in
                DispatchQueue.main.async {
                    self?.finishTranslation(outcome, original: fragment.source, token: token)
                }
            }
            updateStatus()
            return
        }

        if let native {
            Task { [weak self] in
                guard let self, self.isActive, self.sessionToken == token else { return }
                do {
                    let result = try await native(fragment.input)
                    self.finishTranslation(.translated(result), original: fragment.source, token: token)
                } catch {
                    guard self.isActive, self.sessionToken == token else { return }
                    if fragment.fromEnglishPivot {
                        self.finishTranslation(
                            .unavailable("Traduction anglais → français interrompue : \(error.localizedDescription)"),
                            original: fragment.source, token: token
                        )
                    } else if self.shouldAttemptSystemTranslation
                                && self.customTranslationServerURL.isEmpty {
                        // Switching engines is recoverable, not a user-facing
                        // translation failure. Keep the status focused on the
                        // upcoming Whisper→English→French attempt.
                        self.translationBusy = false
                        self.isTranslating = false
                        self.requestEnglishPivot(token: token)
                        self.updateStatus()
                    } else {
                        self.finishTranslation(
                            .unavailable("Traduction locale impossible : \(error.localizedDescription)"),
                            original: fragment.source, token: token
                        )
                    }
                }
            }
            return
        }

        TranslateLiveTranslationBackend.translate(
            text: fragment.input,
            from: fragment.fromEnglishPivot ? "en" : TranslateLiveLanguages.engineCode(for: sourceLanguage),
            to: TranslateLiveLanguages.engineCode(for: targetLanguage),
            serverURL: customTranslationServerURL
        ) { [weak self] outcome in
            DispatchQueue.main.async {
                self?.finishTranslation(outcome, original: fragment.source, token: token)
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
        // A real model can still hallucinate a repeated stock sentence.
        // Do not print/speak it as if it were the TV presenter's words.
        let phrases = result.lowercased()
            .split(whereSeparator: { ".!?;".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)) }
            .filter { !$0.isEmpty }
        if phrases.count >= 2 && Set(phrases).count == 1 {
            errorMessage = "Réponse française répétitive ignorée : traduction insuffisamment fiable."
            return
        }
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

    private func scheduleMicrophoneRecovery(token: UUID) {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard let self, self.isActive, self.sessionToken == token else { return }
            self.whisper.recoverLiveMicrophoneIfNeeded()
            self.isListening = self.whisper.isRecording
            self.updateStatus()
        }
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
        } else if needsEnglishPivotTranslation && !isUsingEnglishPivot {
            status = "⌛ Chargement du traducteur anglais → français…"
        } else if preparingSystemTranslation {
            status = "⌛ Préparation des modèles de traduction iOS…"
        } else if translationBusy {
            status = "🎙️ Écoute continue, traduction en cours…"
        } else {
            status = "🎙️ Interprétation en direct : écoute continue"
        }
    }
}
