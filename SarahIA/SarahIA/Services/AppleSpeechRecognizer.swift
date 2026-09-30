import Foundation
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

/// Compatibility facade kept so the rest of SarahIA does not need a risky rename.
/// The old SFSpeechRecognizer backend has been removed: transcription is now done
/// locally by WhisperService using OpenAI Whisper model weights through whisper.cpp.
public final class AppleSpeechRecognizer: NSObject {
    public static let shared = AppleSpeechRecognizer()

    public private(set) var state: SpeechRecognizerState = .idle {
        didSet {
            NotificationCenter.default.post(
                name: NSNotification.Name("AppleSpeechRecognizerStateChanged"),
                object: nil
            )
        }
    }

    public private(set) var isListening = false {
        didSet {
            NotificationCenter.default.post(
                name: NSNotification.Name("AppleSpeechRecognizerListeningChanged"),
                object: nil
            )
        }
    }

    public private(set) var currentLiveText = ""
    public private(set) var micEnergyLevel: Float = 0

    public var onPartialTranscription: ((String) -> Void)?
    public var onFinalTranscription: ((String) -> Void)?
    public var onVoiceActivity: (() -> Void)?

    private let whisper = WhisperService.shared
    private var preserveActiveSpeech = false
    private var suppressNextExternalFinalCallback = false

    #if canImport(Combine)
    private var cancellables = Set<AnyCancellable>()
    #endif

    private override init() {
        super.init()

        whisper.onPartialTranscription = { [weak self] text in
            guard let self else { return }
            self.currentLiveText = text
            self.onPartialTranscription?(text)
            self.publishEnergyChange()
        }

        whisper.onFinalTranscription = { [weak self] text in
            guard let self else { return }
            self.currentLiveText = text
            self.isListening = false
            self.state = .processing
            HapticService.shared.notificationSuccess()
            if self.suppressNextExternalFinalCallback {
                self.suppressNextExternalFinalCallback = false
            } else {
                self.onFinalTranscription?(text)
            }
            self.state = .idle
        }

        whisper.onVoiceActivity = { [weak self] in
            self?.onVoiceActivity?()
        }

        #if canImport(Combine)
        whisper.$micEnergyLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                guard let self else { return }
                self.micEnergyLevel = level
                self.publishEnergyChange()
            }
            .store(in: &cancellables)

        whisper.$lastError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                guard let self, let error, !error.isEmpty else { return }
                self.suppressNextExternalFinalCallback = false
                self.state = .error(error)
                self.isListening = false
            }
            .store(in: &cancellables)
        #endif
    }

    public func requestAuthorization(completion: @escaping (Bool) -> Void) {
        whisper.requestAuthorization(completion: completion)
    }

    /// Starts local Whisper capture. In continuous voice mode `preserveActiveSpeech`
    /// keeps Sarah's TTS playing so microphone voice activity can barge in instantly.
    public func startListening(autoFinalizeOnSilence: Bool = true, preserveActiveSpeech: Bool = false) {
        guard !isListening else { return }
        self.preserveActiveSpeech = preserveActiveSpeech
        self.suppressNextExternalFinalCallback = false

        if !preserveActiveSpeech {
            MultiAgentVoiceManager.shared.stop()
            if SpeechManager.shared.isSpeaking {
                SpeechManager.shared.stopSpeaking()
            }
        }

        let permission = AVAudioSession.sharedInstance().recordPermission
        if permission == .undetermined {
            requestAuthorization { [weak self] granted in
                guard let self else { return }
                guard granted else {
                    self.state = .error("Autorisation microphone refusée")
                    return
                }
                self.startListening(
                    autoFinalizeOnSilence: autoFinalizeOnSilence,
                    preserveActiveSpeech: preserveActiveSpeech
                )
            }
            return
        }
        guard permission == .granted else {
            state = .error("Autorisation microphone refusée")
            return
        }

        currentLiveText = ""
        micEnergyLevel = 0
        whisper.startRecording(autoFinalizeOnSilence: autoFinalizeOnSilence)

        if whisper.isRecording {
            isListening = true
            state = .listening
            HapticService.shared.speechStarted()
        } else if let error = whisper.lastError {
            state = .error(error)
        }
    }

    public func stopListening() {
        suppressNextExternalFinalCallback = false
        whisper.stopRecordingWithoutTranscription()
        if isListening {
            isListening = false
            HapticService.shared.speechFinished()
        }
        micEnergyLevel = 0
        if case .processing = state {
            return
        }
        state = .idle
        publishEnergyChange()
    }

    /// Used by manual dictation controls that want the captured phrase before stop.
    /// This path deliberately suppresses the global final-transcription callback so
    /// dictating into the composer never auto-sends a chat message after voice mode
    /// has previously been used.
    public func stopListeningAndTranscribe(completion: @escaping (String?) -> Void) {
        suppressNextExternalFinalCallback = true
        state = .processing
        whisper.stopRecordingAndTranscribe { [weak self] text in
            guard let self else {
                completion(text)
                return
            }
            self.isListening = false
            self.suppressNextExternalFinalCallback = false
            self.micEnergyLevel = 0
            if let text, !text.isEmpty {
                self.currentLiveText = text
            }
            self.state = .idle
            self.publishEnergyChange()
            completion(text)
        }
    }

    private func publishEnergyChange() {
        NotificationCenter.default.post(
            name: NSNotification.Name("AppleSpeechRecognizerEnergyChanged"),
            object: nil
        )
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
            .merge(with: NotificationCenter.default.publisher(for: NSNotification.Name("AppleSpeechRecognizerEnergyChanged")))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isListening = AppleSpeechRecognizer.shared.isListening
                self?.currentLiveText = AppleSpeechRecognizer.shared.currentLiveText
                self?.micEnergyLevel = AppleSpeechRecognizer.shared.micEnergyLevel
            }
            .store(in: &cancellables)
    }
}
#endif
