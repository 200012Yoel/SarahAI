import Foundation
import AVFoundation
import QuartzCore
import Speech
#if canImport(whisper)
import whisper
#endif

/// Pipeline de traduction vocale en temps réel — fonctionne aussi bien avec que sans Internet.
///
/// Reconnaissance de la voix (choix automatique, réévalué à chaque phrase) :
/// - **Apple** (iOS) quand elle est disponible : avec Internet, ou sans si l'iPhone la gère hors ligne.
/// - **Whisper** sur l'iPhone (même moteur et même modèle que le mode vocal) dès qu'Apple n'est pas
///   disponible, par exemple hors ligne.
///
/// Déroulé :
/// 1. Pendant que la personne parle : sous-titres immédiats (texte reconnu + traduction rapide).
/// 2. À la première pause (~0,8 s) : la phrase est figée, traduite par le pack Google hors ligne
///    (gratuit, avec ou sans Internet), puis prononcée.
/// 3. Pendant que Sarah parle, le micro est ignoré : le téléphone ne retraduit jamais sa propre voix.
///    L'écoute reprend toute seule dès que la voix a fini.
public final class LiveSpeechTranslationPipeline: NSObject, SFSpeechRecognizerDelegate, AVSpeechSynthesizerDelegate {

    public static let shared = LiveSpeechTranslationPipeline()

    // Callbacks pour l'interface (toujours appelés sur le thread principal)
    public var onTranscriptItemUpdated: ((LiveTranscriptItem) -> Void)?
    public var onAudioEnergyLevel: ((Float) -> Void)?

    /// Moteur de reconnaissance actuellement utilisé (affichable dans l'interface).
    public enum RecognitionMode: String {
        case apple = "Apple"
        case whisper = "Whisper (hors ligne)"
        case unavailable = "Indisponible"
    }

    public private(set) var currentRecognitionMode: RecognitionMode = .unavailable

    // MARK: - Réglages de réactivité

    /// Silence après lequel la phrase est considérée comme terminée.
    private let endOfSentenceSilence: TimeInterval = 0.8
    /// Intervalle minimal entre deux traductions rapides des sous-titres.
    private let partialTranslationInterval: TimeInterval = 0.25
    /// Délai avant de réécouter après la fin de la voix (évite d'attraper la fin du son).
    private let resumeListeningDelay: TimeInterval = 0.25
    /// Fréquence max de mise à jour de l'animation du micro (~15 images/s).
    private let energyUpdateInterval: CFTimeInterval = 1.0 / 15.0

    // Whisper
    private let whisperSampleRate: Double = 16_000
    private let whisperVoiceThresholdDB: Float = -45
    private let whisperPartialInterval: TimeInterval = 1.0
    private let whisperMinimumSpeech: Double = 0.5
    private let whisperMaximumSegment: Double = 25
    private let whisperPreRoll: Double = 0.4

    // MARK: - Reconnaissance Apple

    private var localSpeechRecognizer: SFSpeechRecognizer?
    private var localRecognitionTask: SFSpeechRecognitionTask?

    // MARK: - État partagé avec le thread audio (protégé par `audioLock`)

    private let audioLock = NSLock()
    private var _mode: RecognitionMode = .unavailable
    private var _activeRequest: SFSpeechAudioBufferRecognitionRequest?
    private var _isMicSuspended = false
    private var _whisperSamples: [Float] = []
    private var _whisperHasSpeech = false
    private var _whisperLastVoice: CFTimeInterval = 0
    private var _whisperFinalizeRequested = false
    private var _converter: AVAudioConverter?
    private var _converterInputFormat: AVAudioFormat?
    private var lastEnergyUpdate: CFTimeInterval = 0

    // MARK: - Synthèse vocale

    private let speechSynthesizer = AVSpeechSynthesizer()

    // MARK: - État (thread principal uniquement)

    private var currentLanguagePair = LiveLanguagePair()
    private var isPipelineRunning = false
    private var pipelineEpoch = 0 // Invalidation des réponses d'une ancienne session
    /// Incrémenté à chaque nouvelle session : les résultats d'une ancienne session sont ignorés.
    private var recognitionGeneration = 0

    private var currentSegmentId = UUID().uuidString
    private var currentOriginalText = ""
    private var currentPartialTranslation = ""
    private var currentPartialAttribution: String?
    private var silenceTimer: Timer?

