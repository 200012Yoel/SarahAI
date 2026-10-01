from pathlib import Path

vm_path = Path("SarahIA/SarahIA/ViewModels/ChatViewModel.swift")
voice_view_path = Path("SarahIA/SarahIA/Views/VoiceOrbModalView.swift")
content_path = Path("SarahIA/SarahIA/ContentView.swift")
whisper_path = Path("SarahIA/SarahIA/Services/WhisperService.swift")

vm = vm_path.read_text(encoding="utf-8")
view = voice_view_path.read_text(encoding="utf-8")
content = content_path.read_text(encoding="utf-8")
whisper = whisper_path.read_text(encoding="utf-8")

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

# During asynchronous model warm-up, show a truthful starting state instead of
# pretending that the microphone is switched off.
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
        case .error(let message):
            return message
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

# A microphone permission prompt can send willResignActive. Never kill voice mode
# for that transient event; only stop once the app really enters the background.
view = view.replace(
    "UIApplication.willResignActiveNotification",
    "UIApplication.didEnterBackgroundNotification",
    1,
)

# Stable accessibility identifiers let Maestro prove that the sheet really changes
# between the large and compact presentations.
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

# Tapping the orb while Sarah is speaking means interrupt-and-listen. Otherwise it
# toggles mic pause/resume without closing the voice sheet.
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

# Compact means compact. Keep the normal composer but shrink the voice surface to
# a small orb directly above it. Do not waste half the display on status text.
old_compact = '''    private var compactLayout: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 8)

            orb(size: 86)
                .frame(width: 112, height: 112)
                .accessibilityIdentifier("sarah.voice.orb.compact")

            Text(statusTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.82))
                .lineLimit(1)

            composer
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
        }
    }
'''
new_compact = '''    private var compactLayout: some View {
        VStack(spacing: 4) {
            Spacer(minLength: 2)

            orb(size: 64)
                .frame(width: 80, height: 80)
                .accessibilityIdentifier("sarah.voice.orb.compact")

            composer
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
        }
    }
'''
if old_compact in view:
    view = view.replace(old_compact, new_compact, 1)
elif new_compact not in view:
    raise SystemExit("voice reliability: compact layout anchor not found")

# The old 255-pt detent is visibly huge on modern iPhones. 184 pt is enough for
# the 64-pt orb + composer and recreates the small floating voice surface.
if '.presentationDetents([.height(255), .large], selection: $selectedDetent)' in content:
    content = content.replace(
        '.presentationDetents([.height(255), .large], selection: $selectedDetent)',
        '.presentationDetents([.height(184), .large], selection: $selectedDetent)',
        1,
    )
elif '.presentationDetents([.height(184), .large], selection: $selectedDetent)' not in content:
    raise SystemExit("voice reliability: compact detent anchor not found")
content = content.replace(
    'Un glissement vers le bas la réduit à 255 pt ; VoiceOrbModalView',
    'Un glissement vers le bas la réduit à 184 pt ; VoiceOrbModalView',
    1,
)

# Whisper reliability: prefer the deterministic CPU backend on iPhone. Metal is
# faster when it behaves, but a voice assistant that occasionally stays forever on
# “Whisper démarre…” is worse than a short, predictable CPU transcription delay.
old_backend = '''        #if targetEnvironment(simulator)
        params.use_gpu = false
        #else
        params.use_gpu = true
        params.flash_attn = true
        #endif
'''
new_backend = '''        params.use_gpu = false
        params.flash_attn = false
'''
if old_backend in whisper:
    whisper = whisper.replace(old_backend, new_backend, 1)
elif new_backend not in whisper:
    raise SystemExit("voice reliability: Whisper backend anchor not found")

# If model initialisation ever stalls, surface a real error instead of an endless
# starting label. The in-flight load is not cancelled; if it eventually succeeds,
# recording begins automatically because wantsRecordingAfterModelLoad stays true.
watchdog_property_anchor = '''    private var pendingAutoFinalizeOnSilence = true
'''
watchdog_property = '''    private var pendingAutoFinalizeOnSilence = true
    private var modelLoadWatchdogGeneration = UUID()
'''
if watchdog_property_anchor in whisper and "modelLoadWatchdogGeneration" not in whisper:
    whisper = whisper.replace(watchdog_property_anchor, watchdog_property, 1)

load_anchor = '''        isModelLoading = true
        lastError = nil

        inferenceQueue.async { [weak self] in
'''
load_replacement = '''        isModelLoading = true
        lastError = nil
        let watchdogGeneration = UUID()
        modelLoadWatchdogGeneration = watchdogGeneration

        DispatchQueue.main.asyncAfter(deadline: .now() + 12.0) { [weak self] in
            guard let self,
                  self.isModelLoading,
                  self.context == nil,
                  self.modelLoadWatchdogGeneration == watchdogGeneration else { return }
            self.lastError = "Whisper met trop de temps à démarrer. Le chargement continue ; touchez le micro pour réessayer."
        }

        inferenceQueue.async { [weak self] in
'''
if load_anchor in whisper:
    whisper = whisper.replace(load_anchor, load_replacement, 1)
elif "watchdogGeneration = UUID()" not in whisper:
    raise SystemExit("voice reliability: Whisper watchdog anchor not found")

vm_path.write_text(vm, encoding="utf-8")
voice_view_path.write_text(view, encoding="utf-8")
content_path.write_text(content, encoding="utf-8")
whisper_path.write_text(whisper, encoding="utf-8")

assert "public func pauseVoiceMicrophone()" in vm
assert "public func resumeVoiceMicrophone()" in vm
assert "Whisper démarre…" in view
assert "sarah.voice.orb.compact" in view
assert "orb(size: 64)" in view
assert "interruptVoiceResponse()" in view
assert "height(184)" in content
assert "params.use_gpu = false" in whisper
assert "modelLoadWatchdogGeneration" in whisper
print("Whisper voice reliability + compact UI hotfix applied")
