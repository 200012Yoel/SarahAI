from pathlib import Path

ROOT = Path('.')
VM = ROOT / 'SarahIA/SarahIA/ViewModels/ChatViewModel.swift'
CHAT = ROOT / 'SarahIA/SarahIA/Views/ChatScreenView.swift'


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'Missing anchor: {label}')
    return text.replace(old, new, 1)

vm = VM.read_text(encoding='utf-8')

# Keep microphone mute state coherent with the full-screen controls.
vm = replace_once(
    vm,
    '''    public func startVoiceConversation() {\n        ensureVoicePipelinePrepared()\n        voiceManager.stop()\n        isContinuousConversationActive = true\n\n        guard !AppleSpeechRecognizer.shared.isListening else {\n''',
    '''    public func startVoiceConversation() {\n        ensureVoicePipelinePrepared()\n        voiceManager.stop()\n        isContinuousConversationActive = true\n        isVoiceMicrophoneMuted = false\n\n        guard !AppleSpeechRecognizer.shared.isListening else {\n''',
    'startVoiceConversation mute state'
)

# Add pause/resume/interrupt API used by the restored full-screen voice UI.
if 'public func pauseVoiceMicrophone()' not in vm:
    anchor = '''    /// Coupe complètement le mode vocal et rend la session audio à iOS.\n'''
    methods = '''    /// Met uniquement le micro en pause sans fermer la session vocale.\n    public func pauseVoiceMicrophone() {\n        ensureVoicePipelinePrepared()\n        isVoiceMicrophoneMuted = true\n        AppleSpeechRecognizer.shared.stopListening()\n        isMicRunning = false\n        micInputLevel = 0.0\n        liveTranscriptionText = \"\"\n        voiceStatus = voiceManager.isSpeaking ? .speaking : .idle\n    }\n\n    /// Réarme le micro dans la session vocale plein écran.\n    public func resumeVoiceMicrophone() {\n        ensureVoicePipelinePrepared()\n        isContinuousConversationActive = true\n        isVoiceMicrophoneMuted = false\n\n        guard !voiceManager.isSpeaking else {\n            voiceStatus = .speaking\n            return\n        }\n\n        guard !AppleSpeechRecognizer.shared.isListening else {\n            isMicRunning = true\n            voiceStatus = .listening(level: micInputLevel)\n            return\n        }\n\n        voiceStatus = .starting\n        AppleSpeechRecognizer.shared.startListening(autoFinalizeOnSilence: true)\n        isMicRunning = AppleSpeechRecognizer.shared.isListening\n        if isMicRunning {\n            voiceStatus = .listening(level: micInputLevel)\n        }\n    }\n\n    /// Interrompt la voix de Sarah mais conserve la conversation vocale ouverte.\n    public func interruptVoiceResponse() {\n        ensureVoicePipelinePrepared()\n        voiceManager.stop()\n        isSpeaking = false\n        currentSpeakingText = nil\n        voiceStatus = .idle\n\n        guard isContinuousConversationActive,\n              isShowingVoiceOrbModal,\n              !isVoiceMicrophoneMuted else { return }\n\n        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in\n            guard let self = self,\n                  self.isContinuousConversationActive,\n                  self.isShowingVoiceOrbModal,\n                  !self.isVoiceMicrophoneMuted,\n                  !AppleSpeechRecognizer.shared.isListening else { return }\n            AppleSpeechRecognizer.shared.startListening(autoFinalizeOnSilence: true)\n            self.isMicRunning = AppleSpeechRecognizer.shared.isListening\n            self.voiceStatus = self.isMicRunning ? .listening(level: self.micInputLevel) : .idle\n        }\n    }\n\n'''
    vm = replace_once(vm, anchor, methods + anchor, 'voice pause/resume methods')

# Stop should reset the mute flag too.
vm = replace_once(
    vm,
    '''    public func stopVoiceConversation(stopSpeech: Bool = true) {\n        isContinuousConversationActive = false\n''',
    '''    public func stopVoiceConversation(stopSpeech: Bool = true) {\n        isContinuousConversationActive = false\n        isVoiceMicrophoneMuted = false\n''',
    'stop voice mute reset'
)

# Do not auto-restart while the user explicitly muted the microphone.
vm = replace_once(
    vm,
    '''            if self.isContinuousConversationActive && self.isShowingVoiceOrbModal {\n                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {\n                    guard self.isContinuousConversationActive,\n                          self.isShowingVoiceOrbModal,\n                          !self.voiceManager.isSpeaking else { return }\n                    AppleSpeechRecognizer.shared.startListening()\n''',
    '''            if self.isContinuousConversationActive && self.isShowingVoiceOrbModal && !self.isVoiceMicrophoneMuted {\n                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {\n                    guard self.isContinuousConversationActive,\n                          self.isShowingVoiceOrbModal,\n                          !self.isVoiceMicrophoneMuted,\n                          !self.voiceManager.isSpeaking else { return }\n                    AppleSpeechRecognizer.shared.startListening(autoFinalizeOnSilence: true)\n''',
    'speech finished restart guard'
)

VM.write_text(vm, encoding='utf-8')

chat = CHAT.read_text(encoding='utf-8')
chat = replace_once(
    chat,
    '''        .sheet(isPresented: $viewModel.isShowingVoiceOrbModal) {\n            voiceSheetContent\n        }\n''',
    '''        .fullScreenCover(isPresented: $viewModel.isShowingVoiceOrbModal) {\n            VoiceOrbModalView(\n                viewModel: viewModel,\n                onOpenMenu: {\n                    viewModel.openDrawer()\n                },\n                onOpenSettings: {\n                    isShowingSettings = true\n                }\n            )\n        }\n''',
    'voice fullScreenCover'
)
CHAT.write_text(chat, encoding='utf-8')

# Safety checks.
assert '.fullScreenCover(isPresented: $viewModel.isShowingVoiceOrbModal)' in chat
assert 'public func pauseVoiceMicrophone()' in vm
assert 'public func resumeVoiceMicrophone()' in vm
assert 'public func interruptVoiceResponse()' in vm
print('Full-screen voice runtime patch applied successfully.')
