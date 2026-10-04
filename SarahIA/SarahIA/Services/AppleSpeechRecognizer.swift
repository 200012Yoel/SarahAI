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
public final class WhisperSpeechRecognizer: NSObject {
    public static let shared = WhisperSpeechRecognizer()

    public private(set) var state: SpeechRecognizerState = .idle {
        didSet {
            guard oldValue != state else { return }
            NotificationCenter.default.post(
                name: NSNotification.Name("WhisperSpeechRecognizerStateChanged"),
                object: nil
            )
        }
    }

    public private(set) var isListening = false {
        didSet {
            guard oldValue != isListening else { return }
            NotificationCenter.default.post(
                name: NSNotification.Name("WhisperSpeechRecognizerListeningChanged"),
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
        whisper.$isRecording
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] recording in
                guard let self else { return }
                if recording {
                    let wasListening = self.isListening
                    self.isListening = true
                    self.state = .listening
                    if !wasListening {
                        HapticService.shared.speechStarted()
                    }
                } else if self.isListening {
                    self.isListening = false
                    if self.whisper.isTranscribing || self.whisper.isModelLoading {
                        self.state = .processing
                    } else if case .processing = self.state {
                        return
                    } else {
                        self.state = .idle
                    }
                    HapticService.shared.speechFinished()
                }
            }
            .store(in: &cancellables)

        // Model loading and transcription are real voice states, even when the
        // AVAudioEngine itself is temporarily stopped. Keeping them observable
        // prevents the UI from incorrectly showing "micro off" mid-conversation.
        whisper.$isModelLoading
            .combineLatest(whisper.$isTranscribing)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] values in
                guard let self else { return }
                let (isLoading, isTranscribing) = values
                if isLoading || isTranscribing {
                    if !self.isListening {
                        self.state = .processing
                    }
                } else if !self.isListening,
                          self.whisper.lastError == nil {
                    if case .error = self.state {
                        return
                    }
                    self.state = .idle
                }
            }
            .store(in: &cancellables)

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
                guard let self else { return }
                guard let error, !error.isEmpty else {
                    if !self.isListening,
                       !self.whisper.isModelLoading,
                       !self.whisper.isTranscribing,
                       case .error = self.state {
                        self.state = .idle
                    }
                    return
                }
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
        guard !isListening, !whisper.isTranscribing else { return }
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
        } else if whisper.isModelLoading {
            state = .processing
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
        if case .processing = state, whisper.isTranscribing {
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
            name: NSNotification.Name("WhisperSpeechRecognizerEnergyChanged"),
            object: nil
        )
    }
}

@available(*, deprecated, renamed: "WhisperSpeechRecognizer")
public typealias AppleSpeechRecognizer = WhisperSpeechRecognizer

#if canImport(Combine)
@available(iOS 13.0, *)
public final class ObservableSpeechRecognizer: ObservableObject {
    public static let shared = ObservableSpeechRecognizer()

    @Published public var isListening: Bool = WhisperSpeechRecognizer.shared.isListening
    @Published public var currentLiveText: String = WhisperSpeechRecognizer.shared.currentLiveText
    @Published public var micEnergyLevel: Float = WhisperSpeechRecognizer.shared.micEnergyLevel
    @Published public var state: SpeechRecognizerState = WhisperSpeechRecognizer.shared.state

    private var cancellables = Set<AnyCancellable>()

    private init() {
        NotificationCenter.default.publisher(for: NSNotification.Name("WhisperSpeechRecognizerListeningChanged"))
            .merge(with: NotificationCenter.default.publisher(for: NSNotification.Name("WhisperSpeechRecognizerEnergyChanged")))
            .merge(with: NotificationCenter.default.publisher(for: NSNotification.Name("WhisperSpeechRecognizerStateChanged")))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isListening = WhisperSpeechRecognizer.shared.isListening
                self?.currentLiveText = WhisperSpeechRecognizer.shared.currentLiveText
                self?.micEnergyLevel = WhisperSpeechRecognizer.shared.micEnergyLevel
                self?.state = WhisperSpeechRecognizer.shared.state
            }
            .store(in: &cancellables)
    }
}
#endif
