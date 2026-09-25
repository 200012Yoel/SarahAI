from pathlib import Path

path = Path('SarahIA/SarahIA/ViewModels/ChatViewModel.swift')
text = path.read_text(encoding='utf-8')

old_final_guard = '''            guard let self = self,
                  self.isContinuousConversationActive,
                  self.isShowingVoiceOrbModal,
                  !self.isVoiceMicrophoneMuted else { return }
'''
new_final_guard = '''            guard let self = self,
                  self.isContinuousConversationActive,
                  !self.isVoiceMicrophoneMuted else { return }
'''

if old_final_guard not in text:
    raise SystemExit('voice final transcription guard not found')
text = text.replace(old_final_guard, new_final_guard, 1)

old_speak_gate = 'let shouldSpeakAutomatically = self.isContinuousConversationActive && self.isShowingVoiceOrbModal'
new_speak_gate = 'let shouldSpeakAutomatically = self.isContinuousConversationActive'
if old_speak_gate not in text:
    raise SystemExit('automatic speech gate not found')
text = text.replace(old_speak_gate, new_speak_gate, 1)

# When a response is ready in continuous voice mode, explicitly keep the voice
# state in processing until AVSpeechSynthesizer reports that speech started.
old_idle = '''                self.isTyping = false
                self.voiceStatus = .idle
                
                // Enregistrer l'échange'''
new_idle = '''                self.isTyping = false
                self.voiceStatus = self.isContinuousConversationActive ? .processing : .idle
                
                // Enregistrer l'échange'''
if old_idle not in text:
    raise SystemExit('response voice status block not found')
text = text.replace(old_idle, new_idle, 1)

path.write_text(text, encoding='utf-8')
print('Voice reply routing repaired')
