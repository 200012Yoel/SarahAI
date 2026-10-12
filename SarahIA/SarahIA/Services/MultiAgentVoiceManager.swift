import Foundation

/// All agent speech is generated locally by a neural engine.
/// AVFoundation is used only for PCM playback and microphone capture elsewhere.
@available(iOS 15.0, *)
public final class AgentVoiceManager: NSObject {
    public static let shared = AgentVoiceManager()

    public private(set) var currentSpokenText: String = ""
    public var onSpeechStarted: (() -> Void)?
    public var onSpeechFinished: (() -> Void)?
    public var onSpeechError: ((String) -> Void)?

    private let neural = NeuralVoiceService.shared
    private var pendingSpeechBlock: (() -> Void)?
    private var websiteTexts: [String] = []
    private var websiteIndex = 0
    private var websiteAgent: AgentType?
    private var websiteItemStart: ((Int) -> Void)?
    private var websiteCompletion: (() -> Void)?

    private override init() {
        super.init()
        neural.onStarted = { [weak self] in
            self?.onSpeechStarted?()
        }
        neural.onFinished = { [weak self] in
            self?.finishSpeech()
        }
        neural.onFailure = { [weak self] message in
            print("⚠️ [Sarah Neuronal TTS] \(message)")
            self?.onSpeechError?(message)
        }
    }

    public func cleanTextForSpeech(_ text: String) -> String {
        text
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "—", with: "")
            .replacingOccurrences(of: "•", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A distinct Supertonic 3 voice ID is assigned to each agent.
    public func speak(text: String, as agent: AgentPersona, rate: Float = 1.0) {
        speak(text: text, for: agent, rate: rate)
    }

    public func speak(text: String, for agent: AgentType) {
        speak(text: text, for: agent, rate: 1.0)
    }

    private func speak(text: String, for agent: AgentType, rate: Float) {
        // An old chat completion must never steal the single speech engine
        // while Yoann interprets an external television broadcast.
        guard !AudioSessionManager.shared.isInterpreterSessionActive else { return }
        if !AudioSessionManager.shared.isContinuousVoiceSessionActive {
            WhisperSpeechRecognizer.shared.stopListening()
        }
        stop()
        let cleaned = cleanTextForSpeech(text)
        guard !cleaned.isEmpty else { return }
        currentSpokenText = cleaned
        neural.speak(text: cleaned, for: agent, speed: rate)
    }

    public func speakHandoff(
        transitionText: String,
        sourceAgent: AgentType,
        agentGreeting: String,
        targetAgent: AgentType
    ) {
        guard !AudioSessionManager.shared.isInterpreterSessionActive else { return }
        stop()
        let first = cleanTextForSpeech(transitionText)
        let second = cleanTextForSpeech(agentGreeting)
        guard !first.isEmpty else {
            speak(text: second, for: targetAgent)
            return
        }
        pendingSpeechBlock = { [weak self] in
            self?.speak(text: second, for: targetAgent)
        }
        currentSpokenText = first
        neural.speak(text: first, for: sourceAgent)
    }

    public func speakSequence(
        texts: [String],
        for agent: AgentType,
        onItemStart: @escaping (Int) -> Void,
        completion: @escaping () -> Void
    ) {
        guard !AudioSessionManager.shared.isInterpreterSessionActive else { return }
        stop()
        let cleaned = texts.map(cleanTextForSpeech).filter { !$0.isEmpty }
        guard !cleaned.isEmpty else {
            completion()
            return
        }
        websiteTexts = cleaned
        websiteIndex = 0
        websiteAgent = agent
        websiteItemStart = onItemStart
        websiteCompletion = completion
        nextWebsiteItem()
    }

    private func nextWebsiteItem() {
        guard let agent = websiteAgent, websiteIndex < websiteTexts.count else { return }
        let text = websiteTexts[websiteIndex]
        currentSpokenText = text
        websiteItemStart?(websiteIndex)
        neural.speak(text: text, for: agent)
    }

    private func finishSpeech() {
        if let next = pendingSpeechBlock {
            pendingSpeechBlock = nil
            next()
            return
        }
        if websiteAgent != nil {
            websiteIndex += 1
            if websiteIndex < websiteTexts.count {
                nextWebsiteItem()
                return
            }
            let finished = websiteCompletion
            clearSequence()
            currentSpokenText = ""
            finished?()
        } else {
            currentSpokenText = ""
        }
        onSpeechFinished?()
    }

    private func clearSequence() {
        websiteTexts.removeAll()
        websiteIndex = 0
        websiteAgent = nil
        websiteItemStart = nil
        websiteCompletion = nil
    }

    public func stop() {
        pendingSpeechBlock = nil
        clearSequence()
        currentSpokenText = ""
        neural.stop()
    }

    public var isSpeaking: Bool { neural.isSpeaking }
}
public typealias MultiAgentVoiceManager = AgentVoiceManager
