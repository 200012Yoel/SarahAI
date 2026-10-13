import Foundation
import Combine

/// Compatibility facade. All actual audio is synthesized by the local neural
/// model; this class no longer constructs AVSpeechSynthesizer instances.
public final class SpeechManager: NSObject {
    public static let shared = SpeechManager()

    public private(set) var isSpeaking = false {
        didSet { publish() }
    }
    public private(set) var currentSpokenText: String? {
        didSet { publish() }
    }
    public var onSpeechStarted: (() -> Void)?
    public var onSpeechFinished: (() -> Void)?
    public var onSpeechInterrupted: (() -> Void)?

    private var token: NSObjectProtocol?

    private override init() {
        super.init()
        token = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SarahNeuralSpeechStateChanged"),
            object: nil, queue: .main
        ) { [weak self] _ in self?.updateStatus() }
    }

    deinit {
        if let token { NotificationCenter.default.removeObserver(token) }
    }

    private func publish() {
        NotificationCenter.default.post(
            name: NSNotification.Name("SarahSpeechStateDidChange"), object: nil
        )
    }

    private func updateStatus() {
        let wasSpeaking = isSpeaking
        isSpeaking = NeuralVoiceService.shared.isSpeaking
        currentSpokenText = isSpeaking ? AgentVoiceManager.shared.currentSpokenText : nil
        if !wasSpeaking && isSpeaking { onSpeechStarted?() }
        if wasSpeaking && !isSpeaking { onSpeechFinished?() }
    }

    public func speak(text: String, pitch: Float = 1.0, rate: Float = 1.0) {
        // pitch intentionally unused: Supertonic speaker ID, not pitch shifting,
        // controls the character of each voice.
        _ = pitch
        AgentVoiceManager.shared.speak(text: text, as: .sarah, rate: rate)
        currentSpokenText = text
    }

    public func stopSpeaking() {
        let wasSpeaking = isSpeaking
        AgentVoiceManager.shared.stop()
        updateStatus()
        if wasSpeaking { onSpeechInterrupted?() }
    }
}

@available(iOS 13.0, *)
public final class ObservableSpeechManager: ObservableObject {
    public static let shared = ObservableSpeechManager()
    @Published public var isSpeaking = SpeechManager.shared.isSpeaking
    @Published public var currentSpokenText: String? = SpeechManager.shared.currentSpokenText
    private var cancellables = Set<AnyCancellable>()
    private init() {
        NotificationCenter.default.publisher(for: NSNotification.Name("SarahSpeechStateDidChange"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isSpeaking = SpeechManager.shared.isSpeaking
                self?.currentSpokenText = SpeechManager.shared.currentSpokenText
            }
            .store(in: &cancellables)
    }
}
