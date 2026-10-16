import Foundation
import AVFoundation
import QuartzCore
import Speech

/// Pipeline de traduction vocale en temps réel.
///
/// Fonctionnement :
/// 1. Pendant que la personne parle : sous-titres immédiats (texte reconnu + traduction rapide sur l'iPhone).
/// 2. À la première pause (~0,8 s) : la phrase est figée, traduite par le pack Google hors ligne
///    (gratuit, avec ou sans Internet), puis prononcée.
/// 3. Pendant que Sarah parle, le micro est ignoré : le téléphone ne retraduit jamais sa propre voix.
///    L'écoute reprend toute seule dès que la voix a fini.
public final class LiveSpeechTranslationPipeline: NSObject, SFSpeechRecognizerDelegate, AVSpeechSynthesizerDelegate {

    public static let shared = LiveSpeechTranslationPipeline()

    // Callbacks pour l'UI et la couche d'appel (toujours appelés sur le thread principal)
    public var onTranscriptItemUpdated: ((CallTranscriptItem) -> Void)?
    public var onSynthesizedAudioReady: ((Data, String) -> Void)?
    public var onAudioEnergyLevel: ((Float) -> Void)?

    // MARK: - Réglages de réactivité

    /// Silence après lequel la phrase est considérée comme terminée.
    private let endOfSentenceSilence: TimeInterval = 0.8
    /// Intervalle minimal entre deux traductions rapides des sous-titres.
    private let partialTranslationInterval: TimeInterval = 0.25
    /// Délai avant de réécouter après la fin de la voix (évite d'attraper la fin du son).
    private let resumeListeningDelay: TimeInterval = 0.25
    /// Fréquence max de mise à jour de l'animation du micro (~15 images/s).
    private let energyUpdateInterval: CFTimeInterval = 1.0 / 15.0

    // MARK: - Reconnaissance vocale

    private var localSpeechRecognizer: SFSpeechRecognizer?
    private var localRecognitionTask: SFSpeechRecognitionTask?

    /// Requête courante, lue depuis le thread audio : protégée par un verrou.
    private let audioLock = NSLock()
    private var _activeRequest: SFSpeechAudioBufferRecognitionRequest?
    private var _isMicSuspended = false
    private var lastEnergyUpdate: CFTimeInterval = 0

    // MARK: - Synthèse vocale

    private let speechSynthesizer = AVSpeechSynthesizer()

    // MARK: - État (thread principal uniquement)

    private var currentLanguagePair = CallLanguagePair()
    private var isPipelineRunning = false
    /// Incrémenté à chaque nouvelle session de reconnaissance : les résultats d'une ancienne session sont ignorés.
    private var recognitionGeneration = 0

    private var currentSegmentId = UUID().uuidString
    private var currentOriginalText = ""
    private var currentPartialTranslation = ""
    private var currentPartialAttribution: String?
    private var silenceTimer: Timer?

    private var isPartialTranslationInFlight = false
    private var pendingPartialText: String?
    private var lastPartialTranslationDate = Date.distantPast

    private override init() {
        super.init()
        speechSynthesizer.delegate = self
    }

    // MARK: - Démarrage / Arrêt

    public func startPipeline(with languagePair: CallLanguagePair) {
        runOnMain { [weak self] in
            guard let self = self else { return }
            self.stopPipelineOnMain()
            self.currentLanguagePair = languagePair
            self.isPipelineRunning = true
            TranslationEngine.shared.prepareOfflinePacks(for: [languagePair.localLanguage, languagePair.remoteLanguage])

            let localeId = self.localeIdentifier(for: languagePair.localLanguage)
            self.localSpeechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeId))
            self.localSpeechRecognizer?.delegate = self

