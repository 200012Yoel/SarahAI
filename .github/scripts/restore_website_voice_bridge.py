from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"Missing expected block: {label}")
    return text.replace(old, new, 1)


# -----------------------------------------------------------------------------
# MultiAgentVoiceManager: deterministic TTS sequencing driven by delegate events
# -----------------------------------------------------------------------------
voice_path = Path("SarahIA/SarahIA/Services/MultiAgentVoiceManager.swift")
voice = voice_path.read_text()

state_marker = '''    public var onSpeechStarted: (() -> Void)?
    public var onSpeechFinished: (() -> Void)?
    private var pendingSpeechBlock: (() -> Void)? = nil
'''
state_replacement = '''    public var onSpeechStarted: (() -> Void)?
    public var onSpeechFinished: (() -> Void)?
    private var pendingSpeechBlock: (() -> Void)? = nil

    private var websiteGuideSequenceTexts: [String] = []
    private var websiteGuideSequenceAgent: AgentType? = nil
    private var websiteGuideSequenceIndex: Int = 0
    private var websiteGuideItemStarted: ((Int) -> Void)? = nil
    private var websiteGuideCompletion: (() -> Void)? = nil
    private var isWebsiteGuideSequenceActive = false
    private var suppressNextCancelCallback = false
'''
if "websiteGuideSequenceTexts" not in voice:
    voice = replace_once(voice, state_marker, state_replacement, "voice sequence state")

speak_marker = '''    /// Énonciation vocale dédiée pour l'agent ciblé avec timbre Siri personnalisé
    public func speak(text: String, as agent: AgentPersona, rate: Float = AVSpeechUtteranceDefaultSpeechRate) {
'''
sequence_helpers = '''    private func clearWebsiteGuideSequence() {
        websiteGuideSequenceTexts = []
        websiteGuideSequenceAgent = nil
        websiteGuideSequenceIndex = 0
        websiteGuideItemStarted = nil
        websiteGuideCompletion = nil
        isWebsiteGuideSequenceActive = false
    }

    private func stopForWebsiteGuideReplacement() {
        pendingSpeechBlock = nil
        clearWebsiteGuideSequence()
        if synthesizer.isSpeaking {
            suppressNextCancelCallback = true
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    private func websiteGuideUtterance(text: String, agent: AgentType) -> AVSpeechUtterance {
        let utterance = makeUtterance(text: text)
        utterance.voice = getSiriVoice(for: agent)
        switch agent {
        case .sarah:
            utterance.pitchMultiplier = 1.05
            utterance.rate = 0.51
        case .nathan:
            utterance.pitchMultiplier = 0.95
            utterance.rate = 0.53
        case .esther:
            utterance.pitchMultiplier = 1.12
            utterance.rate = 0.49
        case .tom:
            utterance.pitchMultiplier = 0.84
            utterance.rate = 0.46
        case .yohan:
            utterance.pitchMultiplier = 0.91
            utterance.rate = 0.50
        case .ethel:
            utterance.pitchMultiplier = 1.18
            utterance.rate = 0.48
        }
        return utterance
    }

    private func speakNextWebsiteGuideItem() {
        guard isWebsiteGuideSequenceActive,
              let agent = websiteGuideSequenceAgent,
              websiteGuideSequenceIndex < websiteGuideSequenceTexts.count else { return }

        let index = websiteGuideSequenceIndex
        let text = websiteGuideSequenceTexts[index]
        currentSpokenText = text
        websiteGuideItemStarted?(index)
        AudioSessionManager.shared.configurePlaybackSession()
        synthesizer.speak(websiteGuideUtterance(text: text, agent: agent))
    }

    /// Reads website-builder cards one by one. Advancement is driven exclusively
    /// by AVSpeechSynthesizerDelegate completion, never by guessed timeouts.
    public func speakSequence(
        texts: [String],
        for agent: AgentType,
        onItemStart: @escaping (Int) -> Void,
        completion: @escaping () -> Void
    ) {
        if !AudioSessionManager.shared.isContinuousVoiceSessionActive {
            AppleSpeechRecognizer.shared.stopListening()
        }

        stopForWebsiteGuideReplacement()
        let cleaned = texts.map(cleanTextForSpeech).filter { !$0.isEmpty }
        guard !cleaned.isEmpty else {
            completion()
            return
        }

        websiteGuideSequenceTexts = cleaned
        websiteGuideSequenceAgent = agent
        websiteGuideSequenceIndex = 0
        websiteGuideItemStarted = onItemStart
        websiteGuideCompletion = completion
        isWebsiteGuideSequenceActive = true
        speakNextWebsiteGuideItem()
    }

'''
if "public func speakSequence(" not in voice:
    voice = replace_once(voice, speak_marker, sequence_helpers + speak_marker, "voice speak marker")

