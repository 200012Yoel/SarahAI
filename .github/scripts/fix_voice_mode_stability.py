from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
vm_path = ROOT / "SarahIA/SarahIA/ViewModels/ChatViewModel.swift"
voice_view_path = ROOT / "SarahIA/SarahIA/Views/VoiceOrbModalView.swift"

vm = vm_path.read_text(encoding="utf-8")
voice_view = voice_view_path.read_text(encoding="utf-8")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"missing pattern: {label}")
    return text.replace(old, new, 1)


# 1. Track system interruptions so a Siri/call interruption never causes a
# stray microphone restart while the interruption is still active.
vm = replace_once(
    vm,
    "    private var isVoicePipelinePrepared = false\n",
    "    private var isVoicePipelinePrepared = false\n"
    "    private var shouldResumeVoiceAfterSystemInterruption = false\n",
    "voice interruption state",
)

# 2. Replace the complete voice callback wiring with a single deterministic
# state machine. This also serializes system interruption recovery.
setup_pattern = re.compile(
    r"    private func setupVoicePipeline\(\) \{.*?\n    \}\n    \n    public func toggleMicrophone\(\)",
    re.S,
)
setup_replacement = '''    private func setupVoicePipeline() {
        AppleSpeechRecognizer.shared.onPartialTranscription = { [weak self] partial in
            guard let self = self, self.isContinuousConversationActive else { return }
            self.liveTranscriptionText = partial
        }

        AppleSpeechRecognizer.shared.onFinalTranscription = { [weak self] finalTranscription in
            guard let self = self,
                  self.isContinuousConversationActive,
                  self.isShowingVoiceOrbModal,
                  !self.isVoiceMicrophoneMuted else { return }

            let cleaned = finalTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else {
                self.voiceStatus = .idle
                self.resumeVoiceMicrophone()
                return
            }

            self.liveTranscriptionText = ""
            self.sendMessage(cleaned)
        }

        voiceManager.onSpeechStarted = { [weak self] in
            guard let self = self else { return }
            self.isSpeaking = true
            self.isMicRunning = false
            self.voiceStatus = .speaking
            self.haptics.speechStarted()
        }

        voiceManager.onSpeechFinished = { [weak self] in
            guard let self = self else { return }
            self.isSpeaking = false
            self.currentSpeakingText = nil
            self.haptics.speechFinished()

            guard self.isContinuousConversationActive,
                  self.isShowingVoiceOrbModal,
                  !self.isVoiceMicrophoneMuted,
                  !self.shouldResumeVoiceAfterSystemInterruption else {
                self.voiceStatus = .idle
                return
            }

            self.voiceStatus = .starting
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                guard self.isContinuousConversationActive,
                      self.isShowingVoiceOrbModal,
                      !self.isVoiceMicrophoneMuted,
                      !self.shouldResumeVoiceAfterSystemInterruption,
                      !self.voiceManager.isSpeaking,
                      !AppleSpeechRecognizer.shared.isListening else { return }
                self.resumeVoiceMicrophone()
            }
        }

        AudioSessionManager.shared.onInterruptionBegan = { [weak self] in
            guard let self = self else { return }
            let wasActive = self.isContinuousConversationActive && self.isShowingVoiceOrbModal
            self.shouldResumeVoiceAfterSystemInterruption = wasActive
            guard wasActive else { return }

            self.isVoiceMicrophoneMuted = true
            AppleSpeechRecognizer.shared.stopListening()
            self.voiceManager.stop()
            self.isMicRunning = false
            self.micInputLevel = 0
            self.liveTranscriptionText = ""
            self.voiceStatus = .idle
        }

        AudioSessionManager.shared.onInterruptionEnded = { [weak self] in
            guard let self = self else { return }
            guard self.shouldResumeVoiceAfterSystemInterruption,
                  self.isContinuousConversationActive,
                  self.isShowingVoiceOrbModal else {
                self.shouldResumeVoiceAfterSystemInterruption = false
                return
            }

            self.shouldResumeVoiceAfterSystemInterruption = false
            self.isVoiceMicrophoneMuted = false
            AudioSessionManager.shared.restoreContinuousVoiceSessionIfNeeded()
            self.resumeVoiceMicrophone()
        }
    }

    public func toggleMicrophone()'''
vm, count = setup_pattern.subn(setup_replacement, vm, count=1)
if count != 1:
    raise SystemExit("failed to replace setupVoicePipeline")

# 3. Start exactly one continuous AVAudioSession and ignore duplicate starts.
start_pattern = re.compile(
    r"    public func startVoiceConversation\(\) \{.*?\n    \}\n\n    /// Met uniquement le micro",
    re.S,
)
start_replacement = '''    public func startVoiceConversation() {
        ensureVoicePipelinePrepared()

        if isContinuousConversationActive {
            AudioSessionManager.shared.restoreContinuousVoiceSessionIfNeeded()
            if voiceManager.isSpeaking {
                voiceStatus = .speaking
            } else if AppleSpeechRecognizer.shared.isListening {
                isMicRunning = true
                voiceStatus = .listening(level: micInputLevel)
            } else if !isVoiceMicrophoneMuted {
                resumeVoiceMicrophone()
            }
            return
        }

        voiceManager.stop()
        AppleSpeechRecognizer.shared.stopListening()
        AudioSessionManager.shared.beginContinuousVoiceSession()

        isContinuousConversationActive = true
        isVoiceMicrophoneMuted = false
        shouldResumeVoiceAfterSystemInterruption = false
        liveTranscriptionText = ""
        micInputLevel = 0
        voiceStatus = .starting

        AppleSpeechRecognizer.shared.startListening(autoFinalizeOnSilence: true)
        isMicRunning = AppleSpeechRecognizer.shared.isListening
        voiceStatus = isMicRunning ? .listening(level: 0.0) : .idle
    }

    /// Met uniquement le micro'''
