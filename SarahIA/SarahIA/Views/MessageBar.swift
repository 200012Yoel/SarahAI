import SwiftUI

/// Barre de saisie récente de Sarah :
/// - + = Photos / Appareil photo / Fichier uniquement ;
/// - micro dans le champ = dictée locale, sans envoi automatique ;
/// - waveform = vrai mode vocal continu ;
/// - carré = arrêt de la génération en cours.
@available(iOS 15.0, *)
public struct MessageBar: View {
    @Binding var text: String
    @Binding var activeAgent: AgentType
    var isRecording: Bool
    var isProcessing: Bool
    var onOpenPhotoLibrary: () -> Void
    var onOpenCamera: () -> Void
    var onOpenFile: () -> Void
    var onSend: (String) -> Void
    var onCancel: () -> Void
    var onToggleMic: () -> Void
    var onOpenVoiceOrb: () -> Void
    var onOpenVAICoding: () -> Void

    @FocusState private var isComposerFocused: Bool
    @State private var isDictating = false
    @State private var textBeforeDictation = ""
    @State private var dictationMicLevel: Float = 0.0
    @State private var dictationLiveText: String = ""

    public init(
        text: Binding<String>,
        activeAgent: Binding<AgentType>,
        isRecording: Bool,
        isProcessing: Bool = false,
        onOpenPhotoLibrary: @escaping () -> Void = {},
        onOpenCamera: @escaping () -> Void = {},
        onOpenFile: @escaping () -> Void = {},
        onSend: @escaping (String) -> Void,
        onCancel: @escaping () -> Void = {},
        onToggleMic: @escaping () -> Void,
        onOpenVoiceOrb: @escaping () -> Void,
        onOpenVAICoding: @escaping () -> Void
    ) {
        self._text = text
        self._activeAgent = activeAgent
        self.isRecording = isRecording
        self.isProcessing = isProcessing
        self.onOpenPhotoLibrary = onOpenPhotoLibrary
        self.onOpenCamera = onOpenCamera
        self.onOpenFile = onOpenFile
        self.onSend = onSend
        self.onCancel = onCancel
        self.onToggleMic = onToggleMic
        self.onOpenVoiceOrb = onOpenVoiceOrb
        self.onOpenVAICoding = onOpenVAICoding
    }