# Explicit stop must cancel any pending card sequence.
stop_marker = '''    public func stop() {
        pendingSpeechBlock = nil
'''
stop_replacement = '''    public func stop() {
        pendingSpeechBlock = nil
        clearWebsiteGuideSequence()
'''
if stop_marker in voice and "public func stop() {\n        pendingSpeechBlock = nil\n        clearWebsiteGuideSequence()" not in voice:
    voice = voice.replace(stop_marker, stop_replacement, 1)

old_finish = '''    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if let next = pendingSpeechBlock {
            pendingSpeechBlock = nil
            next()
        } else {
            currentSpokenText = ""
            AudioSessionManager.shared.deactivateSession()
            onSpeechFinished?()
        }
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        currentSpokenText = ""
        AudioSessionManager.shared.deactivateSession()
        onSpeechFinished?()
    }
'''
new_finish = '''    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if let next = pendingSpeechBlock {
            pendingSpeechBlock = nil
            next()
            return
        }

        if isWebsiteGuideSequenceActive {
            websiteGuideSequenceIndex += 1
            if websiteGuideSequenceIndex < websiteGuideSequenceTexts.count {
                speakNextWebsiteGuideItem()
                return
            }

            let completion = websiteGuideCompletion
            clearWebsiteGuideSequence()
            currentSpokenText = ""
            completion?()
            AudioSessionManager.shared.deactivateSession()
            onSpeechFinished?()
            return
        }

        currentSpokenText = ""
        AudioSessionManager.shared.deactivateSession()
        onSpeechFinished?()
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        if suppressNextCancelCallback {
            suppressNextCancelCallback = false
            return
        }
        clearWebsiteGuideSequence()
        currentSpokenText = ""
        AudioSessionManager.shared.deactivateSession()
        onSpeechFinished?()
    }
'''
if "if isWebsiteGuideSequenceActive" not in voice:
    voice = replace_once(voice, old_finish, new_finish, "voice synthesizer delegates")

voice_path.write_text(voice)


# -----------------------------------------------------------------------------
# ChatViewModel: bridge WebsiteBuilderFlowView back to the voice manager
# -----------------------------------------------------------------------------
vm_path = Path("SarahIA/SarahIA/ViewModels/ChatViewModel.swift")
vm = vm_path.read_text()

bridge_marker = '''    public func toggleMicrophone() {
'''
bridge = '''    /// Speaks one contextual instruction from the website builder.
    public func speakWebsiteGuide(_ text: String) {
        ensureVoicePipelinePrepared()
        guard isContinuousConversationActive else { return }
        activeAgent = .esther
        voiceManager.speak(text: text, for: .esther)
    }

    /// Reads card descriptions sequentially. The next highlighted card is selected
    /// only when the previous spoken phrase has actually finished.
    public func speakWebsiteGuideSequence(
        _ texts: [String],
        onItemStart: @escaping (Int) -> Void,
        completion: @escaping () -> Void
    ) {
        ensureVoicePipelinePrepared()
        guard isContinuousConversationActive else {
            completion()
            return
        }
        activeAgent = .esther
        voiceManager.speakSequence(
            texts: texts,
            for: .esther,
            onItemStart: onItemStart,
            completion: completion
        )
    }

    /// Cancels only the current website narration, not the whole voice session.
    public func cancelWebsiteGuideSpeech() {
        guard isContinuousConversationActive else { return }
        voiceManager.stop()
        currentSpeakingText = nil
        isSpeaking = false
        if !isVoiceMicrophoneMuted && !AppleSpeechRecognizer.shared.isListening {
            AppleSpeechRecognizer.shared.startListening(
                autoFinalizeOnSilence: true,
                preserveActiveSpeech: true
            )
        }
    }

'''
if "public func speakWebsiteGuide(" not in vm:
    vm = replace_once(vm, bridge_marker, bridge + bridge_marker, "ChatViewModel toggleMicrophone marker")

vm_path.write_text(vm)
print("website voice bridge restored")
