from pathlib import Path

vm_path = Path("SarahIA/SarahIA/ViewModels/ChatViewModel.swift")
voice_view_path = Path("SarahIA/SarahIA/Views/VoiceOrbModalView.swift")

vm = vm_path.read_text(encoding="utf-8")
view = voice_view_path.read_text(encoding="utf-8")

# The mic button must pause/resume capture, not tear down the whole voice session.
old_toggle = '''    public func toggleMicrophone() {
        ensureVoicePipelinePrepared()
        haptics.buttonTap()
        if isMicRunning || AppleSpeechRecognizer.shared.isListening {
            stopVoiceConversation(stopSpeech: false)
        } else {
            startVoiceConversation()
        }
    }
'''
new_toggle = '''    public func toggleMicrophone() {
        ensureVoicePipelinePrepared()
        haptics.buttonTap()
        if isMicRunning || AppleSpeechRecognizer.shared.isListening {
            pauseVoiceMicrophone()
        } else {
            resumeVoiceMicrophone()
        }
    }
'''
if old_toggle in vm:
    vm = vm.replace(old_toggle, new_toggle, 1)
elif new_toggle not in vm:
    raise SystemExit("voice reliability: toggleMicrophone anchor not found")

if "public func pauseVoiceMicrophone()" not in vm:
    anchor = '''    /// Démarre explicitement une session vocale continue.
'''
    methods = '''    /// Met uniquement le microphone en pause, sans fermer la feuille vocale
    /// ni perdre le contexte de la conversation en cours.
    public func pauseVoiceMicrophone() {
        ensureVoicePipelinePrepared()
        isVoiceMicrophoneMuted = true
        AppleSpeechRecognizer.shared.stopListening()
        isMicRunning = false
        micInputLevel = 0.0
        liveTranscriptionText = ""
        voiceStatus = voiceManager.isSpeaking ? .speaking : .idle
    }

    /// Réarme le microphone dans la session vocale existante.
    public func resumeVoiceMicrophone() {
        ensureVoicePipelinePrepared()
        isContinuousConversationActive = true
        isVoiceMicrophoneMuted = false

        guard !AppleSpeechRecognizer.shared.isListening else {
            isMicRunning = true
            voiceStatus = .listening(level: micInputLevel)
            return
        }

        voiceStatus = .starting
        AppleSpeechRecognizer.shared.startListening(
            autoFinalizeOnSilence: true,
            preserveActiveSpeech: voiceManager.isSpeaking
        )
        isMicRunning = AppleSpeechRecognizer.shared.isListening
        if isMicRunning {
            voiceStatus = .listening(level: micInputLevel)
        }
    }

    /// Coupe immédiatement la réponse parlée de Sarah tout en gardant le mode vocal.
    public func interruptVoiceResponse() {
        ensureVoicePipelinePrepared()
        voiceManager.stop()
        isSpeaking = false
        currentSpeakingText = nil

        guard isContinuousConversationActive,
              isShowingVoiceOrbModal,
              !isVoiceMicrophoneMuted else {
            voiceStatus = .idle
            return
        }

        resumeVoiceMicrophone()
    }

'''
    if anchor not in vm:
        raise SystemExit("voice reliability: startVoiceConversation anchor not found")
    vm = vm.replace(anchor, methods + anchor, 1)

# During the asynchronous model warm-up, show a truthful 'starting' state instead
# of pretending the microphone is switched off.
vm = vm.replace(
    '        voiceStatus = isMicRunning ? .listening(level: 0.0) : .idle\n',
    '        voiceStatus = isMicRunning ? .listening(level: 0.0) : .starting\n',
    1,
)
vm = vm.replace(
    '            self.voiceStatus = self.isMicRunning ? .listening(level: self.micInputLevel) : .idle\n',
    '            self.voiceStatus = self.isMicRunning ? .listening(level: self.micInputLevel) : .starting\n',
    1,
)

# Stopping the sheet must always reset a previous manual mute.
stop_anchor = '''    public func stopVoiceConversation(stopSpeech: Bool = true) {
        isContinuousConversationActive = false
'''
stop_replacement = '''    public func stopVoiceConversation(stopSpeech: Bool = true) {
        isContinuousConversationActive = false
        isVoiceMicrophoneMuted = false
'''
if stop_anchor in vm:
    vm = vm.replace(stop_anchor, stop_replacement, 1)
