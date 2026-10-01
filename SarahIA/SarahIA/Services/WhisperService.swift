import Foundation
import AVFoundation
import whisper
#if canImport(Combine)
import Combine
#endif

/// Local speech-to-text powered by OpenAI Whisper model weights through whisper.cpp.
/// The model is bundled with the IPA and inference stays on-device.
@available(iOS 13.0, *)
public final class WhisperService: ObservableObject {
    public static let shared = WhisperService()

    @Published public private(set) var isRecording = false
    @Published public private(set) var currentText = ""
    @Published public private(set) var micEnergyLevel: Float = 0
    @Published public private(set) var isModelReady = false
    @Published public private(set) var isModelLoading = false
    @Published public private(set) var lastError: String?

    public var onPartialTranscription: ((String) -> Void)?
    public var onFinalTranscription: ((String) -> Void)?
    public var onVoiceActivity: (() -> Void)?

    private let audioEngine = AVAudioEngine()
    private let audioQueue = DispatchQueue(label: "sarah.whisper.audio", qos: .userInitiated)
    private let inferenceQueue = DispatchQueue(label: "sarah.whisper.inference", qos: .userInitiated)
    private var converter: AVAudioConverter?
    private var context: OpaquePointer?
    private var samples: [Float] = []
    private var automaticFinalize = true
    private var hasDetectedSpeech = false
    private var lastVoiceActivity = Date.distantPast
    private var lastBargeInNotification = Date.distantPast
    private var consecutiveVoiceChunks = 0
    private var generation = UUID()
    private var isFinalizing = false

    // Le chargement de ggml-base.bin peut prendre un moment sur un iPhone réel.
    // Il ne doit jamais bloquer le thread principal ni empêcher l'écran vocal
    // de s'afficher immédiatement après le premier toucher.
    private var wantsRecordingAfterModelLoad = false
    private var pendingAutoFinalizeOnSilence = true

    private let targetSampleRate: Double = 16_000
    private let silenceThreshold: TimeInterval = 0.92
    private let minimumUtteranceSeconds: Double = 0.35
    private let activityDBThreshold: Float = -40

    private init() {}

    deinit {
        if let context { whisper_free(context) }
    }

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

    /// Précharge uniquement le modèle Whisper. Cette méthode n'ouvre pas le micro
    /// et ne demande aucune permission. Elle peut donc être appelée après le premier
    /// rendu de l'application pour rendre le premier lancement vocal beaucoup plus vif.
    public func prepareModel() {
        guard context == nil else {
            isModelReady = true
            return
        }
        prepareModelInBackgroundIfNeeded()
    }

    public func startRecording(autoFinalizeOnSilence: Bool = true) {
        guard !isRecording else { return }

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

        // Très important : ne jamais initialiser whisper.cpp sur le main thread.
        // On mémorise l'intention de démarrer le micro puis on reprend exactement
        // la même demande dès que le modèle est prêt.
        if context == nil {
            wantsRecordingAfterModelLoad = true
            pendingAutoFinalizeOnSilence = autoFinalizeOnSilence
            prepareModelInBackgroundIfNeeded()
            return
        }

        wantsRecordingAfterModelLoad = false
        isModelReady = true
        beginAudioCapture(autoFinalizeOnSilence: autoFinalizeOnSilence)
    }

    private func prepareModelInBackgroundIfNeeded() {
        guard context == nil else {
            isModelReady = true
            if wantsRecordingAfterModelLoad {
                let autoFinalize = pendingAutoFinalizeOnSilence
                wantsRecordingAfterModelLoad = false
                startRecording(autoFinalizeOnSilence: autoFinalize)
            }
            return
        }
        guard !isModelLoading else { return }

        isModelLoading = true
        lastError = nil

        inferenceQueue.async { [weak self] in
            guard let self else { return }
            let result: Result<Void, Error>
            do {
                try self.ensureModelLoaded()
                result = .success(())
            } catch {
                result = .failure(error)
            }

            DispatchQueue.main.async {
                self.isModelLoading = false

                switch result {
                case .success:
                    self.isModelReady = true
                    self.lastError = nil
                    guard self.wantsRecordingAfterModelLoad else { return }
                    let autoFinalize = self.pendingAutoFinalizeOnSilence
                    self.wantsRecordingAfterModelLoad = false
                    self.startRecording(autoFinalizeOnSilence: autoFinalize)

                case .failure(let error):
                    self.wantsRecordingAfterModelLoad = false
                    self.isModelReady = false
                    self.lastError = error.localizedDescription
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

        if AudioSessionManager.shared.isContinuousVoiceSessionActive {
            do {
                if !input.isVoiceProcessingEnabled {
                    try input.setVoiceProcessingEnabled(true)
                }
            } catch {
                print("⚠️ [Whisper] Annulation d'écho iOS indisponible: \(error.localizedDescription)")
            }
        }

        let sourceFormat = input.outputFormat(forBus: 0)
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

        input.removeTap(onBus: 0)
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

            let enoughAudio = Double(self.samples.count) / self.targetSampleRate >= self.minimumUtteranceSeconds
            if self.automaticFinalize,
               self.hasDetectedSpeech,
               enoughAudio,
               now.timeIntervalSince(self.lastVoiceActivity) >= self.silenceThreshold {
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

    // MARK: Whisper inference

    private func ensureModelLoaded() throws {
        if context != nil { return }

        guard let modelURL = Bundle.main.url(
            forResource: "ggml-base",
            withExtension: "bin",
            subdirectory: "WhisperModels"
        ) else {
            throw NSError(
                domain: "SarahIA.Whisper",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Le modèle OpenAI Whisper n'est pas inclus dans cette installation."]
            )
        }

        var params = whisper_context_default_params()
        #if targetEnvironment(simulator)
        params.use_gpu = false
        #else
        params.use_gpu = true
        params.flash_attn = true
        #endif

        guard let loaded = whisper_init_from_file_with_params(modelURL.path, params) else {
            throw NSError(
                domain: "SarahIA.Whisper",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Impossible de charger le modèle OpenAI Whisper."]
            )
        }
        context = loaded
    }

    private func transcribe(_ audio: [Float], final: Bool, completion: ((String?) -> Void)?) {
        guard !audio.isEmpty else {
            completion?(nil)
            return
        }
        inferenceQueue.async { [weak self] in
            guard let self, let context = self.context else {
                DispatchQueue.main.async { completion?(nil) }
                return
            }

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

            let result: Int32 = "auto".withCString { language in
                params.language = language
                return audio.withUnsafeBufferPointer { pointer in
                    whisper_full(context, params, pointer.baseAddress, Int32(audio.count))
                }
            }

            guard result == 0 else {
                DispatchQueue.main.async {
                    self.lastError = "Whisper n'a pas pu transcrire cet extrait."
                    self.isFinalizing = false
                    completion?(nil)
                }
                return
            }

            let count = whisper_full_n_segments(context)
            var pieces: [String] = []
            if count > 0 {
                for index in 0..<count {
                    if let cText = whisper_full_get_segment_text(context, index) {
                        let text = String(cString: cText).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !text.isEmpty { pieces.append(text) }
                    }
                }
            }
            let text = pieces.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)

            DispatchQueue.main.async {
                self.currentText = text
                self.isFinalizing = false
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
