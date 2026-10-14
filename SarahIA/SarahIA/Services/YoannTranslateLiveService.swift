import Foundation
import SwiftUI
import AVFoundation
import UIKit
import Combine
#if canImport(Translation)
import Translation
#endif

/// Live interpreter for external speech (TV, video, person) heard through
/// the iPhone microphone.
///
/// Pipeline:
///   microphone → Whisper (on device) → Apple Translation (on device) → subtitles
///
/// * English → French: Whisper transcribes English, Apple translates EN→FR.
/// * Hebrew → French: if iOS offers a Hebrew→French pack it is used directly;
///   otherwise Whisper translates the Hebrew speech to English itself and
///   Apple translates EN→FR. No tiny LLM guesses the meaning any more.
///
/// The default output is subtitles only, so the phone can sit in front of
/// the TV without headphones and without hearing itself.
@available(iOS 16.2, *)
@MainActor
public final class YoannTranslateLiveService: ObservableObject {
    public typealias Language = TranslateLiveLanguages.Language

    public struct Phrase: Identifiable, Equatable {
        public let id = UUID()
        public let source: String
        public let translation: String
    }

    /// How a heard sentence becomes a translation.
    public enum Engine: Equatable {
        case none
        /// Whisper transcribes the source, Apple Translation translates it.
        case appleDirect
        /// Whisper translates the speech to English, Apple translates English → target.
        case whisperEnglishThenApple
        /// Whisper translates the speech straight to English (target is English).
        case whisperToEnglish
        /// User-owned LibreTranslate-compatible server set in the settings.
        case server
    }

    /// Language pair handed to the SwiftUI `translationTask` host.
    public struct ApplePair: Equatable {
        public let source: String
        public let target: String
        public var id: String { source + "-" + target }
    }

    private struct Pending {
        let source: String
        let input: String
        let capturedAt = Date()
    }

    public static func commandPair(_ text: String) -> (from: String, to: String)? {
        TranslateLiveLanguages.pairFromCommand(text)
    }

    @Published public private(set) var isActive = false
    @Published public private(set) var isListening = false
    @Published public private(set) var isTranslating = false
    @Published public private(set) var isPlayingAudio = false
    @Published public private(set) var status = "Prêt à écouter la télévision ou une personne."
    /// Last recognized words (source language, or Whisper's English when relaying).
    @Published public private(set) var lastSource = ""
    @Published public private(set) var lastTranslation = ""
    @Published public private(set) var history: [Phrase] = []
    @Published public private(set) var errorMessage: String?
    /// Non-blocking information (noise ignored, catching up with live…).
    @Published public private(set) var hint: String?
    @Published public private(set) var headphoneConnected = false
    @Published public private(set) var audioOutputDescription = "Sortie audio : vérification…"
    @Published public private(set) var audioInputDescription = "Microphone : vérification…"
    @Published public private(set) var audioRouteWarning: String?
    @Published public private(set) var microphoneLevel: Float = 0
    @Published public private(set) var engine: Engine = .none
    @Published public private(set) var applePair: ApplePair?
    @Published public private(set) var isEngineReady = false
    @Published public private(set) var engineDescription = "Choix du moteur de traduction…"

    // Names used by the Translate Live screen.
    public var translationSetupMessage: String { engineDescription }
    public var isSystemTranslationReady: Bool { isEngineReady }
    public var waitingTranslations: Int { pending.count }
    /// Whisper chunks are committed directly; there is no provisional text.
    public var provisionalSource: String { "" }

    public private(set) var outputMode: AudioSessionManager.InterpreterOutputMode = .subtitles
    public private(set) var sourceLanguage = "he"
    public private(set) var targetLanguage = "fr"

    /// True when the lower pane shows Whisper's English relay instead of the
    /// original words (Hebrew without an Apple Hebrew pack).
    public var showsEnglishRelay: Bool { engine == .whisperEnglishThenApple }

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
    private var appleTranslator: ((String) async throws -> String)?