elif stop_replacement not in vm:
    raise SystemExit("voice reliability: stopVoiceConversation anchor not found")

# Voice UI states: distinguish model warm-up from an actually muted microphone.
old_title = '''        switch viewModel.voiceStatus {
        case .processing:
            return "Je réfléchis…"
        case .speaking:
            return "Sarah parle"
        case .error:
            return "Micro indisponible"
        default:
'''
new_title = '''        switch viewModel.voiceStatus {
        case .starting:
            return "Whisper démarre…"
        case .processing:
            return "Je réfléchis…"
        case .speaking:
            return "Sarah parle"
        case .error:
            return "Micro indisponible"
        default:
'''
if old_title in view:
    view = view.replace(old_title, new_title, 1)
elif new_title not in view:
    raise SystemExit("voice reliability: statusTitle anchor not found")

old_subtitle = '''        switch viewModel.voiceStatus {
        case .error:
            return "Touchez le micro pour réessayer"
        case .processing:
            return "Un instant…"
        case .speaking:
            return "Tu peux interrompre Sarah en touchant le micro"
        default:
'''
new_subtitle = '''        switch viewModel.voiceStatus {
        case .starting:
            return "Préparation du modèle local…"
        case .error:
            return "Touchez le micro pour réessayer"
        case .processing:
            return "Un instant…"
        case .speaking:
            return "Tu peux interrompre Sarah en touchant l’orbe"
        default:
'''
if old_subtitle in view:
    view = view.replace(old_subtitle, new_subtitle, 1)
elif new_subtitle not in view:
    raise SystemExit("voice reliability: statusSubtitle anchor not found")

# Stable accessibility identifiers let Maestro prove that the sheet really changes
# between the large and 255-pt compact presentations.
expanded_orb = '''            orb(size: 292)
                .frame(width: 320, height: 320)
'''
expanded_orb_testable = '''            orb(size: 292)
                .frame(width: 320, height: 320)
                .accessibilityIdentifier("sarah.voice.orb.expanded")
'''
if expanded_orb in view:
    view = view.replace(expanded_orb, expanded_orb_testable, 1)
elif expanded_orb_testable not in view:
    raise SystemExit("voice reliability: expanded orb anchor not found")

compact_orb = '''            orb(size: 86)
                .frame(width: 112, height: 112)
'''
compact_orb_testable = '''            orb(size: 86)
                .frame(width: 112, height: 112)
                .accessibilityIdentifier("sarah.voice.orb.compact")
'''
if compact_orb in view:
    view = view.replace(compact_orb, compact_orb_testable, 1)
elif compact_orb_testable not in view:
    raise SystemExit("voice reliability: compact orb anchor not found")

# Tapping the orb while Sarah is speaking means 'interrupt and listen'. Otherwise
# it toggles mic pause/resume without closing the voice sheet.
old_orb_action = '''        .onTapGesture {
            HapticService.shared.buttonTap()
            if viewModel.isMicRunning {
                viewModel.toggleMicrophone()
            } else {
                viewModel.startVoiceConversation()
            }
        }
'''
new_orb_action = '''        .onTapGesture {
            HapticService.shared.buttonTap()
            if viewModel.isSpeaking {
                viewModel.interruptVoiceResponse()
            } else {
                viewModel.toggleMicrophone()
            }
        }
'''
if old_orb_action in view:
    view = view.replace(old_orb_action, new_orb_action, 1)
elif new_orb_action not in view:
    raise SystemExit("voice reliability: orb action anchor not found")

vm_path.write_text(vm, encoding="utf-8")
voice_view_path.write_text(view, encoding="utf-8")

assert "public func pauseVoiceMicrophone()" in vm
assert "public func resumeVoiceMicrophone()" in vm
assert "Whisper démarre…" in view
assert "sarah.voice.orb.compact" in view
assert "interruptVoiceResponse()" in view
print("Whisper voice reliability polish applied")
