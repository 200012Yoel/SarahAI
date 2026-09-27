from pathlib import Path

p = Path("SarahIA/SarahIA/ViewModels/ChatViewModel.swift")
s = p.read_text()
old = '''            let cleaned = finalTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else {
                self.voiceStatus = .idle
                self.resumeVoiceMicrophone()
                return
            }

            self.liveTranscriptionText = ""
            self.sendMessage(cleaned)'''
new = '''            let cleaned = finalTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else {
                self.voiceStatus = .idle
                self.resumeVoiceMicrophone()
                return
            }

            // Tant que la synthèse parle encore, un résultat final peut être l'écho
            // du haut-parleur. Un vrai barge-in coupe la synthèse dès le partiel,
            // donc son résultat final arrive ensuite avec isSpeaking == false.
            guard !self.voiceManager.isSpeaking else {
                self.liveTranscriptionText = ""
                return
            }

            self.liveTranscriptionText = ""
            self.sendMessage(cleaned)'''
if old not in s:
    raise SystemExit("final transcription block not found")
p.write_text(s.replace(old, new, 1))
print("Voice echo guard applied")
