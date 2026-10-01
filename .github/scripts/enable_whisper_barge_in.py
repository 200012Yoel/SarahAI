from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def write(rel: str, text: str) -> None:
    (ROOT / rel).write_text(text, encoding="utf-8")


def sub_once(text: str, pattern: str, replacement: str, label: str) -> str:
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f"{label}: expected one match, found {count}")
    return updated


# -----------------------------------------------------------------------------
# WhisperService: voice-processing I/O + sustained speech onset.
# iOS .voiceChat plus AVAudioIONode voice processing supplies acoustic echo
# cancellation, so Sarah's own TTS is far less likely to trip barge-in.
# -----------------------------------------------------------------------------
rel = "SarahIA/SarahIA/Services/WhisperService.swift"
s = read(rel)

if "private var consecutiveVoiceFrames = 0" not in s:
    s = s.replace(
        "    private var lastBargeInNotification = Date.distantPast\n",
        "    private var lastBargeInNotification = Date.distantPast\n"
        "    private var consecutiveVoiceFrames = 0\n"
        "    private var voiceActivityLatched = false\n",
        1,
    )

s = s.replace(
    "        hasDetectedSpeech = false\n        samples.removeAll(keepingCapacity: true)\n",
    "        hasDetectedSpeech = false\n"
    "        consecutiveVoiceFrames = 0\n"
    "        voiceActivityLatched = false\n"
    "        samples.removeAll(keepingCapacity: true)\n",
    1,
)

voice_processing_anchor = """        let input = audioEngine.inputNode
        let sourceFormat = input.outputFormat(forBus: 0)
"""
voice_processing_replacement = """        let input = audioEngine.inputNode

        // Full-duplex voice mode uses Apple's Voice Processing I/O. Combined with
        // AVAudioSession .voiceChat this gives us acoustic echo cancellation while
        // Whisper keeps listening during Sarah's own speech.
        if AudioSessionManager.shared.isContinuousVoiceSessionActive {
            do {
                if !input.isVoiceProcessingEnabled {
                    try input.setVoiceProcessingEnabled(true)
                }
            } catch {
                print("⚠️ [Whisper] Voice processing unavailable: \\(error.localizedDescription)")
            }
        }

        let sourceFormat = input.outputFormat(forBus: 0)
"""
if voice_processing_replacement not in s:
    if voice_processing_anchor not in s:
        raise SystemExit("Whisper voice-processing anchor missing")
    s = s.replace(voice_processing_anchor, voice_processing_replacement, 1)

old_vad = """            if db >= self.activityDBThreshold {
                self.hasDetectedSpeech = true
                self.lastVoiceActivity = now
                if now.timeIntervalSince(self.lastBargeInNotification) > 0.22 {
                    self.lastBargeInNotification = now
                    DispatchQueue.main.async {
                        self.onVoiceActivity?()
                    }
                }
            }
"""
new_vad = """            if db >= self.activityDBThreshold {
                self.consecutiveVoiceFrames += 1
                self.lastVoiceActivity = now

                // Roughly 100–150 ms of sustained speech is enough to interrupt,
                // while isolated speaker leakage/clicks are ignored.
                if self.consecutiveVoiceFrames >= 3 {
                    self.hasDetectedSpeech = true
                    if !self.voiceActivityLatched {
                        self.voiceActivityLatched = true
                        self.lastBargeInNotification = now
                        DispatchQueue.main.async {
                            self.onVoiceActivity?()
                        }
                    }
                }
            } else {
                self.consecutiveVoiceFrames = 0
            }
"""
if new_vad not in s:
    if old_vad not in s:
        raise SystemExit("Whisper VAD block missing")
    s = s.replace(old_vad, new_vad, 1)

s = s.replace(
    "            hasDetectedSpeech = false\n            isFinalizing = false\n",
    "            hasDetectedSpeech = false\n"
    "            consecutiveVoiceFrames = 0\n"
    "            voiceActivityLatched = false\n"
    "            isFinalizing = false\n",
    1,
)
write(rel, s)


# -----------------------------------------------------------------------------
# MultiAgentVoiceManager: do not stop Whisper in continuous voice mode.
# Keep the .voiceChat session unchanged while TTS plays.
# -----------------------------------------------------------------------------
rel = "SarahIA/SarahIA/Services/MultiAgentVoiceManager.swift"
s = read(rel)

if "public private(set) var currentSpokenText" not in s:
    s = s.replace(
        "    private let synthesizer = AVSpeechSynthesizer()\n",
        "    private let synthesizer = AVSpeechSynthesizer()\n"
        "    public private(set) var currentSpokenText: String = \"\"\n",
        1,
    )