    private var pending: [Pending] = []
    private var speechQueue: [String] = []
    private var isSpeaking = false
    private var lastChunk = ""
    private var lastChunkAt = Date.distantPast
    private var routeObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var micLevelSubscription: AnyCancellable?

    public init() {}

    // MARK: - Start / stop

    public func start(
        from source: String, to target: String, serverURL: String = "",
        outputMode: AudioSessionManager.InterpreterOutputMode = .subtitles
    ) {
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
        self.outputMode = outputMode
        customTranslationServerURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        errorMessage = nil
        hint = nil
        lastSource = ""
        lastTranslation = ""
        history.removeAll()
        pending.removeAll()
        speechQueue.removeAll()
        isSpeaking = false
        isTranslating = false
        isPlayingAudio = false
        lastChunk = ""
        lastChunkAt = .distantPast
        appleTranslator = nil
        applePair = nil
        engine = .none
        isEngineReady = false
        engineDescription = "Choix du moteur de traduction…"
        sessionToken = UUID()
        isActive = true
        let token = sessionToken

        // The interpreter owns the microphone; regular chat voice must stop.
        WhisperSpeechRecognizer.shared.stopListening()
        AgentVoiceManager.shared.stop()
        AudioSessionManager.shared.beginContinuousInterpreterSession(outputMode: outputMode)

        previousWhisperTranslation = whisper.translateSpeechToEnglish
        previousWhisperLanguage = whisper.preferredLanguageCode
        whisper.liveDualDecodeEnglish = false

        micLevelSubscription = whisper.$micEnergyLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.microphoneLevel = value
            }

