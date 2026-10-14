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
    @Published public private(set) var isTranscribing = false
    @Published public private(set) var currentText = ""
    @Published public private(set) var micEnergyLevel: Float = 0
    @Published public private(set) var isModelReady = false
    @Published public private(set) var isModelLoading = false
    @Published public private(set) var lastError: String?

    public var onPartialTranscription: ((String) -> Void)?
    public var onFinalTranscription: ((String) -> Void)?
    public var onVoiceActivity: (() -> Void)?

    /// Translate Live reads the microphone continuously while Whisper and
    /// neural playback work asynchronously. Separate from normal chat callbacks.
    public var onLiveInterpretationChunk: ((String, Bool) -> Void)?
    /// Used only if the installed iOS Translation framework cannot handle
    /// Hebrew directly. Whisper decodes the SAME audio twice: Hebrew captions
    /// plus an English intermediate for Apple's offline English→French model.
    public var onLiveEnglishPivotChunk: ((String, String, Bool) -> Void)?
    public var liveDualDecodeEnglish = false
    /// Bounded recent verified transcript for Whisper's contextual decoding.
    /// Assign on main thread after a live caption becomes stable.
    public var liveRecognitionContext = ""
    public var onLiveInterpretationError: ((String) -> Void)?
    public var onLiveMicrophoneChanged: ((Bool) -> Void)?
    @Published public private(set) var isLiveInterpreting = false
    private struct LiveChunk {
        let audio: [Float]
        let endsAtPause: Bool
    }
    private var livePendingChunks: [LiveChunk] = []
    private var liveInferenceBusy = false
    private var liveStreamToken = UUID()
    private var liveStartRequested = false

    /// Dedicated Translate Live input settings. Normal chat mode leaves these
    /// at nil / false. Read a snapshot before dispatching on inferenceQueue.
    public var translateSpeechToEnglish = false
    public var preferredLanguageCode: String? = nil

    private let audioEngine = AVAudioEngine()

    /// Check the real audio engine, not the UI's stale microphone flag.
    public var isMicrophoneEngineRunning: Bool {
        audioEngine.isRunning && isRecording
    }
    private let audioQueue = DispatchQueue(label: "sarah.whisper.audio", qos: .userInitiated)
    private let inferenceQueue = DispatchQueue(label: "sarah.whisper.inference", qos: .userInitiated)
    private var converter: AVAudioConverter?
    private var context: OpaquePointer?
    private var loadedModelName: String?
    // Accuracy first: Tiny frequently drops isolated French greetings such
    // as "allô" and misdetects their language. Base is already bundled for
    // Hebrew interpretation; use it for French conversation as well.
    // Keep a single context in RAM and avoid model hot-swaps when switching
    // between Sarah and Yoann.
    private var desiredModelName: String {
        // Base is far too weak for Hebrew (and for translation in general).
        // Translate Live uses the multilingual Medium model when the IPA
        // ships it; ordinary chat keeps the lighter Base model.
        if liveModelRequested,
           Bundle.main.url(forResource: Self.liveModelName, withExtension: "bin",
                           subdirectory: "WhisperModels") != nil {
            return Self.liveModelName
        }
        return "ggml-base"
    }
    private static let liveModelName = "ggml-medium-q5_0"
    private var liveModelRequested = false
    private var samples: [Float] = []
    private var automaticFinalize = true
    private var hasDetectedSpeech = false
    private var lastVoiceActivity = Date.distantPast
    private var lastBargeInNotification = Date.distantPast
    private var consecutiveVoiceChunks = 0
    /// Raised by ChatViewModel when Sarah is audible on the phone speaker.
    /// Speaker echo needs a stronger sustained VAD than isolated headphones.
    public var voiceReplyPlayingOnSpeaker = false
    private var generation = UUID()
    private var isFinalizing = false

    // Whisper can take a moment to initialise on a real iPhone. Never block the
    // main thread: remember the user's intent and start capture as soon as ready.
    private var wantsRecordingAfterModelLoad = false
    private var pendingAutoFinalizeOnSilence = true

    private let targetSampleRate: Double = 16_000
    // Sarah chat: respond after a short, stable pause rather than waiting
    // almost a second on every turn. Translation mode has its own VAD.
    private let silenceThreshold: TimeInterval = 0.47
    private let minimumUtteranceSeconds: Double = 0.25
    // A TV or fan can hold the simple energy VAD open indefinitely.
    // Force French chat to hand off short recorded windows rather than
    // leaving "Je t'écoute" frozen for thirty seconds.
    private let maximumUtteranceSeconds: Double = 7.5
    // TV speech: Whisper needs whole clauses. Short 1–3 s windows cut
    // words in half and made it hallucinate. Flush on a real pause after
    // natural pauses (breathing), or force a cut at 7 s of continuous speech.
    // Increased from 0.38s to allow natural pauses between words without cutting
    private let liveSilenceThreshold: TimeInterval = 0.8
    private let liveMaxChunkSeconds: Double = 7.0
    // Reduced from 2.5s to 1.0s for real-time fluency like ChatGPT
    private let liveMinChunkSeconds: Double = 1.0
    private let activityDBThreshold: Float = -48
    /// Adaptive noise floor for Translate Live: a TV always produces some
    /// sound (music, ambience), so a fixed -48 dB threshold never sees a pause.
    private var liveNoiseFloorDB: Float = -60

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

    /// Starts a reusable continuous microphone stream. There is no per-phrase
    /// stop/start and no need to wait for audio playback. Explicit Stop is the
    /// only normal end of capture; a bounded queue limits inference backlog.
    public func startLiveInterpretation() {
        guard !isLiveInterpreting else { return }
        stopRecordingWithoutTranscription()
        liveStreamToken = UUID()
        livePendingChunks.removeAll()
        liveInferenceBusy = false
        liveRecognitionContext = ""
        liveNoiseFloorDB = -60
        isLiveInterpreting = true
        liveModelRequested = true
        liveStartRequested = true
        AudioSessionManager.shared.beginContinuousVoiceSession()
        startRecording(autoFinalizeOnSilence: false)
    }

    /// iOS can stop AVAudioEngine after a route change or incoming call
    /// without changing our published isRecording flag. Recover the actual
    /// engine rather than showing a false "microphone active" indicator.
    public func recoverLiveMicrophoneIfNeeded() {
        guard isLiveInterpreting else { return }
        guard context != nil else { return } // Initial model load will start it.
        guard !audioEngine.isRunning || !isRecording else { return }
        stopRecordingWithoutTranscription()
        AudioSessionManager.shared.restoreContinuousVoiceSessionIfNeeded()
        startRecording(autoFinalizeOnSilence: false)
    }

    public func stopLiveInterpretation() {
        liveStreamToken = UUID()
        livePendingChunks.removeAll()
        liveInferenceBusy = false
        liveRecognitionContext = ""
        liveStartRequested = false
        isLiveInterpreting = false
        liveModelRequested = false
        stopRecordingWithoutTranscription()
        onLiveInterpretationChunk = nil
        onLiveEnglishPivotChunk = nil
        liveDualDecodeEnglish = false
        onLiveInterpretationError = nil
        onLiveMicrophoneChanged?(false)
        onLiveMicrophoneChanged = nil
    }

    public func prepareModel() {
        guard context == nil || loadedModelName != desiredModelName else {
            isModelReady = true
            return
        }
        prepareModelInBackgroundIfNeeded()
    }

    public func startRecording(autoFinalizeOnSilence: Bool = true) {
        guard !isRecording else { return }
        // The streaming mic is independent from inference. Ordinary dictation
        // still waits for its previous transcription to finish.
        guard isLiveInterpreting || !isTranscribing else { return }

        guard AVAudioSession.sharedInstance().recordPermission == .granted else {
            let requestedGeneration = generation
            let requestedLive = isLiveInterpreting
            requestAuthorization { [weak self] granted in
                guard let self, self.generation == requestedGeneration,
                      self.isLiveInterpreting == requestedLive else {
                    // User closed Translate Live or muted during the iOS prompt.
                    // Never reopen the microphone after the explicit Stop.
                    return
                }
                if granted {
                    self.startRecording(autoFinalizeOnSilence: autoFinalizeOnSilence)
                } else {
                    self.lastError = "Autorisation microphone refusée"
                    if self.isLiveInterpreting {
                        self.onLiveInterpretationError?(self.lastError ?? "Micro refusé")
                    }
                }
            }
            return
        }

        if context == nil || loadedModelName != desiredModelName {
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
        guard context == nil || loadedModelName != desiredModelName else {
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
                    if self.isLiveInterpreting {
                        self.onLiveInterpretationError?(error.localizedDescription)
                    }
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
        lastBargeInNotification = .distantPast
        generation = UUID()
        let currentGeneration = generation

        AudioSessionManager.shared.configureRecordingSession()

        let input = audioEngine.inputNode
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        input.removeTap(onBus: 0)

        if isLiveInterpreting && AudioSessionManager.shared.isRawInterpreterCapture {
            // Subtitle mode: nothing is played back, so no echo to cancel.
            // Voice processing would treat the distant TV as noise.
            do {
                if input.isVoiceProcessingEnabled {
                    try input.setVoiceProcessingEnabled(false)
                }
            } catch {
                print("⚠️ [Whisper] Désactivation du traitement vocal impossible: \(error.localizedDescription)")
            }
        } else if AudioSessionManager.shared.isContinuousVoiceSessionActive {
            do {
                if !input.isVoiceProcessingEnabled {
                    try input.setVoiceProcessingEnabled(true)
                }
            } catch {
                print("⚠️ [Whisper] Annulation d'écho iOS indisponible: \(error.localizedDescription)")
            }
        }

        // AVAudioInputNode exposes microphone buffers on OUTPUT bus zero.
        // inputFormat(forBus:) is not the format delivered to installTap and can
        // be zero / incompatible on an actual iPhone (especially iOS betas).
        // Query only after the audio session and voice-processing mode settle.
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
            if isLiveInterpreting { onLiveInterpretationError?(lastError ?? "") }
            return
        }
        self.converter = converter

        // format:nil follows the hardware's actual tap format after route changes.
        input.installTap(onBus: 0, bufferSize: 2048, format: nil) { [weak self] buffer, _ in
            self?.consume(buffer: buffer, targetFormat: targetFormat, generation: currentGeneration)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            lastError = nil
            if isLiveInterpreting { onLiveMicrophoneChanged?(true) }
        } catch {
            input.removeTap(onBus: 0)
            self.converter = nil
            lastError = "Impossible de démarrer le microphone : \(error.localizedDescription)"
            if isLiveInterpreting { onLiveInterpretationError?(lastError ?? "") }
            AudioSessionManager.shared.deactivateSession()
        }
    }

    /// On confirmed voice barge-in, discard the audio of Sarah's own
    /// playback recorded before the user's interruption, preserving a
    /// short pre-roll so Whisper can understand the start of their words.
    public func keepOnlyRecentBargeInAudio(seconds: Double = 0.55) {
        let capturedGeneration = generation
        audioQueue.async { [weak self] in
            guard let self, self.generation == capturedGeneration else { return }
            let maxSamples = Int(self.targetSampleRate * seconds)
            if self.samples.count > maxSamples {
                self.samples.removeFirst(self.samples.count - maxSamples)
            }
            self.hasDetectedSpeech = true
            self.lastVoiceActivity = Date()
            self.consecutiveVoiceChunks = 0
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

            // When Sarah is playing through the iPhone speaker, don't
            // mistake her remaining acoustic echo for a user interruption.
            // AVAudioSession.voiceChat + AVAudioEngine voice processing provide
            // platform AEC; require stronger and sustained VAD on speaker.
            // A headphone route uses a much shorter 2-chunk threshold.
            let speakerMonitor = !self.isLiveInterpreting && self.voiceReplyPlayingOnSpeaker
            var effectiveThreshold: Float = speakerMonitor
                ? max(self.activityDBThreshold, -41)
                : self.activityDBThreshold
            if self.isLiveInterpreting {
                // Follow the TV's background level: drop quickly to quiet
                // passages, rise slowly so speech itself is not absorbed.
                // Increased from +7dB to +10dB to better reject background chatter
                if db < self.liveNoiseFloorDB {
                    self.liveNoiseFloorDB = db
                } else {
                    self.liveNoiseFloorDB += 0.01 * (db - self.liveNoiseFloorDB)
                }
                effectiveThreshold = max(-55, self.liveNoiseFloorDB + 10)
            }
            let minimumChunks = speakerMonitor ? 6 : 2
            if db >= effectiveThreshold {
                self.hasDetectedSpeech = true
                self.consecutiveVoiceChunks += 1
                self.lastVoiceActivity = now
                // Retry while speech is sustained: a start-up grace window
                // may ignore the first event, which must NOT permanently
                // disable barge-in until the user pauses and starts over.
                // Reduced from 0.24s to 0.12s for faster, snappier response
                if self.consecutiveVoiceChunks >= minimumChunks,
                   now.timeIntervalSince(self.lastBargeInNotification) > 0.12 {
                    self.lastBargeInNotification = now
                    DispatchQueue.main.async { [weak self] in
                        self?.onVoiceActivity?()
                    }
                }
            } else {
                self.consecutiveVoiceChunks = 0
            }

            DispatchQueue.main.async {
                self.micEnergyLevel = level
            }

            let duration = Double(self.samples.count) / self.targetSampleRate

            if self.isLiveInterpreting {
                // Wait for enough phonetic context for Whisper Base, particularly
                // Hebrew news. Sub-second/2-second chunks were hallucinating
                // repeated words, even with a hard-coded Hebrew language.
                // Short greetings still flush on a genuine pause.
                // Never stop AVAudioEngine here; sample collection and inference
                // run on separate queues.
                let briefPause = self.hasDetectedSpeech
                    && now.timeIntervalSince(self.lastVoiceActivity) >= self.liveSilenceThreshold
                let shouldEmit = self.hasDetectedSpeech
                    && duration >= self.liveMinChunkSeconds
                    && (briefPause || duration >= self.liveMaxChunkSeconds)
                if shouldEmit {
                    let liveChunk = self.samples
                    self.samples.removeAll(keepingCapacity: true)
                    self.hasDetectedSpeech = false
                    self.consecutiveVoiceChunks = 0
                    DispatchQueue.main.async { [weak self] in
                        self?.enqueueLiveChunk(
                            liveChunk, endsAtPause: briefPause, generation: generation
                        )
                    }
                } else if !self.hasDetectedSpeech && duration > 0.8 {
                    // No unbounded memory growth during hours of silence.
                    self.samples.removeAll(keepingCapacity: true)
                }
                return
            }

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

    /// Bounded inference queue: continuous recording never accumulates hours
    /// of audio when the iPhone CPU cannot keep up with real-time speech.
    private func enqueueLiveChunk(
        _ audio: [Float], endsAtPause: Bool, generation: UUID
    ) {
        guard isLiveInterpreting, self.generation == generation else { return }
        // Keep at most two recent audio windows waiting while the current
        // decode runs. Dropping every queued window loses entire TV phrases
        // during ordinary CPU spikes. A strict bound prevents runaway lag.
        livePendingChunks.append(LiveChunk(audio: audio, endsAtPause: endsAtPause))
        if livePendingChunks.count > 2 {
            livePendingChunks.removeFirst(livePendingChunks.count - 2)
            onLiveInterpretationError?("Le direct est plus rapide que le décodage audio. Certains passages ont été ignorés.")
        }
        drainLiveChunks(generation: generation)
    }

    private func drainLiveChunks(generation: UUID) {
        guard isLiveInterpreting, self.generation == generation,
              !liveInferenceBusy, !livePendingChunks.isEmpty else { return }
        liveInferenceBusy = true
        let next = livePendingChunks.removeFirst()
        // The busy flag belongs to the live stream, not to one microphone
        // capture: a route change or interruption restarts capture with a
        // new generation while a decode is still running. Releasing it only
        // on a matching generation left Translate Live deaf forever.
        let streamToken = liveStreamToken
        transcribe(
            next.audio, final: true, deliverToLive: true,
            endsAtPause: next.endsAtPause
        ) { [weak self] _ in
            guard let self, self.isLiveInterpreting, self.liveStreamToken == streamToken else { return }
            self.liveInferenceBusy = false
            self.drainLiveChunks(generation: self.generation)
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
        if isLiveInterpreting { onLiveMicrophoneChanged?(false) }
        if !MultiAgentVoiceManager.shared.isSpeaking {
            AudioSessionManager.shared.deactivateSession()
        }
    }

    // MARK: Whisper inference

    private func ensureModelLoaded() throws {
        // Inference runs on one serial queue. Do not retain both Whisper
        // contexts in RAM on an iPhone 14: release the previous model before
        // loading the one needed by this particular voice screen.
        let requestedName = desiredModelName
        if context != nil && loadedModelName == requestedName { return }
        if let old = context {
            whisper_free(old)
            context = nil
            loadedModelName = nil
        }
        guard let modelURL = Bundle.main.url(
            forResource: requestedName,
            withExtension: "bin",
            subdirectory: "WhisperModels"
        ) else {
            throw NSError(
                domain: "SarahIA.Whisper",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Modèle OpenAI Whisper \(requestedName) absent. Installe une IPA complète."]
            )
        }

        func load(useGPU: Bool, flashAttention: Bool) -> OpaquePointer? {
            var params = whisper_context_default_params()
            params.use_gpu = useGPU
            params.flash_attn = flashAttention
            return whisper_init_from_file_with_params(modelURL.path, params)
        }

        #if targetEnvironment(simulator)
        let loaded = load(useGPU: false, flashAttention: false)
        #else
        // Some iOS/device combinations reject Flash Attention or Metal context
        // creation. Falling back keeps voice mode usable instead of failing outright.
        let loaded = load(useGPU: true, flashAttention: true)
            ?? load(useGPU: true, flashAttention: false)
            ?? load(useGPU: false, flashAttention: false)
        #endif

        guard let loaded else {
            throw NSError(
                domain: "SarahIA.Whisper",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Impossible de charger le modèle OpenAI Whisper."]
            )
        }
        context = loaded
        loadedModelName = requestedName
    }

    private func transcribe(
        _ audio: [Float], final: Bool,
        deliverToLive: Bool = false,
        endsAtPause: Bool = true,
        completion: ((String?) -> Void)?
    ) {
        guard !audio.isEmpty else {
            completion?(nil)
            return
        }

        // Preserve every recorded sample; append only silence when a short
        // "allô" clip is too brief for robust Whisper decoding.
        var inferenceAudio = audio
        if !deliverToLive {
            let minimumSamples = Int(targetSampleRate * 1.4)
            if inferenceAudio.count < minimumSamples {
                inferenceAudio.append(contentsOf: repeatElement(
                    Float(0), count: minimumSamples - inferenceAudio.count
                ))
            }
        }

        // Stopping/reopening the voice screen invalidates any in-flight
        // transcription so stale microphone data can never send a chat message.
        let transcriptionGeneration = generation
        isTranscribing = true
        let useEnglishTranslation = translateSpeechToEnglish
        let dualDecodeEnglish = deliverToLive && liveDualDecodeEnglish && !useEnglishTranslation
        // Force French for short conversational utterances. Whisper's
        // automatic language detection is unreliable on tiny fragments
        // ("allô", "bonjour") even when the model itself is multilingual.
        // Translate Live must keep its explicit Hebrew source language.
        let inferenceLanguage = deliverToLive
            ? (preferredLanguageCode ?? "auto")
            : (preferredLanguageCode ?? "fr")
        // Reinjecting the last Whisper hypothesis into the next 2-second
        // TV chunk caused feedback hallucinations ("תודה רבה" dozens of
        // times). Preserve context at the interpreter level instead; live
        // microphone recognition must start each short chunk unprompted.
        let recentPrompt = ""
        inferenceQueue.async { [weak self] in
            guard let self, let context = self.context else {
                DispatchQueue.main.async {
                    self?.isTranscribing = false
                    completion?(nil)
                }
                return
            }

            let threadCount = Int32(max(1, min(8, ProcessInfo.processInfo.activeProcessorCount - 2)))
            var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
            params.print_realtime = false
            params.print_progress = false
            params.print_timestamps = false
            params.print_special = false
            params.translate = useEnglishTranslation
            params.no_context = true
            params.single_segment = !deliverToLive
            params.n_threads = threadCount
            if !deliverToLive {
                // Keep one conversational request bounded; non-speech
                // should never turn into an unbounded assistant prompt.
                params.max_tokens = 96
                params.suppress_blank = true
                params.suppress_nst = true
            }
            params.temperature_inc = -1
            if deliverToLive {
                // Cap live TV decodes and suppress music tokens.
                // These flags are available in pinned whisper.cpp v1.9.4.
                params.max_tokens = 112
                params.suppress_blank = true
                params.suppress_nst = true
                params.no_speech_thold = 0.45
            }

            let result: Int32 = inferenceLanguage.withCString { language in
                params.language = language
                // Whisper's real C API supports initial_prompt; its UTF-8
                // pointer must remain alive for the WHOLE whisper_full call.
                // Keep no_context enabled so prior unrelated chats do not leak.
                if recentPrompt.isEmpty {
                    return inferenceAudio.withUnsafeBufferPointer { pointer in
                        whisper_full(context, params, pointer.baseAddress, Int32(inferenceAudio.count))
                    }
                }
                return recentPrompt.withCString { prompt in
                    params.initial_prompt = prompt
                    return inferenceAudio.withUnsafeBufferPointer { pointer in
                        whisper_full(context, params, pointer.baseAddress, Int32(inferenceAudio.count))
                    }
                }
            }

            guard result == 0 else {
                DispatchQueue.main.async {
                    self.lastError = "Whisper n'a pas pu transcrire cet extrait."
                    if deliverToLive {
                        self.onLiveInterpretationError?(self.lastError ?? "Erreur Whisper")
                    }
                    self.isFinalizing = false
                    self.isTranscribing = false
                    completion?(nil)
                }
                return
            }

            let count = whisper_full_n_segments(context)
            var pieces: [String] = []
            if count > 0 {
                for index in 0..<count {
                    // The microphone energy detector also triggers on television
                    // music and background noise. Reject Whisper segments that
                    // the model itself marks as likely non-speech before the
                    // words reach captions, Qwen or French speech synthesis.
                    // Normal Sarah conversation keeps its existing behavior.
                    if deliverToLive {
                        let noSpeech = whisper_full_get_segment_no_speech_prob(context, index)
                        if noSpeech.isFinite && noSpeech >= 0.72 { continue }
                    }
                    if let cText = whisper_full_get_segment_text(context, index) {
                        let text = String(cString: cText).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !text.isEmpty { pieces.append(text) }
                    }
                }
            }
            let text = pieces.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)

            // A second decode is only enabled for the Hebrew→English→French
            // fallback. Never replace the actual Hebrew source caption with
            // the intermediate English text.
            var englishPivot: String? = nil
            if dualDecodeEnglish, !text.isEmpty,
               !TranslateLiveContextBuffer.isUnreliableTranscript(text),
               (inferenceLanguage != "he" ||
                    TranslateLiveContextBuffer.isMostlyHebrew(text)) {
                var englishParams = params
                englishParams.translate = true
                // Without an English prompt, Whisper often "translates"
                // short Hebrew greetings by spelling them in Latin letters
                // ("Shalom, Manishem…"). A neutral English style prompt keeps
                // the output in real English words. It describes the task,
                // so it is never mistaken for words heard on the microphone.
                let englishStylePrompt = "The following is a natural English translation of everyday Hebrew speech."
                let englishResult: Int32 = inferenceLanguage.withCString { language in
                    englishParams.language = language
                    return englishStylePrompt.withCString { prompt in
                        englishParams.initial_prompt = prompt
                        return inferenceAudio.withUnsafeBufferPointer { pointer in
                            whisper_full(context, englishParams, pointer.baseAddress, Int32(inferenceAudio.count))
                        }
                    }
                }
                if englishResult == 0 {
                    let englishCount = whisper_full_n_segments(context)
                    var englishPieces: [String] = []
                    if englishCount > 0 {
                        for index in 0..<englishCount {
                            if let value = whisper_full_get_segment_text(context, index) {
                                let fragment = String(cString: value)
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                                if !fragment.isEmpty { englishPieces.append(fragment) }
                            }
                        }
                    }
                    let candidate = englishPieces.joined(separator: " ")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let echoedPrompt = candidate.lowercased()
                        .contains("natural english translation of everyday hebrew")
                    if !echoedPrompt,
                       !TranslateLiveContextBuffer.isSuspiciousEnglishPivot(
                            candidate, hebrewSource: text
                        ),
                       candidate.range(of: "[A-Za-z]", options: .regularExpression) != nil {
                        englishPivot = candidate
                    }
                }
            }

            DispatchQueue.main.async {
                self.isFinalizing = false
                self.isTranscribing = false
                guard self.generation == transcriptionGeneration else {
                    completion?(nil)
                    return
                }
                // Clear stale subtitles if a segment was decoded but every
                // hypothesis was rejected as non-speech. Never feed it to Qwen.
                if deliverToLive && count > 0 && text.isEmpty {
                    self.onLiveInterpretationError?("Whisper : aucune parole fiable dans cet extrait.")
                }
                self.currentText = text
                if deliverToLive {
                    if dualDecodeEnglish, !text.isEmpty {
                        // Always deliver the original words (Hebrew script) so
                        // they can be shown; the English relay may be empty.
                        self.onLiveEnglishPivotChunk?(text, englishPivot ?? "", endsAtPause)
                    } else if !text.isEmpty {
                        self.onLiveInterpretationChunk?(text, endsAtPause)
                    }
                } else if final {
                    // An empty transcription is still the end of an utterance.
                    self.onFinalTranscription?(text)
                } else if !text.isEmpty {
                    self.onPartialTranscription?(text)
                }
                completion?(text.isEmpty ? nil : text)
            }
        }
    }
}