vm, count = start_pattern.subn(start_replacement, vm, count=1)
if count != 1:
    raise SystemExit("failed to replace startVoiceConversation")

# 4. Resuming never rebuilds a different audio route.
resume_pattern = re.compile(
    r"    public func resumeVoiceMicrophone\(\) \{.*?\n    \}\n\n    /// Interrompt la voix",
    re.S,
)
resume_replacement = '''    public func resumeVoiceMicrophone() {
        ensureVoicePipelinePrepared()
        guard isShowingVoiceOrbModal else { return }

        isContinuousConversationActive = true
        isVoiceMicrophoneMuted = false
        AudioSessionManager.shared.restoreContinuousVoiceSessionIfNeeded()

        guard !voiceManager.isSpeaking else {
            voiceStatus = .speaking
            return
        }

        guard !AppleSpeechRecognizer.shared.isListening else {
            isMicRunning = true
            voiceStatus = .listening(level: micInputLevel)
            return
        }

        voiceStatus = .starting
        AppleSpeechRecognizer.shared.startListening(autoFinalizeOnSilence: true)
        isMicRunning = AppleSpeechRecognizer.shared.isListening
        voiceStatus = isMicRunning ? .listening(level: micInputLevel) : .idle
    }

    /// Interrompt la voix'''
vm, count = resume_pattern.subn(resume_replacement, vm, count=1)
if count != 1:
    raise SystemExit("failed to replace resumeVoiceMicrophone")

# 5. Closing voice mode is the only place that tears the continuous session down.
stop_pattern = re.compile(
    r"    public func stopVoiceConversation\(stopSpeech: Bool = true\) \{.*?\n    \}\n    \n    public func speakMessage",
    re.S,
)
stop_replacement = '''    public func stopVoiceConversation(stopSpeech: Bool = true) {
        isContinuousConversationActive = false
        isVoiceMicrophoneMuted = true
        shouldResumeVoiceAfterSystemInterruption = false

        if stopSpeech {
            voiceManager.stop()
        }
        AppleSpeechRecognizer.shared.stopListening()
        AudioSessionManager.shared.endContinuousVoiceSession()

        isMicRunning = false
        isSpeaking = false
        currentSpeakingText = nil
        micInputLevel = 0.0
        liveTranscriptionText = ""
        voiceStatus = .idle
        isVoiceMicrophoneMuted = false
    }
    
    public func speakMessage'''
vm, count = stop_pattern.subn(stop_replacement, vm, count=1)
if count != 1:
    raise SystemExit("failed to replace stopVoiceConversation")

# 6. Text chat must stay silent. Automatic TTS is exclusively a voice-mode
# behavior. This removes surprise audio and route changes while typing.
old_speech = '''                if let transitionPart = response.handoffSarahTransition, let agentPart = response.handoffAgentGreeting {
                    let src = response.handoffSourceAgent ?? .sarah
                    self.voiceManager.speakHandoff(transitionText: transitionPart.decodingHTMLEntities(), sourceAgent: src, agentGreeting: agentPart.decodingHTMLEntities(), targetAgent: response.agent)
                } else {
                    let spoken = (response.spokenText.isEmpty ? responseContent : response.spokenText).decodingHTMLEntities()
                    self.voiceManager.speak(text: spoken, for: response.agent)
                }
'''
new_speech = '''                let shouldSpeakAutomatically = self.isContinuousConversationActive && self.isShowingVoiceOrbModal
                if shouldSpeakAutomatically {
                    if let transitionPart = response.handoffSarahTransition,
                       let agentPart = response.handoffAgentGreeting {
                        let src = response.handoffSourceAgent ?? .sarah
                        self.voiceManager.speakHandoff(
                            transitionText: transitionPart.decodingHTMLEntities(),
                            sourceAgent: src,
                            agentGreeting: agentPart.decodingHTMLEntities(),
                            targetAgent: response.agent
                        )
                    } else {
                        let spoken = (response.spokenText.isEmpty ? responseContent : response.spokenText)
                            .decodingHTMLEntities()
                        self.voiceManager.speak(text: spoken, for: response.agent)
                    }
                }
'''
vm = replace_once(vm, old_speech, new_speech, "automatic TTS gate")

# 7. Voice screen recovers after background/foreground instead of remaining
# open with a dead microphone.
voice_view = replace_once(
    voice_view,
    "    @Environment(\\.presentationMode) private var presentationMode\n",
    "    @Environment(\\.presentationMode) private var presentationMode\n"
    "    @Environment(\\.scenePhase) private var scenePhase\n",
    "scenePhase environment",
)

old_background = '''        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            viewModel.stopVoiceConversation()
        }
'''
new_background = '''        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                if viewModel.isShowingVoiceOrbModal {
                    viewModel.startVoiceConversation()
                }
            case .inactive, .background:
                viewModel.stopVoiceConversation()
            @unknown default:
                break
            }
        }
'''
voice_view = replace_once(voice_view, old_background, new_background, "voice lifecycle recovery")

vm_path.write_text(vm, encoding="utf-8")
voice_view_path.write_text(voice_view, encoding="utf-8")
print("voice mode stability patch applied")