        installObservers(token: token)
        if speaksAloud {
            installVoiceCallbacks(token: token)
            neural.prepareForVoiceConversation()
        }
        updateAudioRoute()
        status = "Choix du moteur de traduction…"
        chooseEngine(token: token)
    }

    public func stop() {
        sessionToken = UUID()
        guard isActive else { return }
        isActive = false
        isListening = false
        isTranslating = false
        isPlayingAudio = false
        isSpeaking = false
        pending.removeAll()
        speechQueue.removeAll()
        appleTranslator = nil
        applePair = nil
        engine = .none
        isEngineReady = false
        micLevelSubscription?.cancel()
        micLevelSubscription = nil
        microphoneLevel = 0

        if let routeObserver {
            NotificationCenter.default.removeObserver(routeObserver)
            self.routeObserver = nil
        }
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
            self.interruptionObserver = nil
        }
        // Restore listeners BEFORE canceling playback so an old session
        // cannot receive a synthetic "speech finished" event.
        if previousPlaybackFinished != nil || previousPlaybackStarted != nil
            || previousGenerationStarted != nil || previousPlaybackError != nil {
            neural.onPlaybackFinished = previousPlaybackFinished
            neural.onPlaybackStarted = previousPlaybackStarted
            neural.onGenerationStarted = previousGenerationStarted
            neural.onPlaybackError = previousPlaybackError
        }
        previousPlaybackFinished = nil
        previousPlaybackStarted = nil
        previousGenerationStarted = nil
        previousPlaybackError = nil
        neural.stop()
        whisper.stopLiveInterpretation()
        whisper.translateSpeechToEnglish = previousWhisperTranslation
        whisper.preferredLanguageCode = previousWhisperLanguage
        AudioSessionManager.shared.endContinuousVoiceSession()
        status = "Traduction arrêtée."
    }

    private var speaksAloud: Bool {
        outputMode != .subtitles
            && TranslateLiveLanguages.spokenOutputCodes.contains(
                TranslateLiveLanguages.engineCode(for: targetLanguage))
    }

    // MARK: - Engine selection

    private func chooseEngine(token: UUID) {
        let source = TranslateLiveLanguages.engineCode(for: sourceLanguage)
        let target = TranslateLiveLanguages.engineCode(for: targetLanguage)

        if !customTranslationServerURL.isEmpty,
           TranslateLiveTranslationBackend.validatedURL(customTranslationServerURL) != nil {
            activate(.server, pair: nil, whisperTranslates: false, token: token)
            return
        }
        if target == "en" && source != "en" {
            activate(.whisperToEnglish, pair: nil, whisperTranslates: true, token: token)
            return
        }

        #if canImport(Translation)
        if #available(iOS 18.0, *) {
            Task { [weak self] in
                let availability = LanguageAvailability()
                let targetLocale = Locale.Language(identifier: target)
                var direct: LanguageAvailability.Status = .unsupported
                if source != "auto" {
                    direct = await availability.status(
                        from: Locale.Language(identifier: source), to: targetLocale)
                }
                let relay = await availability.status(
                    from: Locale.Language(identifier: "en"), to: targetLocale)
                guard let self, self.isActive, self.sessionToken == token else { return }
                if direct != .unsupported {
                    self.activate(.appleDirect, pair: ApplePair(source: source, target: target),
                                  whisperTranslates: false, token: token)
                } else if relay != .unsupported && source != "en" {
                    self.activate(.whisperEnglishThenApple,
                                  pair: ApplePair(source: "en", target: target),
                                  whisperTranslates: true, token: token)
                } else {
                    self.fail("La traduction \(TranslateLiveLanguages.label(for: self.sourceLanguage)) → \(TranslateLiveLanguages.label(for: self.targetLanguage)) n'est pas disponible hors ligne sur cet iPhone.")
                }
            }
            return
        }
        #endif
        fail("La traduction hors ligne d'Apple nécessite iOS 18 ou plus récent.")
    }

    private func activate(_ engine: Engine, pair: ApplePair?, whisperTranslates: Bool, token: UUID) {
        guard isActive, sessionToken == token else { return }
        self.engine = engine
        applePair = pair
        let sourceLabel = TranslateLiveLanguages.label(for: sourceLanguage)
        let targetLabel = TranslateLiveLanguages.label(for: targetLanguage)
        switch engine {
        case .appleDirect:
            engineDescription = "Whisper (\(sourceLabel)) → Traduire d'Apple → \(targetLabel), sur l'iPhone."
        case .whisperEnglishThenApple:
            engineDescription = "Whisper comprend le \(sourceLabel.lowercased()) et le rend en anglais, puis Traduire d'Apple → \(targetLabel). Tout reste sur l'iPhone."
        case .whisperToEnglish:
            engineDescription = "Whisper traduit directement vers l'anglais, sur l'iPhone."
            isEngineReady = true
        case .server:
            engineDescription = "Whisper sur l'iPhone, traduction par ton serveur personnel."
            isEngineReady = true
        case .none:
            break
        }

        // Relay mode: Whisper decodes the SAME audio twice — once in the
        // source language (Hebrew script, shown in the lower pane) and once
        // in English (fed to Apple Translation for the French upper pane).
        // Before, Whisper only produced English, so the lower pane showed
        // Latin "Shalom, Manishem…" instead of the Hebrew that was spoken.
        let relay = engine == .whisperEnglishThenApple
        whisper.translateSpeechToEnglish = relay ? false : whisperTranslates
        whisper.liveDualDecodeEnglish = relay
        whisper.preferredLanguageCode = sourceLanguage == "auto"
            ? nil : TranslateLiveLanguages.engineCode(for: sourceLanguage)

        whisper.onLiveInterpretationChunk = { [weak self] chunk, _ in
            guard let self, self.isActive, self.sessionToken == token else { return }
            self.receive(chunk: chunk, token: token)
        }
        if relay {
            whisper.onLiveEnglishPivotChunk = { [weak self] heard, english, _ in
                guard let self, self.isActive, self.sessionToken == token else { return }
                self.receiveRelay(heard: heard, english: english, token: token)
            }
        } else {
            whisper.onLiveEnglishPivotChunk = nil
        }
        whisper.onLiveInterpretationError = { [weak self] message in
            guard let self, self.isActive, self.sessionToken == token else { return }
            // Noise/music rejections and catch-up notices are normal on TV.
            if message.hasPrefix("Whisper : aucune parole fiable")
                || message.hasPrefix("Le direct est plus rapide") {
                self.hint = message.hasPrefix("Le direct")
                    ? "Le direct va plus vite que l'iPhone : quelques mots ont été sautés."
                    : "Musique ou bruit ignoré."
                return
            }
            self.errorMessage = message
            self.updateStatus()
        }
        whisper.onLiveMicrophoneChanged = { [weak self] listening in
            guard let self, self.isActive, self.sessionToken == token else { return }
            self.isListening = listening
            self.updateStatus()
        }
        status = "Chargement de Whisper…"
        whisper.startLiveInterpretation()
        updateStatus()
    }

    private func fail(_ message: String) {
        errorMessage = message
        engineDescription = message
        updateStatus()
    }

    // MARK: - Apple Translation (installed language packs, offline)

    #if canImport(Translation)
    /// Called by the hidden `translationTask` host while the screen is open.
    /// The session is only valid inside that task, so this function keeps
    /// running until the interpreter stops or the pair changes.
    @available(iOS 18.0, *)
    public func attach(_ session: TranslationSession, pair: ApplePair) async {
        let token = sessionToken
        guard isActive, applePair == pair else { return }
        engineDescription = "Préparation de Traduire (\(pair.source) → \(pair.target))…"
        do {
            // Shows Apple's one-time download sheet when the pack is missing.
            try await session.prepareTranslation()
        } catch {
            guard isActive, sessionToken == token else { return }
            fail("Langue non téléchargée pour Traduire. Ouvre Réglages › Apps › Traduire › Langues téléchargées, installe anglais et français, puis relance. (\(error.localizedDescription))")
            return
        }
        guard isActive, sessionToken == token, applePair == pair else { return }
        appleTranslator = { text in
            try await session.translate(text).targetText
        }
        // The "Préparation de Traduire…" line used to stay on screen forever.
        let sourceLabel = TranslateLiveLanguages.label(for: sourceLanguage)
        let targetLabel = TranslateLiveLanguages.label(for: targetLanguage)
        engineDescription = engine == .whisperEnglishThenApple
            ? "Prêt : \(sourceLabel.lowercased()) écrit en bas, \(targetLabel.lowercased()) en haut. Tout reste sur l'iPhone."
            : "Prêt : traduction \(sourceLabel.lowercased()) → \(targetLabel.lowercased()) sur l'iPhone."
        isEngineReady = true
        errorMessage = nil
        updateStatus()
        translateNext()

        while !Task.isCancelled && isActive && sessionToken == token && applePair == pair {
            try? await Task.sleep(nanoseconds: 400_000_000)
        }
        if sessionToken == token {
            appleTranslator = nil
            isEngineReady = false
        }
    }
    #endif

    // MARK: - Recognized speech

    private func receive(chunk: String, token: UUID) {
        guard isActive, sessionToken == token else { return }
        let text = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if TranslateLiveContextBuffer.isUnreliableTranscript(text) {
            hint = "Musique ou bruit ignoré."
            return
        }
        // Whisper sometimes returns the exact same clause for two windows.
        if text == lastChunk && Date().timeIntervalSince(lastChunkAt) < 8 {
            return
        }
        // Whisper locked to Hebrew can still print Latin words on music.
        if engine == .appleDirect || engine == .server,
           TranslateLiveLanguages.engineCode(for: sourceLanguage) == "he",
           !TranslateLiveContextBuffer.isMostlyHebrew(text) {
            hint = "Passage non reconnu comme de l'hébreu, ignoré."
            return
        }
        if engine == .whisperEnglishThenApple || engine == .whisperToEnglish,
           TranslateLiveContextBuffer.isSuspiciousEnglishPivot(text, hebrewSource: "") {
            hint = "Passage incompréhensible ignoré."
            return
        }
        lastChunk = text
        lastChunkAt = Date()
        errorMessage = nil
        hint = nil

        switch engine {
        case .whisperToEnglish:
            lastSource = ""
            appendTranslated(text, source: "")
        case .appleDirect, .whisperEnglishThenApple, .server:
            lastSource = text
            pending.append(Pending(source: text, input: text))
            // A live broadcast never waits: keep only the freshest phrases.
            if pending.count > 3 {
                pending.removeFirst(pending.count - 3)
                hint = "Rattrapage du direct : phrases les plus récentes en priorité."
            }
            translateNext()
        case .none:
            break
        }
        updateStatus()
    }

    /// Relay mode: `heard` is Whisper's transcription in the source language
    /// (Hebrew script), `english` its English translation of the same audio.
    private func receiveRelay(heard: String, english: String, token: UUID) {
        guard isActive, sessionToken == token else { return }
        let original = heard.trimmingCharacters(in: .whitespacesAndNewlines)
        let relay = english.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !original.isEmpty else { return }
        if TranslateLiveContextBuffer.isUnreliableTranscript(original) {
            hint = "Musique ou bruit ignoré."
            return
        }
        let sourceIsHebrew = TranslateLiveLanguages.engineCode(for: sourceLanguage) == "he"
        if sourceIsHebrew && !TranslateLiveContextBuffer.isMostlyHebrew(original) {
            hint = "Passage non reconnu comme de l'hébreu, ignoré."
            return
        }
        if original == lastChunk && Date().timeIntervalSince(lastChunkAt) < 8 {
            return
        }
        lastChunk = original
        lastChunkAt = Date()
        errorMessage = nil
        hint = nil
        // Lower pane: the words exactly as spoken, in Hebrew letters.
        lastSource = original

        // Everyday expressions: Whisper's English for them is unreliable
        // (it spells them phonetically), so use a verified phrasebook.
        if sourceIsHebrew, TranslateLiveLanguages.engineCode(for: targetLanguage) == "fr",
           let french = HebrewFrenchPhrasebook.translate(original) {
            appendTranslated(french, source: original)
            updateStatus()
            return
        }

        let cleanedRelay = HebrewFrenchPhrasebook.fixTransliteratedEnglish(relay)
        guard !cleanedRelay.isEmpty,
              !TranslateLiveContextBuffer.isSuspiciousEnglishPivot(cleanedRelay, hebrewSource: original) else {
            hint = "Phrase pas assez claire pour être traduite, j'écoute la suite."
            updateStatus()
            return
        }
        pending.append(Pending(source: original, input: cleanedRelay))
        if pending.count > 3 {
            pending.removeFirst(pending.count - 3)
            hint = "Rattrapage du direct : phrases les plus récentes en priorité."
        }
        translateNext()
        updateStatus()
    }

    private func translateNext() {
        guard isActive, !isTranslating, !pending.isEmpty else { return }
        let token = sessionToken

        switch engine {
        case .appleDirect, .whisperEnglishThenApple:
            guard let translator = appleTranslator else {
                updateStatus() // Waiting for the language pack.
                return
            }
            let item = pending.removeFirst()
            isTranslating = true
            updateStatus()
            Task { [weak self] in
                let outcome: TranslateLiveTranslationBackend.Outcome
                do {
                    outcome = .translated(try await translator(item.input))
                } catch {
                    outcome = .unavailable("Traduire : " + error.localizedDescription)
                }
                self?.finish(outcome, item: item, token: token)
            }
        case .server:
            let item = pending.removeFirst()
            isTranslating = true
            updateStatus()
            TranslateLiveTranslationBackend.translate(
                text: item.input,
                from: TranslateLiveLanguages.engineCode(for: sourceLanguage),
                to: TranslateLiveLanguages.engineCode(for: targetLanguage),
                serverURL: customTranslationServerURL
            ) { [weak self] outcome in
                Task { @MainActor in
                    self?.finish(outcome, item: item, token: token)
                }
            }
        case .whisperToEnglish, .none:
            pending.removeAll()
        }
    }

    private func finish(
        _ outcome: TranslateLiveTranslationBackend.Outcome, item: Pending, token: UUID
    ) {
        guard isActive, sessionToken == token else { return }
        isTranslating = false
        switch outcome {
        case .translated(let output):
            appendTranslated(output, source: item.source)
        case .unavailable(let reason):
            errorMessage = reason
        }
        translateNext()
        updateStatus()
    }

    private func appendTranslated(_ text: String, source: String) {
        guard isActive else { return }
        let result = SarahResponseCleaner.clean(text)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty,
              result.unicodeScalars.contains(where: { CharacterSet.letters.contains($0) }),
              !TranslateLiveContextBuffer.isUnreliableTranscript(result) else {
            return
        }
        lastTranslation = result
        history.insert(Phrase(source: source, translation: result), at: 0)
        if history.count > 80 { history.removeLast(history.count - 80) }

        guard speaksAloud else { return }
        // Queue the translation: let Yohan finish current phrase before starting next.
        // Prevents interruption when speech synthesis is still playing.
        if !isSpeaking {
            speechQueue = [result]
        } else {
            // Yohan is still speaking: queue the new result to play after current
            speechQueue.append(result)
            // Keep only 2 phrases in queue: current + next (discard older)
            if speechQueue.count > 2 {
                speechQueue.removeFirst(speechQueue.count - 2)
            }
        }
        if !isSpeaking {
            speakNext(token: sessionToken)
        }
    }

    // MARK: - Optional spoken output (headphones / speaker modes)

    private func installVoiceCallbacks(token: UUID) {
        previousPlaybackFinished = neural.onPlaybackFinished
        previousPlaybackStarted = neural.onPlaybackStarted
        previousGenerationStarted = neural.onGenerationStarted
        previousPlaybackError = neural.onPlaybackError
        neural.onGenerationStarted = { [weak self] in
            guard let self, self.isActive, self.sessionToken == token else { return }
            self.updateStatus()
        }
        neural.onPlaybackStarted = { [weak self] in
            guard let self, self.isActive, self.sessionToken == token else { return }
            self.isPlayingAudio = true
            self.updateStatus()
        }
        neural.onPlaybackFinished = { [weak self] in
            guard let self, self.sessionToken == token else { return }
            self.isSpeaking = false
            self.isPlayingAudio = false
            self.speakNext(token: token)
        }
        neural.onPlaybackError = { [weak self] message in
            guard let self, self.sessionToken == token else { return }
            self.hint = "Voix indisponible : " + message
        }
    }

    private func speakNext(token: UUID) {
        guard isActive, sessionToken == token, !isSpeaking, !speechQueue.isEmpty else {
            updateStatus()
            return
        }
        let phrase = speechQueue.removeFirst()
        isSpeaking = true
        neural.speak(
            text: phrase, for: .yohan,
            language: TranslateLiveLanguages.engineCode(for: targetLanguage),
            qualitySteps: 5,
            dedicatedInterpreter: true
        )
        updateStatus()
    }

    // MARK: - Audio route

    private func installObservers(token: UUID) {
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isActive, self.sessionToken == token else { return }
                self.updateAudioRoute()
                self.scheduleMicrophoneRecovery(token: token)
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
                guard let self, self.isActive, self.sessionToken == token else { return }
                self.scheduleMicrophoneRecovery(token: token)
            }
        }
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
        let route = AVAudioSession.sharedInstance().currentRoute
        let types = route.outputs.map(\.portType)
        headphoneConnected = types.contains(.headphones)
            || types.contains(.bluetoothHFP)
            || types.contains(.bluetoothA2DP)
            || types.contains(.bluetoothLE)

        if types.contains(.bluetoothA2DP) || types.contains(.bluetoothHFP)
            || types.contains(.bluetoothLE) {
            audioOutputDescription = "Sortie : écouteurs Bluetooth"
        } else if types.contains(.headphones) {
            audioOutputDescription = "Sortie : écouteurs filaires"
        } else {
            audioOutputDescription = "Sortie : haut-parleur iPhone"
        }

        let inputs = route.inputs.map(\.portType)
        if inputs.contains(.builtInMic) {
            audioInputDescription = "Micro de l'iPhone"
        } else if inputs.contains(.bluetoothHFP) {
            audioInputDescription = "Micro des écouteurs Bluetooth"
        } else if inputs.contains(.headsetMic) {
            audioInputDescription = "Micro du casque filaire"
        } else {
            audioInputDescription = "Micro inconnu"
        }

        switch outputMode {
        case .subtitles:
            audioRouteWarning = inputs.contains(.builtInMic) || inputs.isEmpty
                ? nil
                : "iOS utilise le micro des écouteurs : déconnecte-les pour capter la télé."
        case .headphones:
            audioRouteWarning = headphoneConnected
                ? nil
                : "Aucun écouteur détecté : la voix risque d'être réentendue par le micro."
        case .speaker:
            audioRouteWarning = "Voix sur le haut-parleur : le micro peut réentendre la traduction."
        }
        updateStatus()
    }

    private func updateStatus() {
        guard isActive else { return }
        if engine == .none {
            status = errorMessage == nil ? "Choix du moteur de traduction…" : "Traduction indisponible"
        } else if !isListening {
            status = whisper.isModelLoading ? "Chargement de Whisper…" : "Ouverture du micro…"
        } else if !isEngineReady {
            status = "Préparation de la traduction…"
        } else if isPlayingAudio {
            status = "Lecture de la traduction…"
        } else if isTranslating {
            status = "Traduction…"
        } else {
            status = "J'écoute"
        }
    }
}