    private var isPartialTranslationInFlight = false
    private var pendingPartialText: String?
    private var lastPartialTranslationDate = Date.distantPast

    private var whisperPartialTimer: Timer?
    private var isWhisperPartialInFlight = false
    private var hasShownUnavailableNotice = false

    private override init() {
        super.init()
        speechSynthesizer.delegate = self
    }

    // MARK: - Démarrage / Arrêt

    public func startPipeline(with languagePair: LiveLanguagePair) {
        runOnMain { [weak self] in
            guard let self = self else { return }
            self.stopPipelineOnMain()
            self.currentLanguagePair = languagePair
            self.isPipelineRunning = true
            self.hasShownUnavailableNotice = false

            // Packs de traduction Google + modèle Whisper : prêts pour le hors ligne
            TranslationEngine.shared.prepareOfflinePacks(for: [languagePair.sourceLanguage, languagePair.targetLanguage])
            LiveWhisperTranscriber.shared.prepare()

            let localeId = self.localeIdentifier(for: languagePair.sourceLanguage)
            self.localSpeechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeId))
            self.localSpeechRecognizer?.delegate = self

            self.requestSpeechAuthorizationIfNeeded { authorized in
                guard self.isPipelineRunning else { return }
                if !authorized {
                    print("⚠️ [Traduction] Reconnaissance Apple non autorisée : Whisper uniquement")
                }
                self.startRecognitionSession()
            }
        }
    }

    public func updateLanguagePair(_ newPair: LiveLanguagePair) {
        runOnMain { [weak self] in
            guard let self = self else { return }
            let needsRestart = newPair.sourceLanguage != self.currentLanguagePair.sourceLanguage
            self.currentLanguagePair = newPair
            if needsRestart && self.isPipelineRunning {
                self.startPipeline(with: newPair)
            }
        }
    }

    public func stopPipeline() {
        runOnMain { [weak self] in
            self?.stopPipelineOnMain()
        }
    }

    private func stopPipelineOnMain() {
        pipelineEpoch += 1
        let wasRunning = isPipelineRunning
        isPipelineRunning = false
        silenceTimer?.invalidate()
        silenceTimer = nil
        pendingPartialText = nil
        isPartialTranslationInFlight = false

        endRecognitionSession()
        setMicSuspended(false)

        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        if wasRunning {
            LiveWhisperTranscriber.shared.release()
        }
    }

    // MARK: - Ingestion des buffers micro (thread audio)

    public func processMicrophoneBuffer(_ buffer: AVAudioPCMBuffer) {
        audioLock.lock()
        let mode = _mode
        let request = _activeRequest
        let suspended = _isMicSuspended
        audioLock.unlock()

        // Pendant que Sarah parle, on n'écoute pas : pas d'écho, pas de boucle.
        guard !suspended else { return }

        switch mode {
        case .apple:
            request?.append(buffer)
        case .whisper:
            appendToWhisper(buffer)
        case .unavailable:
            break
        }
        publishAudioEnergy(buffer: buffer)
    }

    private func publishAudioEnergy(buffer: AVAudioPCMBuffer) {
        let now = CACurrentMediaTime()
        guard now - lastEnergyUpdate >= energyUpdateInterval else { return }
        lastEnergyUpdate = now

        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        var sum: Float = 0.0
        for i in 0..<frameLength {
            let sample = channelData[i]
            sum += sample * sample
        }
        let rms = sqrtf(sum / Float(frameLength))
        let normalized = min(max(rms * 10.0, 0.0), 1.0)

        DispatchQueue.main.async { [weak self] in
            self?.onAudioEnergyLevel?(normalized)
        }
    }

    private func setMicSuspended(_ suspended: Bool) {
        audioLock.lock()
        _isMicSuspended = suspended
        audioLock.unlock()
        if suspended {
            onAudioEnergyLevel?(0)
        }
    }

    // MARK: - Choix du moteur de reconnaissance

    private func chooseRecognitionMode() -> RecognitionMode {
        let appleAuthorized = SFSpeechRecognizer.authorizationStatus() == .authorized
        let appleWorks: Bool = {
            guard appleAuthorized, let recognizer = localSpeechRecognizer, recognizer.isAvailable else { return false }
            return NetworkMonitor.shared.isOnline || recognizer.supportsOnDeviceRecognition
        }()
        if appleWorks { return .apple }
        if LiveWhisperTranscriber.isAvailable { return .whisper }
        return .unavailable
    }

    // MARK: - Session de reconnaissance

    private func startRecognitionSession() {
        guard isPipelineRunning else { return }

        endRecognitionSession()

        recognitionGeneration += 1
        currentSegmentId = UUID().uuidString
        currentOriginalText = ""
        currentPartialTranslation = ""
        currentPartialAttribution = nil
        pendingPartialText = nil

        let mode = chooseRecognitionMode()
        currentRecognitionMode = mode

        switch mode {
        case .apple:
            startAppleSession()
        case .whisper:
            startWhisperSession()
        case .unavailable:
            showUnavailableNoticeOnce()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.startRecognitionSession()
            }
        }
    }

    private func endRecognitionSession() {
        recognitionGeneration += 1

        audioLock.lock()
        let request = _activeRequest
        _activeRequest = nil
        _mode = .unavailable
        _whisperSamples.removeAll(keepingCapacity: true)
        _whisperHasSpeech = false
        _whisperFinalizeRequested = false
        audioLock.unlock()

        request?.endAudio()
        localRecognitionTask?.cancel()
        localRecognitionTask = nil

        whisperPartialTimer?.invalidate()
        whisperPartialTimer = nil
    }

    private func showUnavailableNoticeOnce() {
        guard !hasShownUnavailableNotice else { return }
        hasShownUnavailableNotice = true
        let message = "Reconnaissance vocale momentanément indisponible, nouvel essai…"
        publishItem(
            id: "sarah-notice-\(UUID().uuidString)",
            isSpeech: false,
            original: message,
            originalLanguage: "fr",
            translated: "Mode hors ligne",
            targetLanguage: "fr",
            isFinal: true
        )
    }

    // MARK: - Mode Apple

    private func startAppleSession() {
        guard let recognizer = localSpeechRecognizer else { return }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        if #available(iOS 16.0, *) {
            request.addsPunctuation = true
        }
        // Sur l'iPhone quand c'est possible (plus rapide, marche sans Internet)
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition

        let generation = recognitionGeneration

        audioLock.lock()
        _activeRequest = request
        _mode = .apple
        audioLock.unlock()

        localRecognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.handleAppleRecognition(result: result, error: error, generation: generation)
            }
        }
    }

    private func handleAppleRecognition(result: SFSpeechRecognitionResult?, error: Error?, generation: Int) {
        // Résultat d'une ancienne session : ignoré (c'est ce qui causait les répétitions)
        guard generation == recognitionGeneration, isPipelineRunning else { return }

        if let result = result {
            let transcription = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
            if !transcription.isEmpty && transcription != currentOriginalText {
                currentOriginalText = transcription
                showPartial(transcription)

                // Détection de fin de phrase par le silence
                silenceTimer?.invalidate()
                silenceTimer = Timer.scheduledTimer(withTimeInterval: endOfSentenceSilence, repeats: false) { [weak self] _ in
                    self?.finalizeAppleSegment()
                }
            }
            if result.isFinal {
                finalizeAppleSegment()
                return
            }
        }

        if error != nil {
            // Fin de session côté iOS (Internet coupé, limite de durée, silence prolongé…) :
            // on termine la phrase et on relance — le moteur est rechoisi (Whisper si plus d'Internet).
            if !currentOriginalText.isEmpty {
                finalizeAppleSegment()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    self?.startRecognitionSession()
                }
            }
        }
    }

    private func finalizeAppleSegment() {
        silenceTimer?.invalidate()
        silenceTimer = nil

        let text = currentOriginalText
        guard !text.isEmpty else { return }

        let segmentId = currentSegmentId
        let partial = currentPartialTranslation
        let partialAttribution = currentPartialAttribution
        let pair = currentLanguagePair
        let willSpeak = pair.isVoiceEnabled

        // On coupe la session : la phrase suivante repartira de zéro (plus de texte accumulé)
        endRecognitionSession()
        currentOriginalText = ""
        currentPartialTranslation = ""
        currentPartialAttribution = nil
        pendingPartialText = nil

        if willSpeak {
            // Micro coupé dès maintenant pour ne pas capter la voix de Sarah
            setMicSuspended(true)
        } else {
            startRecognitionSession()
        }

        translateAndSpeak(text: text, segmentId: segmentId, pair: pair, partial: partial, partialAttribution: partialAttribution, willSpeak: willSpeak)
    }

    // MARK: - Mode Whisper (hors ligne)

    private func startWhisperSession() {
        audioLock.lock()
        _mode = .whisper
        _whisperSamples.removeAll(keepingCapacity: true)
        _whisperHasSpeech = false
        _whisperFinalizeRequested = false
        audioLock.unlock()

        whisperPartialTimer = Timer.scheduledTimer(withTimeInterval: whisperPartialInterval, repeats: true) { [weak self] _ in
            self?.runWhisperPartial()
        }
    }

    /// Thread audio : conversion 16 kHz mono, détection de voix et de fin de phrase.
    private func appendToWhisper(_ buffer: AVAudioPCMBuffer) {
        guard let chunk = convertTo16kMono(buffer), !chunk.isEmpty else { return }

        let rms = sqrtf(chunk.reduce(Float(0)) { $0 + $1 * $1 } / Float(chunk.count))
        let db = 20 * log10f(max(rms, 0.000_001))
        let now = CACurrentMediaTime()

        var shouldFinalize = false

        audioLock.lock()
        if _mode == .whisper && !_whisperFinalizeRequested {
            _whisperSamples.append(contentsOf: chunk)

            if db >= whisperVoiceThresholdDB {
                _whisperHasSpeech = true
                _whisperLastVoice = now
            }

            let duration = Double(_whisperSamples.count) / whisperSampleRate
            if !_whisperHasSpeech {
                // Avant la parole : on ne garde qu'un court « pré-roll »
                let keep = Int(whisperPreRoll * whisperSampleRate)
                if _whisperSamples.count > keep {
                    _whisperSamples.removeFirst(_whisperSamples.count - keep)
                }
            } else if (duration >= whisperMinimumSpeech && now - _whisperLastVoice >= endOfSentenceSilence)
                        || duration >= whisperMaximumSegment {
                _whisperFinalizeRequested = true
                shouldFinalize = true
            }
        }
        audioLock.unlock()

        if shouldFinalize {
            DispatchQueue.main.async { [weak self] in
                self?.finalizeWhisperSegment()
            }
        }
    }

    private func convertTo16kMono(_ buffer: AVAudioPCMBuffer) -> [Float]? {
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: whisperSampleRate,
            channels: 1,
            interleaved: false
        ) else { return nil }

        audioLock.lock()
        if _converter == nil || _converterInputFormat != buffer.format {
            _converter = AVAudioConverter(from: buffer.format, to: targetFormat)
            _converterInputFormat = buffer.format
        }
        let converter = _converter
        audioLock.unlock()

        guard let converter = converter else { return nil }

        let ratio = whisperSampleRate / max(1, buffer.format.sampleRate)
        let capacity = AVAudioFrameCount(max(1, Int(Double(buffer.frameLength) * ratio) + 32))
        guard let converted = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return nil }

        var supplied = false
        var conversionError: NSError?
        let status = converter.convert(to: converted, error: &conversionError) { _, outStatus in
            if supplied {
                outStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            outStatus.pointee = .haveData
            return buffer
        }
        guard conversionError == nil, status != .error,
              let channel = converted.floatChannelData?[0], converted.frameLength > 0 else { return nil }
        return Array(UnsafeBufferPointer(start: channel, count: Int(converted.frameLength)))
    }

    /// Sous-titres partiels Whisper (environ une fois par seconde pendant que la personne parle).
    private func runWhisperPartial() {
        guard isPipelineRunning, !isWhisperPartialInFlight else { return }

        audioLock.lock()
        let isWhisper = _mode == .whisper
        let hasSpeech = _whisperHasSpeech
        let finalizing = _whisperFinalizeRequested
        let snapshot = _whisperSamples
        audioLock.unlock()

        guard isWhisper, hasSpeech, !finalizing,
              Double(snapshot.count) / whisperSampleRate >= whisperMinimumSpeech else { return }

        isWhisperPartialInFlight = true
        let generation = recognitionGeneration
        let segmentId = currentSegmentId
        let language = currentLanguagePair.sourceLanguage

        Task { [weak self] in
            let text = await LiveWhisperTranscriber.shared.transcribe(snapshot, language: language, skipIfBusy: true)
            await MainActor.run {
                guard let self = self else { return }
                self.isWhisperPartialInFlight = false
                guard let text = text,
                      generation == self.recognitionGeneration,
                      segmentId == self.currentSegmentId,
                      text != self.currentOriginalText else { return }
                self.currentOriginalText = text
                self.showPartial(text)
            }
        }
    }

    private func finalizeWhisperSegment() {
        guard isPipelineRunning else { return }

        audioLock.lock()
        guard _mode == .whisper else {
            audioLock.unlock()
            return
        }
        let samples = _whisperSamples
        _whisperSamples.removeAll(keepingCapacity: true)
        _whisperHasSpeech = false
        _whisperFinalizeRequested = false
        audioLock.unlock()

        let segmentId = currentSegmentId
        let partialText = currentOriginalText
        let partial = currentPartialTranslation
        let partialAttribution = currentPartialAttribution
        let pair = currentLanguagePair
        let willSpeak = pair.isVoiceEnabled

        // Nouveau segment pour la phrase suivante (l'écoute continue si Sarah ne parle pas)
        currentSegmentId = UUID().uuidString
        currentOriginalText = ""
        currentPartialTranslation = ""
        currentPartialAttribution = nil
        pendingPartialText = nil

        if willSpeak {
            setMicSuspended(true)
        }

        Task { [weak self] in
            let finalText = await LiveWhisperTranscriber.shared.transcribe(samples, language: pair.sourceLanguage)
            await MainActor.run {
                guard let self = self, self.isPipelineRunning else { return }
                let text = (finalText ?? partialText).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else {
                    if willSpeak { self.resumeListening() }
                    return
                }
                self.translateAndSpeak(text: text, segmentId: segmentId, pair: pair, partial: partial, partialAttribution: partialAttribution, willSpeak: willSpeak)
            }
        }
    }

    // MARK: - Sous-titres en direct (communs aux deux moteurs)

    private func showPartial(_ text: String) {
        // 1. Le texte original s'affiche tout de suite
        publishLocalItem(original: text, translated: currentPartialTranslation.isEmpty ? "…" : currentPartialTranslation, isFinal: false)

        // 2. Traduction rapide, limitée à 4 par seconde
        pendingPartialText = text
        schedulePartialTranslation()
    }

    private func schedulePartialTranslation() {
        guard !isPartialTranslationInFlight, let text = pendingPartialText else { return }

        let wait = partialTranslationInterval - Date().timeIntervalSince(lastPartialTranslationDate)
        if wait > 0 {
            isPartialTranslationInFlight = true
            DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [weak self] in
                self?.isPartialTranslationInFlight = false
                self?.schedulePartialTranslation()
            }
            return
        }

        pendingPartialText = nil
        isPartialTranslationInFlight = true
        lastPartialTranslationDate = Date()

        let segmentId = currentSegmentId
        let pair = currentLanguagePair

        Task { [weak self] in
            let result = await TranslationEngine.shared.translateDetailed(
                text: text,
                sourceLang: pair.sourceLanguage,
                targetLang: Self.targetEnum(pair.targetLanguage),
                quality: .fast
            )
            await MainActor.run {
                guard let self = self else { return }
                self.isPartialTranslationInFlight = false
                if let result = result, segmentId == self.currentSegmentId {
                    self.currentPartialTranslation = result.text
                    self.currentPartialAttribution = result.engine.attribution
                    self.publishLocalItem(original: self.currentOriginalText, translated: result.text, isFinal: false)
                }
                self.schedulePartialTranslation()
            }
        }
    }

    // MARK: - Phrase terminée : traduction finale + voix

    private func translateAndSpeak(text: String, segmentId: String, pair: LiveLanguagePair, partial: String, partialAttribution: String?, willSpeak: Bool) {
        // Le texte reconnu s'affiche figé tout de suite, la traduction finale suit
        publishItem(
            id: segmentId,
            isSpeech: true,
            original: text,
            originalLanguage: pair.sourceLanguage,
            translated: partial.isEmpty ? "…" : partial,
            targetLanguage: pair.targetLanguage,
            isFinal: false,
            attribution: partial.isEmpty ? nil : partialAttribution
        )

        let epoch = pipelineEpoch
        Task { [weak self] in
            let result = await TranslationEngine.shared.translateDetailed(
                text: text,
                sourceLang: pair.sourceLanguage,
                targetLang: Self.targetEnum(pair.targetLanguage),
                quality: .best
            )
            await MainActor.run {
                guard let self = self, self.isPipelineRunning, epoch == self.pipelineEpoch else { return }
                // Ne pas présenter l'hébreu inchangé comme une traduction française.
                let hasPartial = !partial.isEmpty && partial != "…"
                let finalText = result?.text ?? (hasPartial ? partial : "Traduction indisponible : préparez les langues hors ligne.")
                let attribution = result?.engine.attribution ?? (hasPartial ? partialAttribution : nil)
                self.publishItem(
                    id: segmentId,
                    isSpeech: true,
                    original: text,
                    originalLanguage: pair.sourceLanguage,
                    translated: finalText,
                    targetLanguage: pair.targetLanguage,
                    isFinal: true,
                    attribution: attribution
                )
                if willSpeak {
                    if result != nil || hasPartial {
                        self.speak(finalText, language: pair.targetLanguage)
                    } else {
                        self.resumeListening()
                    }
                }
            }
        }
    }

    // MARK: - Synthèse vocale

    private func speak(_ text: String, language: String) {
        guard !text.isEmpty, text != "…" else {
            resumeListening()
            return
        }

        setMicSuspended(true)

        let utterance = MultiAgentVoiceManager.shared.makeUtterance(text: text)
        utterance.voice = bestVoice(for: language)
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.05
        utterance.volume = 1.0

        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        // Sortie audible : si iOS a placé le son sur l'écouteur du haut, on repasse sur le haut-parleur.
        let session = AVAudioSession.sharedInstance()
        let outputs = session.currentRoute.outputs
        if outputs.count == 1, outputs.first?.portType == .builtInReceiver {
            try? session.overrideOutputAudioPort(.speaker)
        }
        speechSynthesizer.speak(utterance)

    }

    private func resumeListening() {
        DispatchQueue.main.asyncAfter(deadline: .now() + resumeListeningDelay) { [weak self] in
            guard let self = self, self.isPipelineRunning, !self.speechSynthesizer.isSpeaking else { return }
            self.setMicSuspended(false)
            self.startRecognitionSession()
        }
    }

    /// Voix de meilleure qualité installée pour la langue (Premium > Améliorée > Standard).
    private func bestVoice(for language: String) -> AVSpeechSynthesisVoice? {
        let localeCode = localeIdentifier(for: language)
        let prefix = String(localeCode.prefix(2))
        let candidates = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix(prefix) }
        let exact = candidates.filter { $0.language == localeCode }
        let pool = exact.isEmpty ? candidates : exact
        if let best = pool.max(by: { $0.quality.rawValue < $1.quality.rawValue }) {
            return best
        }
        return AVSpeechSynthesisVoice(language: localeCode) ?? AVSpeechSynthesisVoice(language: "fr-FR")
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        resumeListening()
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        resumeListening()
    }

    // MARK: - Publication vers l'UI

    private func publishLocalItem(original: String, translated: String, isFinal: Bool) {
        publishItem(
            id: currentSegmentId,
            isSpeech: true,
            original: original,
            originalLanguage: currentLanguagePair.sourceLanguage,
            translated: translated,
            targetLanguage: currentLanguagePair.targetLanguage,
            isFinal: isFinal,
            attribution: currentPartialTranslation.isEmpty ? nil : currentPartialAttribution
        )
    }

    private func publishItem(id: String, isSpeech: Bool, original: String, originalLanguage: String, translated: String, targetLanguage: String, isFinal: Bool, attribution: String? = nil) {
        let item = LiveTranscriptItem(
            id: id,
            isSpeech: isSpeech,
            originalText: original,
            originalLanguage: originalLanguage,
            translatedText: translated,
            targetLanguage: targetLanguage,
            isFinal: isFinal,
            attribution: attribution
        )
        onTranscriptItemUpdated?(item)
    }

    // MARK: - Autorisations

    private func requestSpeechAuthorizationIfNeeded(_ completion: @escaping (Bool) -> Void) {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            completion(true)
        case .notDetermined:
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async { completion(status == .authorized) }
            }
        default:
            completion(false)
        }
    }

    // MARK: - Helpers

    private func runOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }

    private static func targetEnum(_ code: String) -> TranslationEngine.TargetLanguage {
        switch code {
        case "en": return .english
        case "he": return .hebrew
        default: return .french
        }
    }

    private func localeIdentifier(for langCode: String) -> String {
        switch langCode {
        case "en": return "en-US"
        case "he": return "he-IL"
        case "fr": return "fr-FR"
        default: return "fr-FR"
        }
    }
}