            self.requestSpeechAuthorizationIfNeeded { authorized in
                guard authorized, self.isPipelineRunning else {
                    print("⚠️ [Traduction] Reconnaissance vocale non autorisée")
                    return
                }
                self.startRecognitionSession()
            }
        }
    }

    public func updateLanguagePair(_ newPair: CallLanguagePair) {
        runOnMain { [weak self] in
            guard let self = self else { return }
            let needsRestart = newPair.localLanguage != self.currentLanguagePair.localLanguage
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
    }

    // MARK: - Ingestion des buffers micro (thread audio)

    public func processMicrophoneBuffer(_ buffer: AVAudioPCMBuffer) {
        audioLock.lock()
        let request = _activeRequest
        let suspended = _isMicSuspended
        audioLock.unlock()

        // Pendant que Sarah parle, on n'écoute pas : pas d'écho, pas de boucle.
        guard !suspended else { return }

        request?.append(buffer)
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

    private func setActiveRequest(_ request: SFSpeechAudioBufferRecognitionRequest?) {
        audioLock.lock()
        _activeRequest = request
        audioLock.unlock()
    }

    private func setMicSuspended(_ suspended: Bool) {
        audioLock.lock()
        _isMicSuspended = suspended
        audioLock.unlock()
        if suspended {
            onAudioEnergyLevel?(0)
        }
    }

    // MARK: - Session de reconnaissance

    private func startRecognitionSession() {
        guard isPipelineRunning else { return }
        guard let recognizer = localSpeechRecognizer, recognizer.isAvailable else {
            print("⚠️ [Traduction] Reconnaissance vocale indisponible, nouvel essai dans 1 s")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.startRecognitionSession()
            }
            return
        }

        endRecognitionSession()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        if #available(iOS 16.0, *) {
            request.addsPunctuation = true
        }
        // Sur l'iPhone quand c'est possible (plus rapide, marche sans Internet)
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition

        recognitionGeneration += 1
        let generation = recognitionGeneration

        currentSegmentId = UUID().uuidString
        currentOriginalText = ""
        currentPartialTranslation = ""
        currentPartialAttribution = nil
        pendingPartialText = nil

        setActiveRequest(request)

        localRecognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.handleRecognition(result: result, error: error, generation: generation)
            }
        }
    }

    private func endRecognitionSession() {
        recognitionGeneration += 1
        audioLock.lock()
        let request = _activeRequest
        _activeRequest = nil
        audioLock.unlock()
        request?.endAudio()
        localRecognitionTask?.cancel()
        localRecognitionTask = nil
    }

    private func handleRecognition(result: SFSpeechRecognitionResult?, error: Error?, generation: Int) {
        // Résultat d'une ancienne session : ignoré (c'est ce qui causait les répétitions)
        guard generation == recognitionGeneration, isPipelineRunning else { return }

        if let result = result {
            let transcription = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
            if !transcription.isEmpty && transcription != currentOriginalText {
                currentOriginalText = transcription
                handlePartialTranscription(transcription)
            }
            if result.isFinal {
                finalizeCurrentSegment()
                return
            }
        }

        if error != nil {
            // Fin de session côté iOS (limite de durée, silence prolongé…) : on termine la phrase et on relance.
            if !currentOriginalText.isEmpty {
                finalizeCurrentSegment()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    self?.startRecognitionSession()
                }
            }
        }
    }

    // MARK: - Sous-titres en direct

    private func handlePartialTranscription(_ text: String) {
        // 1. Le texte original s'affiche tout de suite
        publishLocalItem(original: text, translated: currentPartialTranslation.isEmpty ? "…" : currentPartialTranslation, isFinal: false)

        // 2. Traduction rapide (sur l'iPhone), limitée à 4 par seconde
        pendingPartialText = text
        schedulePartialTranslation()

        // 3. Détection de fin de phrase par le silence
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: endOfSentenceSilence, repeats: false) { [weak self] _ in
            self?.finalizeCurrentSegment()
        }
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
                sourceLang: pair.localLanguage,
                targetLang: Self.targetEnum(pair.remoteLanguage),
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

    // MARK: - Phrase terminée

    private func finalizeCurrentSegment() {
        silenceTimer?.invalidate()
        silenceTimer = nil

        let text = currentOriginalText
        let segmentId = currentSegmentId
        let pair = currentLanguagePair
        let partial = currentPartialTranslation
        let partialAttribution = currentPartialAttribution

        guard !text.isEmpty else { return }

        // On coupe la session : la phrase suivante repartira de zéro (plus de texte accumulé)
        endRecognitionSession()
        currentOriginalText = ""
        currentPartialTranslation = ""
        currentPartialAttribution = nil
        pendingPartialText = nil

        let willSpeak = pair.isVoiceTranslationEnabled
        if willSpeak {
            // Micro coupé dès maintenant pour ne pas capter la voix de Sarah
            setMicSuspended(true)
        } else {
            startRecognitionSession()
        }

        Task { [weak self] in
            let result = await TranslationEngine.shared.translateDetailed(
                text: text,
                sourceLang: pair.localLanguage,
                targetLang: Self.targetEnum(pair.remoteLanguage),
                quality: .best
            )
            await MainActor.run {
                guard let self = self else { return }
                // Si aucun moteur n'a traduit, on garde au moins la traduction rapide, sinon le texte d'origine
                let finalText = result?.text ?? (partial.isEmpty ? text : partial)
                let attribution = result?.engine.attribution ?? (partial.isEmpty ? nil : partialAttribution)
                self.publishItem(
                    id: segmentId,
                    isLocal: true,
                    original: text,
                    originalLanguage: pair.localLanguage,
                    translated: finalText,
                    targetLanguage: pair.remoteLanguage,
                    isFinal: true,
                    attribution: attribution
                )
                guard self.isPipelineRunning else { return }
                if willSpeak {
                    self.speak(finalText, language: pair.remoteLanguage)
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
        speechSynthesizer.speak(utterance)

        onSynthesizedAudioReady?(Data(text.utf8), language)
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

    // MARK: - Audio distant (correspondant -> utilisateur)

    public func handleRemoteIncomingText(_ remoteText: String) {
        let pair = currentLanguagePair
        let id = UUID().uuidString

        runOnMain { [weak self] in
            self?.publishItem(
                id: id,
                isLocal: false,
                original: remoteText,
                originalLanguage: pair.remoteLanguage,
                translated: "…",
                targetLanguage: pair.localLanguage,
                isFinal: false
            )
        }

        Task { [weak self] in
            let result = await TranslationEngine.shared.translateDetailed(
                text: remoteText,
                sourceLang: pair.remoteLanguage,
                targetLang: Self.targetEnum(pair.localLanguage),
                quality: .best
            )
            await MainActor.run {
                self?.publishItem(
                    id: id,
                    isLocal: false,
                    original: remoteText,
                    originalLanguage: pair.remoteLanguage,
                    translated: result?.text ?? remoteText,
                    targetLanguage: pair.localLanguage,
                    isFinal: true,
                    attribution: result?.engine.attribution
                )
            }
        }
    }

    // MARK: - Publication vers l'UI

    private func publishLocalItem(original: String, translated: String, isFinal: Bool) {
        publishItem(
            id: currentSegmentId,
            isLocal: true,
            original: original,
            originalLanguage: currentLanguagePair.localLanguage,
            translated: translated,
            targetLanguage: currentLanguagePair.remoteLanguage,
            isFinal: isFinal,
            attribution: currentPartialTranslation.isEmpty ? nil : currentPartialAttribution
        )
    }

    private func publishItem(id: String, isLocal: Bool, original: String, originalLanguage: String, translated: String, targetLanguage: String, isFinal: Bool, attribution: String? = nil) {
        let item = CallTranscriptItem(
            id: id,
            isLocalSpeaker: isLocal,
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