// MARK: - Everyday Hebrew → French phrasebook

/// Verified translations for everyday spoken Hebrew. Whisper's English relay
/// tends to spell these phonetically ("Shalom, Manishem, Kol Mesehdeh"),
/// which Apple then leaves untranslated. When EVERY part of a heard sentence
/// is a known expression, the French comes from this table instead.
enum HebrewFrenchPhrasebook {
    private struct Entry {
        let french: String
        let question: Bool
    }

    private static let table: [String: Entry] = {
        let raw: [(String, String, Bool)] = [
            ("שלום", "bonjour", false),
            ("שלום לכולם", "bonjour à tous", false),
            ("היי", "salut", false),
            ("אהלן", "salut", false),
            ("בוקר טוב", "bonjour", false),
            ("צהריים טובים", "bon après-midi", false),
            ("ערב טוב", "bonsoir", false),
            ("לילה טוב", "bonne nuit", false),
            ("מה נשמע", "comment ça va", true),
            ("מה שלומך", "comment vas-tu", true),
            ("מה שלומכם", "comment allez-vous", true),
            ("מה קורה", "quoi de neuf", true),
            ("מה המצב", "ça va", true),
            ("מה איתך", "et toi, ça va", true),
            ("הכל בסדר", "tout va bien", false),
            ("הכול בסדר", "tout va bien", false),
            ("כל בסדר", "tout va bien", false),
            ("בסדר", "d'accord", false),
            ("הכל טוב", "tout va bien", false),
            ("הכול טוב", "tout va bien", false),
            ("אני בסדר", "je vais bien", false),
            ("טוב", "bien", false),
            ("תודה", "merci", false),
            ("תודה רבה", "merci beaucoup", false),
            ("בבקשה", "s'il te plaît", false),
            ("סליחה", "pardon", false),
            ("כן", "oui", false),
            ("לא", "non", false),
            ("להתראות", "au revoir", false),
            ("ביי", "au revoir", false),
            ("נעים מאוד", "enchanté", false),
            ("ברוך הבא", "bienvenue", false),
            ("ברוכים הבאים", "bienvenue", false),
            ("מזל טוב", "félicitations", false),
            ("בהצלחה", "bonne chance", false),
            ("שבת שלום", "chabbat chalom", false),
            ("חג שמח", "joyeuses fêtes", false),
            ("ברוך השם", "Dieu merci", false),
            ("תודה לאל", "Dieu merci", false),
            ("בתיאבון", "bon appétit", false),
            ("לחיים", "santé", false),
            ("אין בעיה", "pas de problème", false),
            ("יאללה", "allez", false),
            ("סבבה", "ça marche", false),
            ("אחלה", "super", false),
            ("אמא", "maman", false),
            ("אבא", "papa", false),
            ("אני אוהב אותך", "je t'aime", false),
            ("אני אוהבת אותך", "je t'aime", false),
            ("איפה אתה", "où es-tu", true),
            ("איפה את", "où es-tu", true),
            ("מה אתה עושה", "qu'est-ce que tu fais", true),
            ("מה את עושה", "qu'est-ce que tu fais", true),
        ]
        var map: [String: Entry] = [:]
        for (hebrew, french, question) in raw {
            map[normalize(hebrew)] = Entry(french: french, question: question)
        }
        return map
    }()