// MARK: - Whisper hors ligne pour la traduction en direct

/// Transcription hors ligne pour la traduction en direct, avec le même moteur et le même modèle
/// que le mode vocal (whisper.cpp + `WhisperModels/ggml-base.bin` déjà inclus dans l'app).
/// Contexte séparé : le mode vocal du chat n'est jamais touché. Libéré à la fermeture de l'écran.
final class LiveWhisperTranscriber {
    static let shared = LiveWhisperTranscriber()

    private let queue = DispatchQueue(label: "sarah.live.whisper", qos: .userInitiated)
    private let lock = NSLock()
    private var busy = false
    private var context: OpaquePointer?

    private static var modelURL: URL? {
        Bundle.main.url(forResource: "ggml-base", withExtension: "bin", subdirectory: "WhisperModels")
    }

    /// Vrai si Whisper et son modèle sont présents dans l'app.
    static var isAvailable: Bool {
        #if canImport(whisper)
        return modelURL != nil
        #else
        return false
        #endif
    }

    /// Charge le modèle en arrière-plan (quelques secondes la première fois).
    func prepare() {
        queue.async { [weak self] in
            _ = self?.loadIfNeeded()
        }
    }

    /// Libère la mémoire quand la traduction en direct est fermée.
    func release() {
        queue.async { [weak self] in
            #if canImport(whisper)
            if let context = self?.context {
                whisper_free(context)
            }
            #endif
            self?.context = nil
        }
    }