s = s.replace(
    """        // Ne jamais laisser reconnaissance + synthèse tourner en même temps.
        // Deux AVAudioEngine concurrents peuvent provoquer du routage audio instable
        // et des ralentissements à l'échelle du téléphone.
        WhisperSpeechRecognizer.shared.stopListening()
        stop()
""",
    """        // In continuous voice mode Whisper intentionally stays live so the
        // user can interrupt Sarah. Outside voice mode we keep single-source audio.
        if !AudioSessionManager.shared.isContinuousVoiceSessionActive {
            WhisperSpeechRecognizer.shared.stopListening()
        }
        stop()
""",
    1,
)

manual_session = re.compile(
    r"        do \{\n            let session = AVAudioSession\.sharedInstance\(\)\n"
    r"            try session\.setCategory\(\.playAndRecord, mode: \.default, options: \[\.defaultToSpeaker, \.allowBluetooth\]\)\n"
    r"            try session\.setActive\(true, options: \.notifyOthersOnDeactivation\)\n"
    r"            try session\.overrideOutputAudioPort\(\.speaker\)\n"
    r"        \} catch \{\n            print\(\"⚠️ \[AgentVoiceManager\] Erreur configuration AVAudioSession: \\\\(error\.localizedDescription\)\"\)\n"
    r"        \}\n"
)
s, _ = manual_session.subn("        AudioSessionManager.shared.configurePlaybackSession()\n", s, count=1)

if "currentSpokenText = cleaned" not in s:
    s = s.replace(
        "        print(\"🔊 [AgentVoiceManager] Synthèse vocale [\\(agent.rawValue)] via \\(resolvedVoice?.name ?? \"fr-FR\") | ID: \\(resolvedVoice?.identifier ?? \"\")\")\n        synthesizer.speak(utterance)\n",
        "        currentSpokenText = cleaned\n"
        "        print(\"🔊 [AgentVoiceManager] Synthèse vocale [\\(agent.rawValue)] via \\(resolvedVoice?.name ?? \"fr-FR\") | ID: \\(resolvedVoice?.identifier ?? \"\")\")\n"
        "        synthesizer.speak(utterance)\n",
        1,
    )

s = s.replace(
    """    public func speakHandoff(transitionText: String, sourceAgent: AgentType, agentGreeting: String, targetAgent: AgentType) {
        WhisperSpeechRecognizer.shared.stopListening()
        stop()
""",
    """    public func speakHandoff(transitionText: String, sourceAgent: AgentType, agentGreeting: String, targetAgent: AgentType) {
        if !AudioSessionManager.shared.isContinuousVoiceSessionActive {
            WhisperSpeechRecognizer.shared.stopListening()
        }
        stop()
""",
    1,
)

if "self.currentSpokenText = cleanAgent" not in s:
    s = s.replace(
        "            self.synthesizer.speak(agentUtterance)\n",
        "            self.currentSpokenText = cleanAgent\n            self.synthesizer.speak(agentUtterance)\n",
        1,
    )
if "currentSpokenText = cleanTransition" not in s:
    s = s.replace(
        "        synthesizer.speak(sourceUtterance)\n    }\n",
        "        currentSpokenText = cleanTransition\n        synthesizer.speak(sourceUtterance)\n    }\n",
        1,
    )

s = s.replace(
    """        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        // Ne jamais conserver la route .playAndRecord une fois la voix coupée.
""",
    """        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        currentSpokenText = ""

        // Ne jamais conserver la route .playAndRecord une fois la voix coupée.
""",
    1,
)

s = s.replace(
    """        } else {
            AudioSessionManager.shared.deactivateSession()
            onSpeechFinished?()
        }
""",
    """        } else {
            currentSpokenText = ""
            AudioSessionManager.shared.deactivateSession()
            onSpeechFinished?()
        }
""",
    1,
)
s = s.replace(
    """    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        AudioSessionManager.shared.deactivateSession()
        onSpeechFinished?()
    }
""",
    """    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        currentSpokenText = ""
        AudioSessionManager.shared.deactivateSession()
        onSpeechFinished?()
    }
""",
    1,
)
write(rel, s)


# -----------------------------------------------------------------------------
# ChatViewModel: ChatGPT-style barge-in.
# Sarah talks while Whisper remains live. Real user voice activity immediately
# cancels TTS; the same captured utterance is then finalized and transcribed.
# -----------------------------------------------------------------------------
rel = "SarahIA/SarahIA/ViewModels/ChatViewModel.swift"
s = read(rel)

partial_block = """        WhisperSpeechRecognizer.shared.onPartialTranscription = { [weak self] partial in
            self?.liveTranscriptionText = partial
        }
"""
activity_block = """        WhisperSpeechRecognizer.shared.onVoiceActivity = { [weak self] in
            guard let self = self,
                  self.isContinuousConversationActive,
                  !self.isVoiceMicrophoneMuted,
                  self.voiceManager.isSpeaking else { return }

            // True barge-in: stop Sarah immediately but keep Whisper recording the
            // user's entire interruption. The final transcript will be sent normally.
            self.voiceManager.stop()
            self.isSpeaking = false
            self.currentSpeakingText = nil
            self.isMicRunning = WhisperSpeechRecognizer.shared.isListening
            self.voiceStatus = .listening(level: self.micInputLevel)
            self.haptics.buttonTap()
        }
"""
if activity_block not in s:
    if partial_block not in s:
        raise SystemExit("ChatViewModel partial transcription block missing")
    s = s.replace(partial_block, partial_block + "\n" + activity_block, 1)

