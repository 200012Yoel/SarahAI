from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def p(rel: str) -> Path:
    return ROOT / rel


def read(rel: str) -> str:
    return p(rel).read_text(encoding="utf-8")


def write(rel: str, text: str) -> None:
    p(rel).write_text(text, encoding="utf-8")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one old block, found {count}")
    return text.replace(old, new, 1)


# -----------------------------------------------------------------------------
# 1) Whisper VAD: require a tiny amount of sustained voice before barge-in.
# -----------------------------------------------------------------------------
rel = "SarahIA/SarahIA/Services/WhisperService.swift"
s = read(rel)
if "private var consecutiveVoiceChunks = 0" not in s:
    s = s.replace(
        "    private var lastBargeInNotification = Date.distantPast\n",
        "    private var lastBargeInNotification = Date.distantPast\n    private var consecutiveVoiceChunks = 0\n",
        1,
    )
s = s.replace(
    "        hasDetectedSpeech = false\n        samples.removeAll(keepingCapacity: true)",
    "        hasDetectedSpeech = false\n        consecutiveVoiceChunks = 0\n        samples.removeAll(keepingCapacity: true)",
    1,
)
old_vad = '''            if db >= self.activityDBThreshold {
                self.hasDetectedSpeech = true
                self.lastVoiceActivity = now
                if now.timeIntervalSince(self.lastBargeInNotification) > 0.22 {
                    self.lastBargeInNotification = now
                    DispatchQueue.main.async {
                        self.onVoiceActivity?()
                    }
                }
            }
'''
new_vad = '''            if db >= self.activityDBThreshold {
                self.hasDetectedSpeech = true
                self.consecutiveVoiceChunks += 1
                self.lastVoiceActivity = now
                if self.consecutiveVoiceChunks >= 2,
                   now.timeIntervalSince(self.lastBargeInNotification) > 0.18 {
                    self.lastBargeInNotification = now
                    DispatchQueue.main.async {
                        self.onVoiceActivity?()
                    }
                }
            } else {
                self.consecutiveVoiceChunks = 0
            }
'''
s = replace_once(s, old_vad, new_vad, "Whisper sustained VAD")
s = s.replace(
    "            hasDetectedSpeech = false\n            isFinalizing = false",
    "            hasDetectedSpeech = false\n            consecutiveVoiceChunks = 0\n            isFinalizing = false",
    1,
)
write(rel, s)


# -----------------------------------------------------------------------------
# 2) TTS manager: in continuous voice mode, do NOT shut Whisper down.
#    Track Sarah's spoken text for echo-aware diagnostics and interruption state.
# -----------------------------------------------------------------------------
rel = "SarahIA/SarahIA/Services/MultiAgentVoiceManager.swift"
s = read(rel)
if "public private(set) var currentSpokenText: String = \"\"" not in s:
    s = s.replace(
        "    private let synthesizer = AVSpeechSynthesizer()\n",
        "    private let synthesizer = AVSpeechSynthesizer()\n    public private(set) var currentSpokenText: String = \"\"\n",
        1,
    )
old_start = '''        // Ne jamais laisser reconnaissance + synthèse tourner en même temps.
        // Deux AVAudioEngine concurrents peuvent provoquer du routage audio instable
        // et des ralentissements à l'échelle du téléphone.
        WhisperSpeechRecognizer.shared.stopListening()
        stop()
'''
new_start = '''        // Hors mode vocal continu, on conserve le comportement mono-source.
        // En mode vocal continu, Whisper reste volontairement en écoute afin que
        // l'utilisateur puisse interrompre Sarah à n'importe quel moment.
        if !AudioSessionManager.shared.isContinuousVoiceSessionActive {
            WhisperSpeechRecognizer.shared.stopListening()
        }
        stop()
'''
s = replace_once(s, old_start, new_start, "preserve Whisper during continuous TTS")
old_session = '''        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            try session.overrideOutputAudioPort(.speaker)
        } catch {
            print("⚠️ [AgentVoiceManager] Erreur configuration AVAudioSession: \\(error.localizedDescription)")
        }
'''
if old_session in s:
    s = s.replace(old_session, "        AudioSessionManager.shared.configurePlaybackSession()\n", 1)
if "        currentSpokenText = cleaned\n        print(\"🔊 [AgentVoiceManager]" not in s:
    s = s.replace(
        "        print(\"🔊 [AgentVoiceManager] Synthèse vocale [\\(agent.rawValue)] via \\(resolvedVoice?.name ?? \"fr-FR\") | ID: \\(resolvedVoice?.identifier ?? \"\")\")\n        synthesizer.speak(utterance)",
        "        currentSpokenText = cleaned\n        print(\"🔊 [AgentVoiceManager] Synthèse vocale [\\(agent.rawValue)] via \\(resolvedVoice?.name ?? \"fr-FR\") | ID: \\(resolvedVoice?.identifier ?? \"\")\")\n        synthesizer.speak(utterance)",
        1,
    )
