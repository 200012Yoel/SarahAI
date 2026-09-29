from pathlib import Path

path = Path("SarahIA/SarahIA/ViewModels/ChatViewModel.swift")
text = path.read_text()

if "AppleSpeechRecognizer.shared.onVoiceActivity" not in text:
    marker = "        AppleSpeechRecognizer.shared.onFinalTranscription = { [weak self]"
    idx = text.find(marker)
    if idx == -1:
        raise SystemExit("Whisper barge-in: final transcription hook not found")

    block = '''        // Whisper VAD barge-in: AVAudioSession voiceChat performs echo cancellation.
        // Genuine microphone activity can therefore stop Sarah immediately, before
        // the full Whisper transcription has finished.
        AppleSpeechRecognizer.shared.onVoiceActivity = { [weak self] in
            guard let self = self,
                  self.isContinuousConversationActive,
                  !self.isVoiceMicrophoneMuted,
                  self.voiceManager.isSpeaking else { return }

            self.currentSpeakingText = self.voiceManager.currentSpokenText
            self.voiceManager.stop()
            self.isSpeaking = false
            self.voiceStatus = .listening(level: self.micInputLevel)
        }

'''
    text = text[:idx] + block + text[idx:]

path.write_text(text)
print("Whisper VAD barge-in bridge applied")
