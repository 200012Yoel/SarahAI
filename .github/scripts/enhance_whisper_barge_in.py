from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def write(rel: str, text: str) -> None:
    (ROOT / rel).write_text(text, encoding="utf-8")


# Whisper audio capture: enable Apple's Voice Processing I/O while the
# continuous .voiceChat session is active. This is the critical AEC layer that
# prevents Sarah's own speaker output from looking like a user interruption.
rel = "SarahIA/SarahIA/Services/WhisperService.swift"
s = read(rel)
old = """        let input = audioEngine.inputNode
        let sourceFormat = input.outputFormat(forBus: 0)
"""
new = """        let input = audioEngine.inputNode

        if AudioSessionManager.shared.isContinuousVoiceSessionActive {
            do {
                if !input.isVoiceProcessingEnabled {
                    try input.setVoiceProcessingEnabled(true)
                }
            } catch {
                print("⚠️ [Whisper] Annulation d'écho iOS indisponible: \\(error.localizedDescription)")
            }
        }

        let sourceFormat = input.outputFormat(forBus: 0)
"""
if new not in s:
    if old not in s:
        raise SystemExit("Whisper input-node anchor missing")
    s = s.replace(old, new, 1)
write(rel, s)


# Unmuting during Sarah's speech must NOT cut Sarah immediately. It merely arms
# Whisper so the user's next spoken words can perform the interruption naturally.
rel = "SarahIA/SarahIA/ViewModels/ChatViewModel.swift"
s = read(rel)
old = """        isVoiceMicrophoneMuted = false
        isContinuousConversationActive = true
        if voiceManager.isSpeaking {
            voiceManager.stop()
        }
        WhisperSpeechRecognizer.shared.startListening()
        isMicRunning = WhisperSpeechRecognizer.shared.isListening
        voiceStatus = isMicRunning ? .listening(level: micInputLevel) : .starting
"""
new = """        isVoiceMicrophoneMuted = false
        isContinuousConversationActive = true
        AudioSessionManager.shared.beginContinuousVoiceSession()
        WhisperSpeechRecognizer.shared.startListening(
            autoFinalizeOnSilence: true,
            preserveActiveSpeech: true
        )
        isMicRunning = WhisperSpeechRecognizer.shared.isListening
        voiceStatus = voiceManager.isSpeaking
            ? .speaking
            : (isMicRunning ? .listening(level: micInputLevel) : .starting)
"""
if new not in s:
    if old not in s:
        raise SystemExit("ChatViewModel unmute block missing")
    s = s.replace(old, new, 1)
write(rel, s)

print("Whisper barge-in echo cancellation hardened")