    /// Transcrit un extrait 16 kHz mono. `language` : "he", "fr", "en" ou `nil` (détection automatique).
    func transcribe(_ samples: [Float], language: String?, skipIfBusy: Bool = false) async -> String? {
        guard !samples.isEmpty else { return nil }
        lock.lock()
        if skipIfBusy && busy {
            lock.unlock()
            return nil
        }
        busy = true
        lock.unlock()

        return await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                let text = self?.runInference(samples, language: language)
                self?.lock.lock()
                self?.busy = false
                self?.lock.unlock()
                continuation.resume(returning: text)
            }
        }
    }

    // MARK: Moteur (file `queue` uniquement)

    private func loadIfNeeded() -> Bool {
        #if canImport(whisper)
        if context != nil { return true }
        guard let url = Self.modelURL else { return false }

        func load(useGPU: Bool, flashAttention: Bool) -> OpaquePointer? {
            var params = whisper_context_default_params()
            params.use_gpu = useGPU
            params.flash_attn = flashAttention
            return whisper_init_from_file_with_params(url.path, params)
        }

        #if targetEnvironment(simulator)
        context = load(useGPU: false, flashAttention: false)
        #else
        context = load(useGPU: true, flashAttention: true)
            ?? load(useGPU: true, flashAttention: false)
            ?? load(useGPU: false, flashAttention: false)
        #endif
        return context != nil
        #else
        return false
        #endif
    }

    private func runInference(_ audio: [Float], language: String?) -> String? {
        #if canImport(whisper)
        guard loadIfNeeded(), let context = context else { return nil }

        let threadCount = Int32(max(1, min(8, ProcessInfo.processInfo.activeProcessorCount - 2)))
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.print_realtime = false
        params.print_progress = false
        params.print_timestamps = false
        params.print_special = false
        params.translate = false
        params.no_context = true
        params.single_segment = false
        params.n_threads = threadCount
        params.temperature_inc = -1

        let result: Int32 = (language ?? "auto").withCString { languagePointer in
            params.language = languagePointer
            return audio.withUnsafeBufferPointer { pointer in
                whisper_full(context, params, pointer.baseAddress, Int32(audio.count))
            }
        }
        guard result == 0 else { return nil }

        var pieces: [String] = []
        let count = whisper_full_n_segments(context)
        if count > 0 {
            for index in 0..<count {
                if let cText = whisper_full_get_segment_text(context, index) {
                    let text = String(cString: cText).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty { pieces.append(text) }
                }
            }
        }
        let text = pieces.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return Self.isHallucination(text) ? nil : text
        #else
        return nil
        #endif
    }

    /// Filtre les phrases fantômes que Whisper invente parfois sur du silence.
    private static func isHallucination(_ text: String) -> Bool {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        if cleaned.isEmpty { return true }
        let lower = cleaned.lowercased()
        let ghosts = [
            "sous-titres réalisés par", "sous-titrage", "merci d'avoir regardé",
            "thank you for watching", "thanks for watching", "תודה רבה שצפיתם", "תודה שצפיתם"
        ]
        return ghosts.contains { lower.contains($0) }
    }
}