old_handoff = '''    public func speakHandoff(transitionText: String, sourceAgent: AgentType, agentGreeting: String, targetAgent: AgentType) {
        WhisperSpeechRecognizer.shared.stopListening()
        stop()
'''
new_handoff = '''    public func speakHandoff(transitionText: String, sourceAgent: AgentType, agentGreeting: String, targetAgent: AgentType) {
        if !AudioSessionManager.shared.isContinuousVoiceSessionActive {
            WhisperSpeechRecognizer.shared.stopListening()
        }
        stop()
'''
s = replace_once(s, old_handoff, new_handoff, "handoff preserves Whisper")
if "            self.currentSpokenText = cleanAgent\n            self.synthesizer.speak(agentUtterance)" not in s:
    s = s.replace(
        "            self.synthesizer.speak(agentUtterance)",
        "            self.currentSpokenText = cleanAgent\n            self.synthesizer.speak(agentUtterance)",
        1,
    )
if "        currentSpokenText = cleanTransition\n        synthesizer.speak(sourceUtterance)" not in s:
    s = s.replace(
        "        synthesizer.speak(sourceUtterance)\n    }\n    \n    public func stop()",
        "        currentSpokenText = cleanTransition\n        synthesizer.speak(sourceUtterance)\n    }\n    \n    public func stop()",
        1,
    )
if "        currentSpokenText = \"\"\n\n        // Ne jamais conserver" not in s:
    s = s.replace(
        "        if synthesizer.isSpeaking {\n            synthesizer.stopSpeaking(at: .immediate)\n        }\n\n        // Ne jamais conserver",
        "        if synthesizer.isSpeaking {\n            synthesizer.stopSpeaking(at: .immediate)\n        }\n        currentSpokenText = \"\"\n\n        // Ne jamais conserver",
        1,
    )
s = s.replace(
    "        } else {\n            AudioSessionManager.shared.deactivateSession()\n            onSpeechFinished?()\n        }",
    "        } else {\n            currentSpokenText = \"\"\n            AudioSessionManager.shared.deactivateSession()\n            onSpeechFinished?()\n        }",
    1,
)
s = s.replace(
    "    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {\n        AudioSessionManager.shared.deactivateSession()",
    "    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {\n        currentSpokenText = \"\"\n        AudioSessionManager.shared.deactivateSession()",
    1,
)
write(rel, s)


# -----------------------------------------------------------------------------
# 3) Chat voice loop: full-duplex barge-in.
#    Sarah speaks while Whisper remains armed. Genuine mic activity cuts TTS
#    immediately; Whisper keeps recording the user's new sentence.
# -----------------------------------------------------------------------------
rel = "SarahIA/SarahIA/ViewModels/ChatViewModel.swift"
s = read(rel)
final_marker = "        WhisperSpeechRecognizer.shared.onFinalTranscription = { [weak self] finalTranscription in\n"
if "WhisperSpeechRecognizer.shared.onVoiceActivity = { [weak self] in" not in s:
    if final_marker not in s:
        raise SystemExit("ChatViewModel final-transcription marker missing")
    barge = '''        WhisperSpeechRecognizer.shared.onVoiceActivity = { [weak self] in
            guard let self = self,
                  self.isContinuousConversationActive,
                  !self.isVoiceMicrophoneMuted,
                  self.isBargeInMonitorActive,
                  self.voiceManager.isSpeaking else { return }

            // AVAudioSession .voiceChat fournit l'annulation d'écho. Dès qu'une
            // vraie voix traverse le VAD Whisper, Sarah s'arrête immédiatement,
            // mais Whisper continue d'enregistrer la nouvelle phrase utilisateur.
            self.currentSpeakingText = self.voiceManager.currentSpokenText
            self.isBargeInMonitorActive = false
            self.voiceManager.stop()
            self.isSpeaking = false
            self.voiceStatus = .listening(level: self.micInputLevel)
        }

'''
    s = s.replace(final_marker, barge + final_marker, 1)

old_speech_started = '''        voiceManager.onSpeechStarted = { [weak self] in
            WhisperService.shared.stopRecordingWithoutTranscription()
            self?.isMicRunning = false
            self?.isSpeaking = true
            self?.voiceStatus = .speaking
            self?.haptics.speechStarted()
        }
'''
new_speech_started = '''        voiceManager.onSpeechStarted = { [weak self] in
            guard let self = self else { return }
            self.isSpeaking = true
            self.currentSpeakingText = self.voiceManager.currentSpokenText
            self.voiceStatus = .speaking
            self.haptics.speechStarted()

            guard self.isContinuousConversationActive,
                  !self.isVoiceMicrophoneMuted else {
                self.isBargeInMonitorActive = false
                self.isMicRunning = false
                return
            }

            self.isBargeInMonitorActive = true
            AudioSessionManager.shared.restoreContinuousVoiceSessionIfNeeded()
            if !WhisperSpeechRecognizer.shared.isListening {
                WhisperSpeechRecognizer.shared.startListening(
                    autoFinalizeOnSilence: true,
                    preserveActiveSpeech: true
                )
            }
            self.isMicRunning = WhisperSpeechRecognizer.shared.isListening
        }
'''
s = replace_once(s, old_speech_started, new_speech_started, "full-duplex speech start")