s = sub_once(
    s,
    r"        voiceManager\.onSpeechStarted = \{ \[weak self\] in\n.*?        \}\n\s*\n        voiceManager\.onSpeechFinished =",
    """        voiceManager.onSpeechStarted = { [weak self] in
            guard let self = self else { return }
            self.isSpeaking = true
            self.currentSpeakingText = self.voiceManager.currentSpokenText
            self.voiceStatus = .speaking
            self.haptics.speechStarted()

            if self.isContinuousConversationActive && !self.isVoiceMicrophoneMuted {
                AudioSessionManager.shared.beginContinuousVoiceSession()
                if !WhisperSpeechRecognizer.shared.isListening {
                    WhisperSpeechRecognizer.shared.startListening(
                        autoFinalizeOnSilence: true,
                        preserveActiveSpeech: true
                    )
                }
                self.isMicRunning = WhisperSpeechRecognizer.shared.isListening
            } else {
                WhisperSpeechRecognizer.shared.stopListening()
                self.isMicRunning = false
            }
        }

        voiceManager.onSpeechFinished =""",
    "speech-started barge-in",
)

s = sub_once(
    s,
    r"        voiceManager\.onSpeechFinished = \{ \[weak self\] in\n.*?        \}\n    \}\n\s*\n    public func toggleMicrophone\(\)",
    """        voiceManager.onSpeechFinished = { [weak self] in
            guard let self = self else { return }
            self.isSpeaking = false
            self.currentSpeakingText = nil
            self.haptics.speechFinished()

            guard self.isContinuousConversationActive,
                  !self.isVoiceMicrophoneMuted else {
                self.voiceStatus = .idle
                return
            }

            AudioSessionManager.shared.restoreContinuousVoiceSessionIfNeeded()
            if !WhisperSpeechRecognizer.shared.isListening {
                WhisperSpeechRecognizer.shared.startListening(
                    autoFinalizeOnSilence: true,
                    preserveActiveSpeech: true
                )
            }
            self.isMicRunning = WhisperSpeechRecognizer.shared.isListening
            self.voiceStatus = self.isMicRunning ? .listening(level: self.micInputLevel) : .starting
        }
    }

    public func toggleMicrophone()""",
    "speech-finished barge-in",
)

s = sub_once(
    s,
    r"    public func toggleMicrophone\(\) \{\n.*?    \}\n\s*\n    /// Démarre explicitement une session vocale continue\.",
    """    public func toggleMicrophone() {
        ensureVoicePipelinePrepared()
        haptics.buttonTap()

        if isMicRunning || WhisperSpeechRecognizer.shared.isListening {
            isVoiceMicrophoneMuted = true
            WhisperSpeechRecognizer.shared.stopListening()
            isMicRunning = false
            micInputLevel = 0
            voiceStatus = voiceManager.isSpeaking ? .speaking : .idle
            return
        }

        isVoiceMicrophoneMuted = false
        isContinuousConversationActive = true
        AudioSessionManager.shared.beginContinuousVoiceSession()
        WhisperSpeechRecognizer.shared.startListening(
            autoFinalizeOnSilence: true,
            preserveActiveSpeech: true
        )
        isMicRunning = WhisperSpeechRecognizer.shared.isListening
        voiceStatus = voiceManager.isSpeaking ? .speaking : (isMicRunning ? .listening(level: micInputLevel) : .starting)
    }

    /// Démarre explicitement une session vocale continue.""",
    "toggle microphone full duplex",
)

s = sub_once(
    s,
    r"    public func startVoiceConversation\(\) \{\n.*?    \}\n\s*\n    /// Coupe complètement le mode vocal",
    """    public func startVoiceConversation() {
        ensureVoicePipelinePrepared()
        voiceManager.stop()
        AudioSessionManager.shared.beginContinuousVoiceSession()
        isContinuousConversationActive = true
        isVoiceMicrophoneMuted = false

        if !WhisperSpeechRecognizer.shared.isListening {
            WhisperSpeechRecognizer.shared.startListening(
                autoFinalizeOnSilence: true,
                preserveActiveSpeech: true
            )
        }
        isMicRunning = WhisperSpeechRecognizer.shared.isListening
        voiceStatus = isMicRunning ? .listening(level: micInputLevel) : .starting
    }

    /// Coupe complètement le mode vocal""",
    "start voice full duplex",
)

s = s.replace(
    "        AudioSessionManager.shared.deactivateSession()\n",
    "        AudioSessionManager.shared.endContinuousVoiceSession()\n",
    1,
)
write(rel, s)

print("Whisper full-duplex barge-in enabled")
