import Foundation
import Speech
import AVFoundation
#if canImport(Combine)
import Combine
#endif

public enum SpeechRecognizerState: Equatable {
    case idle
    case listening
    case processing
    case error(String)
}

/// Reconnaissance vocale Apple utilisée à la fois par le mode conversation et
/// par la dictée de la barre de saisie. Les deux usages ont des fins de phrase
/// différentes : le mode vocal peut valider au silence, la dictée attend le bouton.
public final class AppleSpeechRecognizer: NSObject, SFSpeechRecognizerDelegate {

    public static let shared = AppleSpeechRecognizer()

    public private(set) var state: SpeechRecognizerState = .idle {
        didSet {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("AppleSpeechRecognizerStateChanged"), object: nil)
            }
        }
    }

    public private(set) var isListening: Bool = false {
        didSet {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("AppleSpeechRecognizerListeningChanged"), object: nil)
            }
        }
    }

    public private(set) var currentLiveText: String = ""
    public private(set) var micEnergyLevel: Float = 0.0

    public var onPartialTranscription: ((String) -> Void)?
    public var onFinalTranscription: ((String) -> Void)?

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    private var silenceTimer: Timer?
    private let silenceThreshold: TimeInterval = 1.3
    private var hasDetectedSpeechInCurrentSession = false
    private var automaticallyFinalizeOnSilence = true

    private var lastEnergyPublishTime: TimeInterval = 0
    private let energyPublishInterval: TimeInterval = 1.0 / 20.0

    private override init() {
        super.init()
        speechRecognizer?.delegate = self
    }

    // MARK: - Autorisations

    public func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                        DispatchQueue.main.async { completion(allowed) }
                    }
                default:
                    completion(false)
                }
            }
        }
    }

    // MARK: - Écoute

    /// - Parameter autoFinalizeOnSilence: `true` pour une conversation mains
    /// libres, `false` pour la dictée type ChatGPT qui n'est validée que par
    /// le bouton carré ou le bouton Envoyer.
    public func startListening(autoFinalizeOnSilence: Bool = true) {
        guard !isListening else { return }

        automaticallyFinalizeOnSilence = autoFinalizeOnSilence

        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        if speechStatus == .notDetermined || AVAudioSession.sharedInstance().recordPermission == .undetermined {
            requestAuthorization { [weak self] granted in
                guard granted else {
                    self?.state = .error("Autorisation microphone ou dictée refusée")
                    return
                }
                self?.startListening(autoFinalizeOnSilence: autoFinalizeOnSilence)
            }
            return
        }

        guard speechStatus == .authorized,
              AVAudioSession.sharedInstance().recordPermission == .granted else {
            state = .error("Autorisation microphone ou dictée refusée")
            return
        }

        TTSManager.shared.stop()
        SpeechManager.shared.stopSpeaking()
        if #available(iOS 13.0, *) {
            TTSService.shared.stopSpeaking()
        }

        stopListening()
        automaticallyFinalizeOnSilence = autoFinalizeOnSilence

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            state = .error("Reconnaissance vocale non disponible")
            return
        }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setPreferredIOBufferDuration(0.046)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            state = .error("Micro indisponible")
            print("⚠️ [AppleSpeechRecognizer] AVAudioSession: \(error.localizedDescription)")
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else {
            AudioSessionManager.shared.deactivateSession()
            return
        }

        request.shouldReportPartialResults = true
        if #available(iOS 13.0, *) {
            request.requiresOnDeviceRecognition = false
        }

        let inputNode = audioEngine.inputNode
        let nativeFormat = inputNode.outputFormat(forBus: 0)
        guard nativeFormat.sampleRate > 0, nativeFormat.channelCount > 0 else {
            state = .error("Micro indisponible")
            recognitionRequest = nil
            AudioSessionManager.shared.deactivateSession()
            return
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: nil) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.recognitionRequest?.append(buffer)
            self.calculateAudioEnergy(buffer: buffer)
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let result = result {
                    let text = result.bestTranscription.formattedString
                    self.currentLiveText = text
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.hasDetectedSpeechInCurrentSession = true
                    }
                    self.onPartialTranscription?(text)

                    if self.automaticallyFinalizeOnSilence {
                        self.resetSilenceTimer()
                    }

                    if result.isFinal {
                        if self.automaticallyFinalizeOnSilence {
                            self.finalizeTranscription(text)
                        } else {
                            // En dictée, un résultat « final » provenant de Speech ne doit
                            // jamais envoyer le message tout seul. On arrête simplement le
                            // micro ; MessageBar remettra ce texte dans la zone de saisie.
                            self.stopListening()
                        }
                        return
                    }
                }

                if let error = error {
                    let nsError = error as NSError
                    if nsError.code != 216 && self.isListening {
                        self.state = .error("Reconnaissance vocale interrompue")
                        print("⚠️ [AppleSpeechRecognizer] Recognition: \(error.localizedDescription)")
                    }
                    self.stopListening()
                }
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
            state = .listening
            currentLiveText = ""
            micEnergyLevel = 0.0
            hasDetectedSpeechInCurrentSession = false
            HapticService.shared.speechStarted()
        } catch {
            state = .error("Micro indisponible")
            print("⚠️ [AppleSpeechRecognizer] AVAudioEngine start: \(error.localizedDescription)")
            stopListening()
        }
    }

    public func stopListening() {
        silenceTimer?.invalidate()
        silenceTimer = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        if isListening {
            isListening = false
            state = .idle
            micEnergyLevel = 0.0
            HapticService.shared.speechFinished()
        }

        let session = AVAudioSession.sharedInstance()
        if !MultiAgentVoiceManager.shared.isSpeaking && !SpeechManager.shared.isSpeaking {
            do {
                try session.setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                print("⚠️ [AppleSpeechRecognizer] Désactivation audio: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Finalisation automatique du mode conversation

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        guard automaticallyFinalizeOnSilence else { return }

        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceThreshold, repeats: false) { [weak self] _ in
            guard let self = self,
                  self.isListening,
                  self.hasDetectedSpeechInCurrentSession,
                  self.automaticallyFinalizeOnSilence else { return }
            let finalText = self.currentLiveText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !finalText.isEmpty {
                self.finalizeTranscription(finalText)
            }
        }
    }

    private func finalizeTranscription(_ text: String) {
        let textToSend = text.trimmingCharacters(in: .whitespacesAndNewlines)
        stopListening()
        guard !textToSend.isEmpty else {
            state = .idle
            return
        }
        state = .processing
        HapticService.shared.notificationSuccess()
        onFinalTranscription?(textToSend)
    }

    // MARK: - Niveau réel du micro

    private func calculateAudioEnergy(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return }
        let frameLength = Int(buffer.frameLength)

        var sum: Float = 0.0
        for i in 0..<frameLength {
            let sample = channelData[i]
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(frameLength))
        let db = 20.0 * log10(max(rms, 0.000_001))
        let normalized = min(1.0, max(0.0, (db + 55.0) / 45.0))

        let now = Date().timeIntervalSinceReferenceDate
        guard now - lastEnergyPublishTime >= energyPublishInterval else { return }
        lastEnergyPublishTime = now

        DispatchQueue.main.async {
            guard self.isListening else { return }
            self.micEnergyLevel = normalized
            NotificationCenter.default.post(name: NSNotification.Name("AppleSpeechRecognizerEnergyChanged"), object: nil)
        }
    }

    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if !available {
            stopListening()
            state = .error("Reconnaissance vocale temporairement indisponible")
        }
    }
}

#if canImport(Combine)
@available(iOS 13.0, *)
public final class ObservableSpeechRecognizer: ObservableObject {
    public static let shared = ObservableSpeechRecognizer()

    @Published public var isListening: Bool = AppleSpeechRecognizer.shared.isListening
    @Published public var currentLiveText: String = AppleSpeechRecognizer.shared.currentLiveText
    @Published public var micEnergyLevel: Float = AppleSpeechRecognizer.shared.micEnergyLevel

    private var cancellables = Set<AnyCancellable>()

    private init() {
        NotificationCenter.default.publisher(for: NSNotification.Name("AppleSpeechRecognizerListeningChanged"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isListening = AppleSpeechRecognizer.shared.isListening
                self?.currentLiveText = AppleSpeechRecognizer.shared.currentLiveText
                self?.micEnergyLevel = AppleSpeechRecognizer.shared.micEnergyLevel
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("AppleSpeechRecognizerEnergyChanged"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.micEnergyLevel = AppleSpeechRecognizer.shared.micEnergyLevel
                self?.currentLiveText = AppleSpeechRecognizer.shared.currentLiveText
            }
            .store(in: &cancellables)
    }
}
#endif