    public var body: some View {
        Group {
            if isDictating {
                dictationBar
            } else {
                standardBar
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AppleSpeechRecognizerListeningChanged"))) { _ in
            guard isDictating else { return }
            let recognizer = AppleSpeechRecognizer.shared
            dictationLiveText = recognizer.currentLiveText
            dictationMicLevel = recognizer.micEnergyLevel
            if !recognizer.isListening {
                commitDictationToComposer()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AppleSpeechRecognizerEnergyChanged"))) { _ in
            guard isDictating else { return }
            dictationMicLevel = AppleSpeechRecognizer.shared.micEnergyLevel
            dictationLiveText = AppleSpeechRecognizer.shared.currentLiveText
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AppleSpeechRecognizerStateChanged"))) { _ in
            guard isDictating else { return }
            if case .error = AppleSpeechRecognizer.shared.state {
                AppleSpeechRecognizer.shared.stopListening()
                isDictating = false
                dictationMicLevel = 0
                text = textBeforeDictation
            }
        }
        .onDisappear {
            if isDictating {
                AppleSpeechRecognizer.shared.stopListening()
                isDictating = false
                dictationMicLevel = 0
            }
        }
    }

    private var standardBar: some View {
        HStack(spacing: 10) {
            Menu {
                Button {
                    HapticService.shared.buttonTap()
                    isComposerFocused = false
                    onOpenPhotoLibrary()
                } label: {
                    Label("Photos", systemImage: "photo.on.rectangle.angled")
                }

                Button {
                    HapticService.shared.buttonTap()
                    isComposerFocused = false
                    onOpenCamera()
                } label: {
                    Label("Appareil photo", systemImage: "camera")
                }

                Button {
                    HapticService.shared.buttonTap()
                    isComposerFocused = false
                    onOpenFile()
                } label: {
                    Label("Fichier", systemImage: "doc")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .sarahLiquidGlass(cornerRadius: 22, tint: activeAgent.themeColor, intensity: 0.10)
            }
            .accessibilityLabel("Ajouter une photo, prendre une photo ou joindre un fichier")

            HStack(spacing: 8) {
                TextField("Demander à \(activeAgent.displayName)...", text: $text, onCommit: {
                    guard !isProcessing else { return }
                    submitMessage()
                })
                .focused($isComposerFocused)
                .foregroundColor(.white)
                .accentColor(activeAgent.themeColor)
                .font(.system(size: 15))

                if activeAgent == .esther {
                    Button(action: {
                        guard !isProcessing else { return }
                        HapticService.shared.buttonTap()
                        isComposerFocused = false
                        onOpenVAICoding()
                    }) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .foregroundColor(activeAgent.themeColor)
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 30, height: 30)
                            .background(activeAgent.themeColor.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isProcessing)
                }

                Button(action: startDictation) {
                    Image(systemName: "mic")
                        .foregroundColor(isProcessing ? .gray.opacity(0.45) : .gray)
                        .font(.system(size: 18))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isProcessing)
                .accessibilityLabel("Dicter un message")
            }
            .padding(.leading, 15)
            .padding(.trailing, 9)
            .frame(height: 48)
            .sarahLiquidGlass(cornerRadius: 24, tint: activeAgent.themeColor, intensity: activeAgent == .esther ? 0.12 : 0.08)

            let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            Button {
                if isProcessing {
                    HapticService.shared.buttonTap()
                    onCancel()
                } else if hasText {
                    submitMessage()
                } else {
                    HapticService.shared.buttonTap()
                    isComposerFocused = false
                    onOpenVoiceOrb()
                }
            } label: {
                ZStack {
                    if isProcessing {
                        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                            .fill(Color.white)
                            .frame(width: 11, height: 11)
                    } else {
                        Image(systemName: hasText ? "arrow.up" : "waveform")
                            .font(.system(size: 18, weight: hasText ? .bold : .regular))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 44, height: 44)
            }
            .background(
                ZStack {
                    Circle().fill(.ultraThinMaterial)
                    Circle().fill((isProcessing || hasText) ? activeAgent.themeColor.opacity(0.92) : Color.white.opacity(0.06))
                    Circle().stroke((isProcessing || hasText) ? Color.white.opacity(0.26) : Color.white.opacity(0.12), lineWidth: 0.8)
                }
            )
            .clipShape(Circle())
            .buttonStyle(ScaleBounceButtonStyle())
            .accessibilityLabel(isProcessing ? "Arrêter la génération" : (hasText ? "Envoyer" : "Mode vocal Sarah"))
        }
    }

    private var dictationBar: some View {
        HStack(spacing: 10) {
            Button(action: cancelDictation) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.white.opacity(0.10)))
            }
            .buttonStyle(PlainButtonStyle())

            VStack(spacing: 3) {
                LiveMicrophoneWaveform(level: dictationMicLevel)
                    .frame(maxWidth: .infinity, minHeight: 28, maxHeight: 28)
                Text(currentRecognizedText.isEmpty ? "Transcription en cours" : "Je t’écoute…")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            Button(action: { finishDictation(sendImmediately: false) }) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.white.opacity(0.10)))
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: { finishDictation(sendImmediately: true) }) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(activeAgent.themeColor))
            }
            .buttonStyle(ScaleBounceButtonStyle())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .sarahLiquidGlass(cornerRadius: 28, tint: activeAgent.themeColor, intensity: 0.10)
    }

    private var currentRecognizedText: String {
        let live = AppleSpeechRecognizer.shared.currentLiveText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !live.isEmpty { return live }
        return dictationLiveText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func startDictation() {
        guard !isProcessing else { return }
        HapticService.shared.buttonTap()
        let recognizer = AppleSpeechRecognizer.shared
        if recognizer.isListening { recognizer.stopListening() }
        textBeforeDictation = text.trimmingCharacters(in: .whitespacesAndNewlines)
        dictationLiveText = ""
        dictationMicLevel = 0
        isDictating = true
        recognizer.startListening(autoFinalizeOnSilence: false)
    }

    private func finishDictation(sendImmediately: Bool) {
        HapticService.shared.buttonTap()
        let recognized = currentRecognizedText
        AppleSpeechRecognizer.shared.stopListening()
        isDictating = false
        dictationMicLevel = 0
        let finalText = mergedText(prefix: textBeforeDictation, dictated: recognized)
        text = finalText
        if sendImmediately && !finalText.isEmpty {
            onSend(finalText)
            text = ""
        }
    }

    private func commitDictationToComposer() {
        text = mergedText(prefix: textBeforeDictation, dictated: currentRecognizedText)
        isDictating = false
        dictationMicLevel = 0
    }

    private func cancelDictation() {
        HapticService.shared.buttonTap()
        AppleSpeechRecognizer.shared.stopListening()
        isDictating = false
        dictationMicLevel = 0
        text = textBeforeDictation
    }

    private func mergedText(prefix: String, dictated: String) -> String {
        let lhs = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        let rhs = dictated.trimmingCharacters(in: .whitespacesAndNewlines)
        if lhs.isEmpty { return rhs }
        if rhs.isEmpty { return lhs }
        return lhs + " " + rhs
    }

    private func submitMessage() {
        guard !isProcessing else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        HapticService.shared.buttonTap()
        isComposerFocused = false
        onSend(trimmed)
        text = ""
    }
}

@available(iOS 15.0, *)
private struct LiveMicrophoneWaveform: View {
    let level: Float
    private let weights: [CGFloat] = [0.38,0.62,0.90,0.55,0.74,1.00,0.66,0.44,0.82,0.58,0.96,0.70,0.48,0.88,0.64,1.00,0.60,0.78,0.50,0.92,0.68,0.42]

    var body: some View {
        GeometryReader { geo in
            let normalized = CGFloat(max(0.0, min(1.0, level)))
            HStack(alignment: .center, spacing: 3) {
                ForEach(weights.indices, id: \.self) { index in
                    let height = max(4, min(geo.size.height, 4 + normalized * geo.size.height * weights[index]))
                    Capsule()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: 3, height: height)
                        .animation(.linear(duration: 0.08), value: level)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}