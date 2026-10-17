import Foundation
import AVFoundation
#if canImport(Combine)
import Combine
#endif
#if canImport(WhisperKit)
import WhisperKit
#endif

// MARK: - Moteur Whisper partagé (WhisperKit, licence MIT)

/// Moteur Whisper de Sarah, entièrement sur l'iPhone (WhisperKit / Core ML, licence MIT : utilisable dans une app vendue).
///
/// - **Modèle intégré à l'app** (`openai_whisper-base`) : la voix marche dès l'installation, sans Internet,
///   sans aucun téléchargement.
/// - **Précision maximale en option** : `large-v3 turbo` (632 Mo, très bon en hébreu) sur les iPhone
///   avec 6 Go de RAM ou plus, sinon `small` (216 Mo). Téléchargé une seule fois (bouton des Réglages,
///   ou automatiquement en Wi-Fi), puis utilisé à la place du modèle intégré.
public actor SarahWhisperEngine {

    public static let shared = SarahWhisperEngine()

    /// Notification envoyée pendant le téléchargement (userInfo["progress"] : Double 0…1).
    public static let downloadProgressNotification = Notification.Name("SarahWhisperDownloadProgress")
    /// Notification envoyée quand le modèle devient prêt ou échoue (userInfo["ready"] : Bool).
    public static let stateChangedNotification = Notification.Name("SarahWhisperStateChanged")

    public static var isAvailable: Bool {
        #if canImport(WhisperKit)
        return true
        #else
        return false
        #endif
    }

    // MARK: Modèle intégré

    /// Modèle livré dans l'IPA (ajouté par le workflow de compilation).
    public static var bundledModelFolder: URL? {
        Bundle.main.url(forResource: "openai_whisper-base", withExtension: nil, subdirectory: "WhisperKitModels")
    }

    // MARK: Modèle de précision maximale (optionnel)

    /// Modèle de précision maximale, choisi selon la mémoire de l'iPhone.
    public static var modelVariant: String {
        let ramGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        return ramGB >= 5.5
            ? "openai_whisper-large-v3-v20240930_turbo_632MB"
            : "openai_whisper-small_216MB"
    }

    public static var modelDisplaySize: String {
        modelVariant.contains("632MB") ? "632 Mo" : "216 Mo"
    }

    private static let savedFolderKey = "sarah.whisper.modelRelativePath"
    private static let savedVariantKey = "sarah.whisper.modelVariant"

    /// Dossier des modèles téléchargés (Application Support, exclu de la sauvegarde iCloud).
    private static var downloadBase: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SarahWhisper", isDirectory: true)
        if !FileManager.default.fileExists(atPath: base.path) {
            try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            var url = base
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? url.setResourceValues(values)
        }
        return base
    }

    /// Dossier du modèle de précision maximale, s'il a été téléchargé.
    public static var downloadedModelFolder: URL? {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: savedVariantKey) == modelVariant,
              let relative = defaults.string(forKey: savedFolderKey) else { return nil }
        let folder = downloadBase.appendingPathComponent(relative, isDirectory: true)
        return FileManager.default.fileExists(atPath: folder.path) ? folder : nil
    }

    /// Vrai si la précision maximale est installée.
    public static var isUpgradeInstalled: Bool {
        downloadedModelFolder != nil
    }

    /// Vrai si une reconnaissance vocale hors ligne est disponible (modèle intégré ou téléchargé).
    public static var isModelDownloaded: Bool {
        isAvailable && (bundledModelFolder != nil || downloadedModelFolder != nil)
    }

    #if canImport(WhisperKit)
    private var pipe: WhisperKit?
    private var pipeIsUpgrade = false
    private var loadTask: Task<WhisperKit?, Never>?
    #endif
    private var isBusy = false
    private var isDownloadingUpgrade = false

    public var isReady: Bool {
        #if canImport(WhisperKit)
        return pipe != nil
        #else
        return false
        #endif
    }

    public var isUpgradeDownloading: Bool { isDownloadingUpgrade }

    // MARK: Préparation

    /// Charge le meilleur modèle présent sur l'iPhone (jamais de téléchargement ici, donc rapide).
    /// Si `allowDownload`, lance en plus le téléchargement de la précision maximale en arrière-plan.
    @discardableResult
    public func prepare(allowDownload: Bool) async -> Bool {
        #if canImport(WhisperKit)
        let ready = await loadIfNeeded() != nil
        if allowDownload && !Self.isUpgradeInstalled && !isDownloadingUpgrade && NetworkMonitor.shared.isOnline {
            Task { await self.downloadUpgrade() }
        }
        return ready
        #else
        return false
        #endif
    }

    #if canImport(WhisperKit)
    private func loadIfNeeded() async -> WhisperKit? {
        if let pipe { return pipe }
        if let loadTask { return await loadTask.value }

        let upgrade = Self.downloadedModelFolder
        guard let modelFolder = upgrade ?? Self.bundledModelFolder else {
            print("⚠️ [Whisper] Aucun modèle vocal présent dans l'app")
            return nil
        }
        let isUpgrade = upgrade != nil

        let task = Task<WhisperKit?, Never> {
            do {
                return try await Self.makeKit(modelFolder: modelFolder)
            } catch {
                print("⚠️ [Whisper] Chargement impossible : \(error.localizedDescription)")
                return nil
            }
        }
        loadTask = task
        var result = await task.value
        loadTask = nil

        // Si le modèle téléchargé est abîmé, on revient au modèle intégré.
        if result == nil, isUpgrade, let bundled = Self.bundledModelFolder {
            UserDefaults.standard.removeObject(forKey: Self.savedFolderKey)
            result = try? await Self.makeKit(modelFolder: bundled)
            pipeIsUpgrade = false
        } else {
            pipeIsUpgrade = isUpgrade
        }

        pipe = result
        NotificationCenter.default.post(
            name: Self.stateChangedNotification,
            object: nil,
            userInfo: ["ready": result != nil]
        )
        return result
    }

    private static func makeKit(modelFolder: URL) async throws -> WhisperKit {
        // Le tokenizer est cherché à côté du modèle (inclus pour le modèle intégré) puis dans
        // `downloadBase` (rangé là au premier chargement en ligne du modèle téléchargé).
        try await WhisperKit(
            modelFolder: modelFolder.path,
            tokenizerFolder: downloadBase,
            verbose: false,
            logLevel: .error,
            prewarm: true,
            load: true,
            download: false
        )
    }
    #endif

    /// Télécharge la précision maximale (une seule fois), puis l'utilise à la place du modèle intégré.
    @discardableResult
    public func downloadUpgrade() async -> Bool {
        #if canImport(WhisperKit)
        if Self.isUpgradeInstalled {
            if !pipeIsUpgrade { pipe = nil; _ = await loadIfNeeded() }
            return true
        }
        guard !isDownloadingUpgrade, NetworkMonitor.shared.isOnline else { return false }
        isDownloadingUpgrade = true
        defer { isDownloadingUpgrade = false }

        do {
            let base = Self.downloadBase
            let folder = try await WhisperKit.download(
                variant: Self.modelVariant,
                downloadBase: base,
                progressCallback: { progress in
                    NotificationCenter.default.post(
                        name: SarahWhisperEngine.downloadProgressNotification,
                        object: nil,
                        userInfo: ["progress": progress.fractionCompleted]
                    )
                }
            )
            // Premier chargement en ligne : récupère et range le tokenizer pour le hors ligne.
            let kit = try await Self.makeKit(modelFolder: folder)
            let relative = folder.path.replacingOccurrences(of: base.path + "/", with: "")
            UserDefaults.standard.set(relative, forKey: Self.savedFolderKey)
            UserDefaults.standard.set(Self.modelVariant, forKey: Self.savedVariantKey)
            pipe = kit
            pipeIsUpgrade = true
            NotificationCenter.default.post(name: Self.stateChangedNotification, object: nil, userInfo: ["ready": true])
            return true
        } catch {
            print("⚠️ [Whisper] Téléchargement de la précision maximale impossible : \(error.localizedDescription)")
            NotificationCenter.default.post(name: Self.stateChangedNotification, object: nil, userInfo: ["ready": pipe != nil])
            return false
        }
        #else
        return false
        #endif
    }

    // MARK: Transcription

    /// Transcrit un extrait audio 16 kHz mono.
    /// - Parameters:
    ///   - language: "he", "fr", "en"… ou `nil` pour la détection automatique.
    ///   - skipIfBusy: pour les sous-titres partiels, on saute plutôt que de faire la queue.
    public func transcribe(_ samples: [Float], language: String?, skipIfBusy: Bool = false) async -> String? {
        #if canImport(WhisperKit)
        guard !samples.isEmpty else { return nil }
        if skipIfBusy && isBusy { return nil }
        guard let pipe = await loadIfNeeded() else { return nil }

        isBusy = true
        defer { isBusy = false }

        let options = DecodingOptions(
            task: .transcribe,
            language: language,
            temperature: 0.0,
            usePrefillPrompt: language != nil,
            detectLanguage: language == nil,
            skipSpecialTokens: true,
            withoutTimestamps: true
        )
        do {
            let results = try await pipe.transcribe(audioArray: samples, decodeOptions: options)
            let text = results
                .map { $0.text }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return Self.isHallucination(text) ? nil : text
        } catch {
            print("⚠️ [Whisper] Transcription impossible : \(error.localizedDescription)")
            return nil
        }
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

// MARK: - Service vocal Whisper (mode vocal du chat)

/// Reconnaissance vocale locale (Whisper sur l'iPhone) pour le mode vocal de Sarah.
@available(iOS 13.0, *)
public final class WhisperService: ObservableObject {
    public static let shared = WhisperService()

    @Published public private(set) var isRecording = false
    @Published public private(set) var isTranscribing = false
    @Published public private(set) var currentText = ""
    @Published public private(set) var micEnergyLevel: Float = 0
    @Published public private(set) var isModelReady = false
    @Published public private(set) var isModelLoading = false
    @Published public private(set) var lastError: String?

    public var onPartialTranscription: ((String) -> Void)?
    public var onFinalTranscription: ((String) -> Void)?
    public var onVoiceActivity: (() -> Void)?

    /// Langue forcée ("he", "fr"…) ou `nil` pour la détection automatique.
    public var preferredLanguage: String?

    private let audioEngine = AVAudioEngine()
    private let audioQueue = DispatchQueue(label: "sarah.whisper.audio", qos: .userInitiated)
    private var converter: AVAudioConverter?
    private var samples: [Float] = []
    private var automaticFinalize = true
    private var hasDetectedSpeech = false
    private var lastVoiceActivity = Date.distantPast
    private var lastBargeInNotification = Date.distantPast
    private var consecutiveVoiceChunks = 0
    private var generation = UUID()
    private var isFinalizing = false

    // Whisper peut mettre un moment à se charger : on mémorise l'intention de l'utilisateur
    // et on démarre la capture dès que le modèle est prêt, sans bloquer l'interface.
    private var wantsRecordingAfterModelLoad = false
    private var pendingAutoFinalizeOnSilence = true

    private let targetSampleRate: Double = 16_000
    private let silenceThreshold: TimeInterval = 0.92
    private let minimumUtteranceSeconds: Double = 0.35
    private let maximumUtteranceSeconds: Double = 30
    private let activityDBThreshold: Float = -48

    private init() {}

    // MARK: Permissions

    public func requestAuthorization(completion: @escaping (Bool) -> Void) {
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted:
            completion(true)
        case .denied:
            completion(false)
        case .undetermined:
            session.requestRecordPermission { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        @unknown default:
            completion(false)
        }
    }

    // MARK: Lifecycle

    @Published public private(set) var isUpgradeDownloading = false

    /// Prépare le modèle au lancement (modèle intégré : immédiat et hors ligne).
    /// En Wi-Fi, la précision maximale se télécharge en plus, en arrière-plan.
    public func prepareModel() {
        guard !isModelReady else { return }
        prepareModelInBackgroundIfNeeded(allowDownload: NetworkMonitor.shared.isOnUnmeteredNetwork)
    }

    /// Téléchargement de la précision maximale demandé dans les Réglages (tout réseau).
    public func downloadModelNow() {
        guard !isUpgradeDownloading else { return }
        isUpgradeDownloading = true
        Task { [weak self] in
            let ok = await SarahWhisperEngine.shared.downloadUpgrade()
            await MainActor.run {
                self?.isUpgradeDownloading = false
                if ok { self?.isModelReady = true }
            }
        }
    }

    public func startRecording(autoFinalizeOnSilence: Bool = true) {
        guard !isRecording, !isTranscribing else { return }

        guard AVAudioSession.sharedInstance().recordPermission == .granted else {
            requestAuthorization { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.startRecording(autoFinalizeOnSilence: autoFinalizeOnSilence)
                } else {
                    self.lastError = "Autorisation microphone refusée"
                }
            }
            return
        }

        if !isModelReady {
            // Chargement du modèle intégré (quelques secondes au tout premier usage), jamais de téléchargement.
            wantsRecordingAfterModelLoad = true
            pendingAutoFinalizeOnSilence = autoFinalizeOnSilence
            prepareModelInBackgroundIfNeeded(allowDownload: false)
            return
        }

        wantsRecordingAfterModelLoad = false
        beginAudioCapture(autoFinalizeOnSilence: autoFinalizeOnSilence)
    }

    private func prepareModelInBackgroundIfNeeded(allowDownload: Bool) {
        guard !isModelLoading else { return }
        isModelLoading = true
        lastError = nil

        Task { [weak self] in
            let ready = await SarahWhisperEngine.shared.prepare(allowDownload: allowDownload)
            await MainActor.run {
                guard let self else { return }
                self.isModelLoading = false
                self.isModelReady = ready

                if ready {
                    self.lastError = nil
                    guard self.wantsRecordingAfterModelLoad else { return }
                    let autoFinalize = self.pendingAutoFinalizeOnSilence
                    self.wantsRecordingAfterModelLoad = false
                    self.startRecording(autoFinalizeOnSilence: autoFinalize)
                } else {
                    self.wantsRecordingAfterModelLoad = false
                    self.lastError = SarahWhisperEngine.isModelDownloaded
                        ? "Le moteur vocal n'a pas pu démarrer. Réessaie dans un instant."
                        : "Le moteur vocal n'est pas inclus dans cette version de Sarah."
                }
            }
        }
    }

    private func beginAudioCapture(autoFinalizeOnSilence: Bool) {
        automaticFinalize = autoFinalizeOnSilence
        isFinalizing = false
        hasDetectedSpeech = false
        consecutiveVoiceChunks = 0
        samples.removeAll(keepingCapacity: true)
        currentText = ""
        micEnergyLevel = 0
        generation = UUID()
        let currentGeneration = generation

        AudioSessionManager.shared.configureRecordingSession()

        let input = audioEngine.inputNode
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        input.removeTap(onBus: 0)

        if AudioSessionManager.shared.isContinuousVoiceSessionActive {
            do {
                if !input.isVoiceProcessingEnabled {
                    try input.setVoiceProcessingEnabled(true)
                }
            } catch {
                print("⚠️ [Whisper] Annulation d'écho iOS indisponible: \(error.localizedDescription)")
            }
        }

        // inputFormat est le format natif du micro. outputFormat peut décrire le graphe
        // en aval et devenir invalide après un changement de route audio.
        let sourceFormat = input.inputFormat(forBus: 0)
        guard sourceFormat.sampleRate > 0,
              sourceFormat.channelCount > 0,
              let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: targetSampleRate,
                channels: 1,
                interleaved: false
              ),
              let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            lastError = "Format microphone incompatible"
            return
        }
        self.converter = converter

        input.installTap(onBus: 0, bufferSize: 2048, format: sourceFormat) { [weak self] buffer, _ in
            self?.consume(buffer: buffer, targetFormat: targetFormat, generation: currentGeneration)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            lastError = nil
        } catch {
            input.removeTap(onBus: 0)
            self.converter = nil
            lastError = "Impossible de démarrer le microphone : \(error.localizedDescription)"
            AudioSessionManager.shared.deactivateSession()
        }
    }

    public func stopRecordingAndTranscribe(completion: ((String?) -> Void)? = nil) {
        wantsRecordingAfterModelLoad = false
        let snapshot = stopCaptureAndTakeSamples()
        guard !snapshot.isEmpty else {
            completion?(nil)
            return
        }
        transcribe(snapshot, final: true, completion: completion)
    }

    public func stopRecordingWithoutTranscription() {
        wantsRecordingAfterModelLoad = false
        _ = stopCaptureAndTakeSamples()
    }

    public func startTranscription() {
        startRecording()
    }

    public func stopTranscription() {
        stopRecordingAndTranscribe()
    }

    public func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        ) else { return }
        consume(buffer: buffer, targetFormat: targetFormat, generation: generation)
    }

    public func reset() {
        wantsRecordingAfterModelLoad = false
        stopRecordingWithoutTranscription()
        currentText = ""
        isTranscribing = false
        lastError = nil
    }

    // MARK: Audio capture + VAD

    private func consume(buffer: AVAudioPCMBuffer, targetFormat: AVAudioFormat, generation: UUID) {
        guard self.generation == generation, isRecording || audioEngine.isRunning else { return }
        guard let converter else { return }

        let ratio = targetSampleRate / max(1, buffer.format.sampleRate)
        let capacity = AVAudioFrameCount(max(1, Int(Double(buffer.frameLength) * ratio) + 32))
        guard let converted = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

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
        guard conversionError == nil,
              status != .error,
              let channel = converted.floatChannelData?[0],
              converted.frameLength > 0 else { return }

        let count = Int(converted.frameLength)
        let chunk = Array(UnsafeBufferPointer(start: channel, count: count))
        let rms = sqrt(chunk.reduce(Float(0)) { $0 + $1 * $1 } / Float(max(1, count)))
        let db = 20 * log10(max(rms, 0.000_001))
        let level = min(1, max(0, (db + 55) / 45))
        let now = Date()

        audioQueue.async { [weak self] in
            guard let self, self.generation == generation, !self.isFinalizing else { return }
            self.samples.append(contentsOf: chunk)

            if db >= self.activityDBThreshold {
                self.hasDetectedSpeech = true
                self.consecutiveVoiceChunks += 1
                self.lastVoiceActivity = now
                if self.consecutiveVoiceChunks >= 2,
                   now.timeIntervalSince(self.lastBargeInNotification) > 0.18 {
                    self.lastBargeInNotification = now
                    DispatchQueue.main.async {
                        self.onVoiceActivity?()
                    }
                }
            } else {
                self.consecutiveVoiceChunks = 0
            }

            DispatchQueue.main.async {
                self.micEnergyLevel = level
            }

            let duration = Double(self.samples.count) / self.targetSampleRate
            let enoughAudio = duration >= self.minimumUtteranceSeconds
            let silenceDetected = self.hasDetectedSpeech &&
                enoughAudio &&
                now.timeIntervalSince(self.lastVoiceActivity) >= self.silenceThreshold
            let reachedSafetyLimit = self.hasDetectedSpeech && duration >= self.maximumUtteranceSeconds

            if self.automaticFinalize && (silenceDetected || reachedSafetyLimit) {
                self.isFinalizing = true
                let finalSamples = self.samples
                DispatchQueue.main.async {
                    self.finishAfterSilence(samples: finalSamples, generation: generation)
                }
            }
        }
    }

    private func finishAfterSilence(samples: [Float], generation: UUID) {
        guard self.generation == generation else { return }
        stopAudioEngineOnly()
        transcribe(samples, final: true, completion: nil)
    }

    private func stopCaptureAndTakeSamples() -> [Float] {
        generation = UUID()
        stopAudioEngineOnly()
        var snapshot: [Float] = []
        audioQueue.sync {
            snapshot = samples
            samples.removeAll(keepingCapacity: true)
            hasDetectedSpeech = false
            consecutiveVoiceChunks = 0
            isFinalizing = false
        }
        return snapshot
    }

    private func stopAudioEngineOnly() {
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        converter = nil
        isRecording = false
        micEnergyLevel = 0
        if !MultiAgentVoiceManager.shared.isSpeaking {
            AudioSessionManager.shared.deactivateSession()
        }
    }

    // MARK: Inference

    private func transcribe(_ audio: [Float], final: Bool, completion: ((String?) -> Void)?) {
        guard !audio.isEmpty else {
            completion?(nil)
            return
        }

        isTranscribing = true
        let language = preferredLanguage

        Task { [weak self] in
            let text = await SarahWhisperEngine.shared.transcribe(audio, language: language) ?? ""
            await MainActor.run {
                guard let self else {
                    completion?(nil)
                    return
                }
                self.currentText = text
                self.isFinalizing = false
                self.isTranscribing = false
                if text.isEmpty && !SarahWhisperEngine.isModelDownloaded {
                    self.lastError = "Le moteur vocal n'est pas inclus dans cette version de Sarah."
                }
                if final {
                    if !text.isEmpty { self.onFinalTranscription?(text) }
                } else if !text.isEmpty {
                    self.onPartialTranscription?(text)
                }
                completion?(text.isEmpty ? nil : text)
            }
        }
    }
}
