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
    /// True while the offline TTS model is generating audio, before playback starts.
    public private(set) var isPreparingSpeech = false
    public var onSpeechPreparationStarted: (() -> Void)?

    private let neural = NeuralVoiceService.shared
    private var pendingSpeechBlock: (() -> Void)?
    // Short speech segments let Sarah start speaking without waiting for
    // Supertonic to synthesize an entire long response.
    private var pendingSpeechChunks: [String] = []
    private var pendingSpeechAgent: AgentType?
    private var pendingSpeechRate: Float = 1.0
    private var websiteTexts: [String] = []
    private var websiteIndex = 0
    private var websiteAgent: AgentType?
    private var websiteItemStart: ((Int) -> Void)?
    private var websiteCompletion: (() -> Void)?

    private override init() {
        super.init()
        neural.onStarted = { [weak self] in
            self?.isPreparingSpeech = false
            self?.onSpeechStarted?()
        }
        neural.onFinished = { [weak self] in
            self?.isPreparingSpeech = false
            self?.finishSpeech()
        }
        neural.onFailure = { [weak self] message in
            print("⚠️ [Sarah Neuronal TTS] \(message)")
            self?.isPreparingSpeech = false
            self?.pendingSpeechChunks.removeAll()
            self?.pendingSpeechAgent = nil
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

    /// Avoid multi-second silence while a whole paragraph is generated.
    /// Segment on natural sentence boundaries when possible, but cap long
    /// run-on speech so the first audible audio arrives much earlier.
    private func speechChunks(_ text: String, limit: Int = 150) -> [String] {
        let words = text.split(whereSeparator: { $0.isWhitespace })
        var chunks: [String] = []
        var current = ""
        for word in words {
            let term = String(word)
            let proposed = current.isEmpty ? term : current + " " + term
            if !current.isEmpty && proposed.count > limit {
                chunks.append(current)
                current = term
            } else {
                current = proposed
            }
            if current.count >= 65,
               let last = current.last,
               ".!?;:".contains(last) {
                chunks.append(current)
                current = ""
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }

    private func playNextChatChunk() {
        guard let agent = pendingSpeechAgent, !pendingSpeechChunks.isEmpty else {
            pendingSpeechAgent = nil
            return
        }
        let next = pendingSpeechChunks.removeFirst()
        currentSpokenText = next
        isPreparingSpeech = true
        onSpeechPreparationStarted?()
        // Fewer diffusion steps increase responsiveness on A15-class iPhones.
        neural.speak(text: next, for: agent, speed: pendingSpeechRate, qualitySteps: 6)
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
        pendingSpeechChunks = speechChunks(cleaned)
        pendingSpeechAgent = agent
        pendingSpeechRate = rate
        playNextChatChunk()
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
        isPreparingSpeech = true
        onSpeechPreparationStarted?()
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
        isPreparingSpeech = true
        onSpeechPreparationStarted?()
        neural.speak(text: text, for: agent)
    }

    private func finishSpeech() {
        if !pendingSpeechChunks.isEmpty {
            playNextChatChunk()
            return
        }
        pendingSpeechAgent = nil
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
        pendingSpeechChunks.removeAll()
        pendingSpeechAgent = nil
        clearSequence()
        currentSpokenText = ""
        isPreparingSpeech = false
        neural.stop()
    }

    public var isSpeaking: Bool { neural.isSpeaking }
}
public typealias MultiAgentVoiceManager = AgentVoiceManager
