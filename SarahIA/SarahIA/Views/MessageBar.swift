import SwiftUI
import UIKit

/// Barre de saisie Sarah orientée fiabilité :
/// - la capsule centrale est un vrai UITextField natif sur toute sa surface ;
/// - + = Photos / Appareil photo / Fichier ;
/// - micro = dictée locale ;
/// - waveform = mode vocal Sarah ;
/// - carré = arrêt de la génération.
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
        .padding(.vertical, 6)
        // Une surface presque transparente empêche les touches de traverser la
        // barre et d'atteindre MessageList derrière elle.
        .background(Color.black.opacity(0.001))
        .contentShape(Rectangle())
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
        HStack(spacing: 9) {
            attachmentMenu

            ZStack(alignment: .trailing) {
                ReliableComposerTextField(
                    text: $text,
                    placeholder: "Demander à \(activeAgent.displayName)...",
                    tintColor: UIColor(activeAgent.themeColor),
                    accessibilityIdentifier: "sarah.composer.field",
                    isEnabled: !isProcessing,
                    onReturn: {
                        guard !isProcessing else { return }
                        submitMessage()
                    }
                )
                .frame(maxWidth: .infinity, minHeight: 52, maxHeight: 52)

                HStack(spacing: 2) {
                    if activeAgent == .esther {
                        Button {
                            guard !isProcessing else { return }
                            HapticService.shared.buttonTap()
                            dismissKeyboard()
                            onOpenVAICoding()
                        } label: {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .foregroundColor(activeAgent.themeColor)
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 36, height: 36)
                                .background(activeAgent.themeColor.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isProcessing)
                    }

                    Button(action: startDictation) {
                        Image(systemName: "mic")
                            .foregroundColor(isProcessing ? .gray.opacity(0.40) : .gray)
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 40, height: 40)
                            .contentShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isProcessing)
                    .accessibilityLabel("Dicter un message")
                    .accessibilityIdentifier("sarah.dictation.button")
                }
                .padding(.trailing, 6)
            }
            .frame(minHeight: 52)
            .sarahLiquidGlass(
                cornerRadius: 26,
                tint: activeAgent.themeColor,
                intensity: activeAgent == .esther ? 0.12 : 0.08
            )
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

            composerActionButton
        }
        .frame(maxWidth: .infinity)
    }

    private var attachmentMenu: some View {
        Menu {
            Button {
                HapticService.shared.buttonTap()
                dismissKeyboard()
                onOpenPhotoLibrary()
            } label: {
                Label("Photos", systemImage: "photo.on.rectangle.angled")
            }

            Button {
                HapticService.shared.buttonTap()
                dismissKeyboard()
                onOpenCamera()
            } label: {
                Label("Appareil photo", systemImage: "camera")
            }

            Button {
                HapticService.shared.buttonTap()
                dismissKeyboard()
                onOpenFile()
            } label: {
                Label("Fichier", systemImage: "doc")
            }
        } label: {
            ZStack {
                Circle().fill(Color.white.opacity(0.07))
                Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                Image(systemName: "plus")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: 50, height: 50)
            .contentShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Ajouter une photo, prendre une photo ou joindre un fichier")
        .accessibilityIdentifier("sarah.attachment.menu")
    }

    private var composerActionButton: some View {
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return Button {
            if isProcessing {
                HapticService.shared.buttonTap()
                onCancel()
            } else if hasText {
                submitMessage()
            } else {
                HapticService.shared.buttonTap()
                dismissKeyboard()
                onOpenVoiceOrb()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(
                        (isProcessing || hasText)
                        ? activeAgent.themeColor.opacity(0.92)
                        : Color.white.opacity(0.08)
                    )
                Circle()
                    .stroke(
                        (isProcessing || hasText)
                        ? Color.white.opacity(0.26)
                        : Color.white.opacity(0.14),
                        lineWidth: 0.8
                    )

                if isProcessing {
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                } else {
                    Image(systemName: hasText ? "arrow.up" : "waveform")
                        .font(.system(size: 19, weight: hasText ? .bold : .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 50, height: 50)
            .contentShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(isProcessing ? "Arrêter la génération" : (hasText ? "Envoyer" : "Mode vocal Sarah"))
        .accessibilityIdentifier("sarah.composer.action")
    }

    private var dictationBar: some View {
        HStack(spacing: 10) {
            Button(action: cancelDictation) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 46, height: 46)
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
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(Color.white.opacity(0.10)))
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: { finishDictation(sendImmediately: true) }) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(activeAgent.themeColor))
            }
            .buttonStyle(PlainButtonStyle())
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
        dismissKeyboard()
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
        let prefix = textBeforeDictation
        isDictating = false
        dictationMicLevel = 0

        AppleSpeechRecognizer.shared.stopListeningAndTranscribe { recognized in
            let finalText = mergedText(prefix: prefix, dictated: recognized ?? "")
            text = finalText
            dictationLiveText = recognized ?? ""
            if sendImmediately && !finalText.isEmpty {
                onSend(finalText)
                text = ""
            }
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
        dismissKeyboard()
        onSend(trimmed)
        text = ""
    }

    private func dismissKeyboard() {
        KeyboardObserver.shared.dismiss()
    }
}

/// UITextField natif utilisé par le composer. Contrairement à un TextField
/// SwiftUI entouré de padding, toute la frame de cette vue est réellement
/// interactive et devient first responder dès le premier toucher.
@available(iOS 15.0, *)
private struct ReliableComposerTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let tintColor: UIColor
    let accessibilityIdentifier: String
    let isEnabled: Bool
    let onReturn: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> PaddedTextField {
        let field = PaddedTextField(frame: .zero)
        field.delegate = context.coordinator
        field.backgroundColor = .clear
        field.borderStyle = .none
        field.textColor = .white
        field.tintColor = tintColor
        field.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        field.autocapitalizationType = .sentences
        field.autocorrectionType = .yes
        field.spellCheckingType = .yes
        field.returnKeyType = .send
        field.clearButtonMode = .never
        field.adjustsFontSizeToFitWidth = false
        field.minimumFontSize = 12
        field.textContentType = nil
        field.isUserInteractionEnabled = true
        field.accessibilityIdentifier = accessibilityIdentifier
        field.textInsets = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 54)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        return field
    }

    func updateUIView(_ uiView: PaddedTextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.tintColor = tintColor
        uiView.isEnabled = isEnabled
        uiView.isUserInteractionEnabled = isEnabled
        uiView.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: UIColor.white.withAlphaComponent(0.38),
                .font: UIFont.systemFont(ofSize: 15, weight: .regular)
            ]
        )
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: ReliableComposerTextField

        init(parent: ReliableComposerTextField) {
            self.parent = parent
        }

        @objc func textChanged(_ sender: UITextField) {
            parent.text = sender.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onReturn()
            return false
        }
    }
}

@available(iOS 15.0, *)
private final class PaddedTextField: UITextField {
    var textInsets: UIEdgeInsets = .zero

    override func textRect(forBounds bounds: CGRect) -> CGRect {
        bounds.inset(by: textInsets)
    }

    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        bounds.inset(by: textInsets)
    }

    override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        bounds.inset(by: textInsets)
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
