from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def path(rel: str) -> Path:
    return ROOT / rel


def read(rel: str) -> str:
    return path(rel).read_text(encoding="utf-8")


def write(rel: str, text: str) -> None:
    path(rel).write_text(text, encoding="utf-8")


def replace_once_if_present(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count > 1:
        raise SystemExit(f"{label}: expected at most one match, found {count}")
    if count == 1:
        return text.replace(old, new, 1)
    return text


# -----------------------------------------------------------------------------
# 1. The recognizer facade is Whisper, not Apple Speech.
#    Keep an alias only so the unused legacy UIKit controller can still compile.
# -----------------------------------------------------------------------------
rel = "SarahIA/SarahIA/Services/AppleSpeechRecognizer.swift"
s = read(rel)
s = s.replace("public final class AppleSpeechRecognizer: NSObject", "public final class WhisperSpeechRecognizer: NSObject")
s = s.replace("public static let shared = AppleSpeechRecognizer()", "public static let shared = WhisperSpeechRecognizer()")
s = s.replace("AppleSpeechRecognizer.shared", "WhisperSpeechRecognizer.shared")
s = s.replace("AppleSpeechRecognizerStateChanged", "WhisperSpeechRecognizerStateChanged")
s = s.replace("AppleSpeechRecognizerListeningChanged", "WhisperSpeechRecognizerListeningChanged")
s = s.replace("AppleSpeechRecognizerEnergyChanged", "WhisperSpeechRecognizerEnergyChanged")
compat_marker = "\n#if canImport(Combine)\n@available(iOS 13.0, *)\npublic final class ObservableSpeechRecognizer"
if "public typealias AppleSpeechRecognizer = WhisperSpeechRecognizer" not in s:
    if compat_marker not in s:
        raise SystemExit("Whisper compatibility alias marker missing")
    s = s.replace(
        compat_marker,
        "\n@available(*, deprecated, renamed: \"WhisperSpeechRecognizer\")\npublic typealias AppleSpeechRecognizer = WhisperSpeechRecognizer\n" + compat_marker,
        1,
    )
write(rel, s)


# -----------------------------------------------------------------------------
# 2. All active SwiftUI voice code uses the Whisper facade name.
# -----------------------------------------------------------------------------
for rel in [
    "SarahIA/SarahIA/ViewModels/ChatViewModel.swift",
    "SarahIA/SarahIA/Views/MessageBar.swift",
    "SarahIA/SarahIA/Services/SpeechManager.swift",
    "SarahIA/SarahIA/Services/MultiAgentVoiceManager.swift",
    "SarahIA/SarahIA/Services/AIService.swift",
]:
    s = read(rel)
    s = s.replace("AppleSpeechRecognizer.shared", "WhisperSpeechRecognizer.shared")
    s = s.replace("AppleSpeechRecognizerStateChanged", "WhisperSpeechRecognizerStateChanged")
    s = s.replace("AppleSpeechRecognizerListeningChanged", "WhisperSpeechRecognizerListeningChanged")
    s = s.replace("AppleSpeechRecognizerEnergyChanged", "WhisperSpeechRecognizerEnergyChanged")
    s = s.replace("Pipeline Vocale Apple Speech & Multi-Agents", "Pipeline Vocale Whisper & Multi-Agents")
    write(rel, s)


# -----------------------------------------------------------------------------
# 3. Composer: never disable the native UITextField while Sarah is answering.
#    The stop button still stops generation, but the user can type immediately.
# -----------------------------------------------------------------------------
rel = "SarahIA/SarahIA/Views/MessageBar.swift"
s = read(rel)
s = replace_once_if_present(
    s,
    "                    isEnabled: !isProcessing,",
    "                    isEnabled: true,",
    "composer always enabled",
)
if "                    isEnabled: true," not in s:
    raise SystemExit("composer native field is not forced enabled")
s = s.replace(
    "                    .disabled(isProcessing)\n                    .accessibilityLabel(\"Dicter un message\")",
    "                    .accessibilityLabel(\"Dicter un message\")",
)
s = s.replace(
    "    private func startDictation() {\n        guard !isProcessing else { return }\n        HapticService.shared.buttonTap()",
    "    private func startDictation() {\n        if isProcessing { onCancel() }\n        HapticService.shared.buttonTap()",
)
write(rel, s)


# -----------------------------------------------------------------------------
# 4. Remove the full-screen tap recognizer that could steal the first composer tap.
# -----------------------------------------------------------------------------
rel = "SarahIA/SarahIA/Views/ChatScreenView.swift"
s = read(rel)
s = s.replace(
    "                .frame(maxWidth: .infinity, maxHeight: .infinity)\n                .contentShape(Rectangle())\n                .onTapGesture { keyboard.dismiss() }\n",
    "                .frame(maxWidth: .infinity, maxHeight: .infinity)\n",
)
if ".onTapGesture { keyboard.dismiss() }" in s:
    raise SystemExit("full-screen keyboard tap recognizer still present")
old_bg = "        .ignoresSafeArea()\n    }\n\n    private var composerDock: some View"
if old_bg in s:
    s = s.replace(
        old_bg,
        "        .ignoresSafeArea()\n        .allowsHitTesting(false)\n    }\n\n    private var composerDock: some View",
        1,
    )
write(rel, s)


# -----------------------------------------------------------------------------
# 5. Voice screen lifecycle: the microphone permission alert must NOT close voice.
#    Dismissing the sheet keeps the continuous session alive for the compact orb.
# -----------------------------------------------------------------------------
rel = "SarahIA/SarahIA/Views/VoiceOrbModalView.swift"
s = read(rel)
s = s.replace(
    "        .onDisappear {\n            viewModel.stopVoiceConversation()\n        }\n",
    "",
)
s = s.replace("UIApplication.willResignActiveNotification", "UIApplication.didEnterBackgroundNotification")
if "UIApplication.willResignActiveNotification" in s:
    raise SystemExit("voice screen still stops on microphone permission alert")
write(rel, s)


# -----------------------------------------------------------------------------
# 6. Compact voice mode is a floating orb above the REAL composer.
#    Pulling the sheet down dismisses only the surface, not the voice conversation.
# -----------------------------------------------------------------------------
rel = "SarahIA/SarahIA/ContentView.swift"
s = read(rel)
old_sheet = "        .sheet(isPresented: $viewModel.isShowingVoiceOrbModal, onDismiss: {\n            viewModel.stopVoiceConversation()\n        }) {\n            voiceSheetContent\n        }"
new_sheet = "        .sheet(isPresented: $viewModel.isShowingVoiceOrbModal) {\n            voiceSheetContent\n        }"
s = replace_once_if_present(s, old_sheet, new_sheet, "voice sheet dismissal")
if new_sheet not in s:
    raise SystemExit("canonical voice sheet not found")

startup_block = """                if isShowingStartupAnimation {
                    SarahStartupAnimationView()
                        .allowsHitTesting(false)
                        .zIndex(100)
                        .transition(.opacity)
                }
"""
if "compactVoiceOrb\n                        .zIndex(25)" not in s:
    compact_insert = startup_block + """

                if viewModel.isContinuousConversationActive &&
                   !viewModel.isShowingVoiceOrbModal &&
                   !viewModel.isDrawerOpen &&
                   !isShowingSettings {
                    compactVoiceOrb
                        .zIndex(25)
                        .transition(.scale(scale: 0.86).combined(with: .opacity))
                }
"""
    if startup_block not in s:
        raise SystemExit("startup block missing for compact voice orb")
    s = s.replace(startup_block, compact_insert, 1)

s = s.replace("    @State private var selectedDetent: PresentationDetent = .large\n\n", "")
s = s.replace(
    "        .presentationDetents([.height(255), .large], selection: $selectedDetent)",
    "        .presentationDetents([.large])",
)
s = s.replace(
    "/// Hôte du mode vocal moderne. La grande feuille s'ouvre comme le mode vocal\n/// principal. Un glissement vers le bas la réduit à 255 pt ; VoiceOrbModalView\n/// bascule alors automatiquement sur son petit orbe de 86 pt.",
    "/// Hôte du mode vocal moderne. La feuille reste grande ; un glissement vers le bas\n/// la ferme visuellement sans couper la conversation. Le petit orbe apparaît alors\n/// au-dessus du véritable composer du chat.",
)

marker = "    private var drawerOverlay: some View {"
if "private var compactVoiceOrb: some View" not in s:
    compact_property = """    private var compactVoiceOrb: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    HapticService.shared.buttonTap()
                    viewModel.isShowingVoiceOrbModal = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(0.96),
                                        viewModel.activeAgent.themeColor.opacity(0.94),
                                        viewModel.activeAgent.themeColor
                                    ],
                                    center: .topLeading,
                                    startRadius: 2,
                                    endRadius: 44
                                )
                            )
                            .frame(width: 64, height: 64)
                            .shadow(
                                color: viewModel.activeAgent.themeColor.opacity(0.48),
                                radius: 14
                            )

                        Image(systemName: "waveform")
                            .font(.system(size: 21, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(1.0 + min(CGFloat(viewModel.micInputLevel), 1.0) * 0.055)
                    .animation(.spring(response: 0.22, dampingFraction: 0.76), value: viewModel.micInputLevel)
                    .contentShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("Rouvrir le mode vocal Sarah")
                .accessibilityIdentifier("sarah.voice.compactOrb")
            }
        }
        .padding(.trailing, 18)
        .padding(.bottom, 10)
    }

"""
    if marker not in s:
        raise SystemExit("drawer overlay marker missing")
    s = s.replace(marker, compact_property + marker, 1)
write(rel, s)


# -----------------------------------------------------------------------------
# 7. Reliable loop: listen -> Whisper -> answer -> Apple TTS -> listen again.
#    Compact mode keeps the loop alive. The mic button mutes/resumes without
#    destroying the continuous conversation.
# -----------------------------------------------------------------------------
rel = "SarahIA/SarahIA/ViewModels/ChatViewModel.swift"
s = read(rel)

needle = """        voiceManager.onSpeechStarted = { [weak self] in
            self?.isSpeaking = true
            self?.voiceStatus = .speaking
            self?.haptics.speechStarted()
        }
"""
replacement = """        voiceManager.onSpeechStarted = { [weak self] in
            WhisperService.shared.stopRecordingWithoutTranscription()
            self?.isMicRunning = false
            self?.isSpeaking = true
            self?.voiceStatus = .speaking
            self?.haptics.speechStarted()
        }
"""
if needle in s:
    s = s.replace(needle, replacement, 1)

s = s.replace(
    "            if self.isContinuousConversationActive && self.isShowingVoiceOrbModal {\n",
    "            if self.isContinuousConversationActive && !self.isVoiceMicrophoneMuted {\n",
)
s = s.replace(
    "                    guard self.isContinuousConversationActive,\n                          self.isShowingVoiceOrbModal,\n                          !self.voiceManager.isSpeaking else { return }",
    "                    guard self.isContinuousConversationActive,\n                          !self.isVoiceMicrophoneMuted,\n                          !self.voiceManager.isSpeaking else { return }",
)

old_toggle = """    public func toggleMicrophone() {
        ensureVoicePipelinePrepared()
        haptics.buttonTap()
        if isMicRunning || WhisperSpeechRecognizer.shared.isListening {
            stopVoiceConversation(stopSpeech: false)
        } else {
            startVoiceConversation()
        }
    }
"""
new_toggle = """    public func toggleMicrophone() {
        ensureVoicePipelinePrepared()
        haptics.buttonTap()

        if isMicRunning || WhisperSpeechRecognizer.shared.isListening {
            isVoiceMicrophoneMuted = true
            WhisperSpeechRecognizer.shared.stopListening()
            isMicRunning = false
            micInputLevel = 0
            voiceStatus = .idle
            return
        }

        isVoiceMicrophoneMuted = false
        isContinuousConversationActive = true
        if voiceManager.isSpeaking {
            voiceManager.stop()
        }
        WhisperSpeechRecognizer.shared.startListening()
        isMicRunning = WhisperSpeechRecognizer.shared.isListening
        voiceStatus = isMicRunning ? .listening(level: micInputLevel) : .starting
    }
"""
s = replace_once_if_present(s, old_toggle, new_toggle, "voice microphone mute/resume")

s = s.replace(
    "        voiceManager.stop()\n        isContinuousConversationActive = true\n\n        guard !WhisperSpeechRecognizer.shared.isListening else {",
    "        voiceManager.stop()\n        isContinuousConversationActive = true\n        isVoiceMicrophoneMuted = false\n\n        guard !WhisperSpeechRecognizer.shared.isListening else {",
)
s = s.replace(
    "        voiceStatus = isMicRunning ? .listening(level: 0.0) : .idle\n    }\n\n    /// Coupe complètement le mode vocal",
    "        voiceStatus = isMicRunning ? .listening(level: 0.0) : .starting\n    }\n\n    /// Coupe complètement le mode vocal",
)
s = s.replace(
    "        isContinuousConversationActive = false\n\n        // Couper d'abord",
    "        isContinuousConversationActive = false\n        isVoiceMicrophoneMuted = false\n\n        // Couper d'abord",
)
s = s.replace(
    "                case .idle:\n                    if self.isContinuousConversationActive,",
    "                case .idle:\n                    if self.isTyping {\n                        self.voiceStatus = .processing\n                    } else if self.isContinuousConversationActive,",
)
write(rel, s)

print("Canonical Whisper runtime and UI fixes applied")