    private static let maxWords = 4

    /// Removes vowel points/cantillation and punctuation, collapses spaces.
    static func normalize(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            let v = scalar.value
            if (0x0591...0x05C7).contains(v) && !(0x05D0...0x05EA).contains(v) {
                continue // niqqud, cantillation, maqaf, geresh…
            }
            scalars.append(scalar)
        }
        return String(scalars)
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// French translation if the whole Hebrew sentence is made of known
    /// expressions, otherwise nil (the normal translator is used).
    static func translate(_ hebrew: String) -> String? {
        let words = normalize(hebrew).split(separator: " ").map(String.init)
        guard !words.isEmpty, words.count <= 16 else { return nil }
        var parts: [Entry] = []
        var index = 0
        while index < words.count {
            var matched = false
            for length in stride(from: min(maxWords, words.count - index), through: 1, by: -1) {
                let key = words[index..<(index + length)].joined(separator: " ")
                if let entry = table[key] {
                    parts.append(entry)
                    index += length
                    matched = true
                    break
                }
            }
            if !matched { return nil }
        }
        return compose(parts)
    }

    private static func compose(_ parts: [Entry]) -> String {
        var output = ""
        var startOfSentence = true
        for (i, part) in parts.enumerated() {
            var piece = part.french
            if startOfSentence, let first = piece.first {
                piece = first.uppercased() + piece.dropFirst()
            }
            output += piece
            let isLast = i == parts.count - 1
            if part.question {
                output += " ?"
                startOfSentence = true
            } else if isLast {
                output += "."
                startOfSentence = true
            } else {
                output += ","
                startOfSentence = false
            }
            if !isLast { output += " " }
        }
        return output
    }