old_finished = '''        voiceManager.onSpeechFinished = { [weak self] in
            guard let self = self else { return }
            self.isSpeaking = false
            self.voiceStatus = .idle
            self.haptics.speechFinished()
            
            if self.isContinuousConversationActive && !self.isVoiceMicrophoneMuted {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    guard self.isContinuousConversationActive,
                          !self.isVoiceMicrophoneMuted,
                          !self.voiceManager.isSpeaking else { return }
                    WhisperSpeechRecognizer.shared.startListening()
                    self.isMicRunning = WhisperSpeechRecognizer.shared.isListening
                    self.voiceStatus = self.isMicRunning ? .listening(level: 0.0) : .idle
                }
            }
        }
'''
new_finished = '''        voiceManager.onSpeechFinished = { [weak self] in
            guard let self = self else { return }
            self.isSpeaking = false
            self.currentSpeakingText = nil
            self.haptics.speechFinished()

            let finishedWithoutBargeIn = self.isBargeInMonitorActive
            self.isBargeInMonitorActive = false

            guard self.isContinuousConversationActive,
                  !self.isVoiceMicrophoneMuted else {
                self.voiceStatus = .idle
                return
            }

            if finishedWithoutBargeIn {
                // Sarah a fini normalement. On jette le tampon utilisé uniquement
                // pour surveiller une interruption afin qu'aucun résidu d'écho ne
                // devienne un faux message, puis on repart sur une capture propre.
                WhisperSpeechRecognizer.shared.stopListening()
                self.isMicRunning = false
                self.voiceStatus = .starting
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                    guard self.isContinuousConversationActive,
                          !self.isVoiceMicrophoneMuted,
                          !self.voiceManager.isSpeaking else { return }
                    WhisperSpeechRecognizer.shared.startListening(
                        autoFinalizeOnSilence: true,
                        preserveActiveSpeech: true
                    )
                    self.isMicRunning = WhisperSpeechRecognizer.shared.isListening
                    self.voiceStatus = self.isMicRunning ? .listening(level: self.micInputLevel) : .starting
                }
            } else {
                // Barge-in : Whisper est déjà en train d'enregistrer l'utilisateur.
                self.isMicRunning = WhisperSpeechRecognizer.shared.isListening
                self.voiceStatus = self.isMicRunning ? .listening(level: self.micInputLevel) : .starting
            }
        }
'''
s = replace_once(s, old_finished, new_finished, "clean barge-in speech finish")

# Opening the voice conversation establishes one stable voiceChat session.
old_start_voice = '''        ensureVoicePipelinePrepared()
        voiceManager.stop()
        isContinuousConversationActive = true
        isVoiceMicrophoneMuted = false
'''
new_start_voice = '''        ensureVoicePipelinePrepared()
        voiceManager.stop()
        AudioSessionManager.shared.beginContinuousVoiceSession()
        isContinuousConversationActive = true
        isVoiceMicrophoneMuted = false
        isBargeInMonitorActive = false
'''
s = replace_once(s, old_start_voice, new_start_voice, "begin continuous voice session")
s = s.replace(
    "        WhisperSpeechRecognizer.shared.startListening()\n        isMicRunning = WhisperSpeechRecognizer.shared.isListening\n        voiceStatus = isMicRunning ? .listening(level: 0.0) : .starting",
    "        WhisperSpeechRecognizer.shared.startListening(\n            autoFinalizeOnSilence: true,\n            preserveActiveSpeech: true\n        )\n        isMicRunning = WhisperSpeechRecognizer.shared.isListening\n        voiceStatus = isMicRunning ? .listening(level: 0.0) : .starting",
    1,
)
# Fully ending voice mode, unlike compacting it, releases the shared session.
s = s.replace(
    "        isContinuousConversationActive = false\n        isVoiceMicrophoneMuted = false\n",
    "        isContinuousConversationActive = false\n        isVoiceMicrophoneMuted = false\n        isBargeInMonitorActive = false\n",
    1,
)
s = s.replace(
    "        WhisperSpeechRecognizer.shared.stopListening()\n        AudioSessionManager.shared.deactivateSession()",
    "        WhisperSpeechRecognizer.shared.stopListening()\n        AudioSessionManager.shared.endContinuousVoiceSession()",
    1,
)
# A final transcript always wins over any remaining speech.
old_final_send = '''            self.liveTranscriptionText = ""
            self.sendMessage(cleaned)
'''
new_final_send = '''            self.liveTranscriptionText = ""
            if self.voiceManager.isSpeaking {
                self.isBargeInMonitorActive = false
                self.voiceManager.stop()
                self.isSpeaking = false
            }
            self.sendMessage(cleaned)
'''
s = replace_once(s, old_final_send, new_final_send, "final transcript interrupts residual TTS")
write(rel, s)

print("Canonical Whisper full-duplex barge-in applied")