    /// Replaces common phonetic spellings that Whisper sometimes leaves in
    /// its English relay, so Apple Translation receives real English.
    static func fixTransliteratedEnglish(_ english: String) -> String {
        let replacements: [(String, String)] = [
            ("\\bshabb?at shalom\\b", "have a good Sabbath"),
            ("\\bma nishm[ae]\\w*\\b", "how are you"),
            ("\\bmanish\\w*\\b", "how are you"),
            ("\\bma kore\\b", "what's up"),
            ("\\b(ha)?kol b[ae]s[ae]der\\b", "everything is fine"),
            ("\\bkol m[ae]s[ae]h?d[ae]h?\\b", "everything is fine"),
            ("\\bb[ae]s[ae]der\\b", "okay"),
            ("\\btoda raba\\b", "thank you very much"),
            ("\\btodah? rabbah?\\b", "thank you very much"),
            ("\\btodah?\\b", "thank you"),
            ("\\bshalom\\b", "hello"),
            ("\\bb[ae]vakash?a\\b", "please"),
            ("\\bslich?a\\b", "sorry"),
            ("\\blehitraot\\b", "goodbye"),
            ("\\bmazal tov\\b", "congratulations"),
            ("\\bbaruch hashem\\b", "thank God"),
            ("\\byalla\\b", "come on"),
            ("\\bsababa\\b", "great"),
            ("\\bachla\\b", "great"),
        ]
        var text = english
        for (pattern, value) in replacements {
            text = text.replacingOccurrences(
                of: pattern, with: value,
                options: [.regularExpression, .caseInsensitive])
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
