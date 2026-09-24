import SwiftUI

/// Barre de saisie native SwiftUI.
@available(iOS 15.0, *)
public struct MessageBar: View {
    @Binding var text: String
    @Binding var activeAgent: AgentType
    var isRecording: Bool
    var isProcessing: Bool
    var onOpenActions: () -> Void
    var onOpenCamera: () -> Void
    var onOpenFile: () -> Void
    var onSend: (String) -> Void
    var onCancel: () -> Void
    var onToggleMic: () -> Void
    var onOpenVoiceOrb: () -> Void
    var onOpenVAICoding: () -> Void

    @FocusState private var isComposerFocused: Bool

    public init(
        text: Binding<String>,
        activeAgent: Binding<AgentType>,
        isRecording: Bool,
        isProcessing: Bool = false,
        onOpenActions: @escaping () -> Void = {},
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
        self.onOpenActions = onOpenActions
        self.onOpenCamera = onOpenCamera
        self.onOpenFile = onOpenFile
        self.onSend = onSend
        self.onCancel = onCancel
        self.onToggleMic = onToggleMic
        self.onOpenVoiceOrb = onOpenVoiceOrb
        self.onOpenVAICoding = onOpenVAICoding
    }

    public var body: some View {
        VStack(spacing: 8) {
            TextField("Demander à \(activeAgent.displayName)…", text: $text, onCommit: submitMessage)
                .focused($isComposerFocused)
                .accessibilityIdentifier("chat.input")
                .foregroundColor(.white)
                .font(.system(size: 17))
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .frame(minHeight: 42)
            HStack(spacing: 14) {
                Menu {
                    Button(action: onOpenActions) { Label("Ajouter une image", systemImage: "photo") }
                    Button(action: onOpenCamera) { Label("Prendre une photo", systemImage: "camera") }
                    Button(action: onOpenFile) { Label("Ajouter un fichier", systemImage: "doc") }
                } label: {
                    Image(systemName: "plus").font(.system(size: 23)).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Ajouter une pièce jointe")
                .accessibilityIdentifier("chat.attach")
                Spacer(minLength: 0)
                Text(isRecording ? "Dictée en cours…" : activeAgent.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                Button {
                    isComposerFocused = false
                    onToggleMic()
                } label: {
                    Image(systemName: isRecording ? "stop.fill" : "mic")
                        .font(.system(size: 21)).frame(width: 44, height: 44)
                }
                .disabled(isProcessing)
                .accessibilityIdentifier("chat.dictate")
                .accessibilityLabel(isRecording ? "Terminer la dictée" : "Dicter du texte")
                let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                Button {
                    if isProcessing { onCancel() }
                    else if isRecording { onToggleMic() }
                    else if hasText { submitMessage() }
                    else { isComposerFocused = false; onOpenVoiceOrb() }
                } label: {
                    Image(systemName: isProcessing || isRecording ? "stop.fill" : (hasText ? "arrow.up" : "waveform"))
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color.white.opacity(0.18)))
                        .frame(width: 44, height: 44)
                }
                .accessibilityIdentifier("chat.sendOrVoice")
                .accessibilityLabel(isProcessing ? "Arrêter la génération" : (isRecording ? "Terminer la dictée" : (hasText ? "Envoyer" : "Ouvrir le mode vocal")))
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
        }
        .foregroundColor(.white)
        .buttonStyle(PlainButtonStyle())
        .background(RoundedRectangle(cornerRadius: 26).fill(Color(white: 0.12)))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .padding(.horizontal, 12)
        .padding(.top, 5)
        .padding(.bottom, 2)
    }

    private func openRaphaelStudio() {
        guard !isProcessing else { return }
        HapticService.shared.buttonTap()
        activeAgent = .esther
        isComposerFocused = false
        onOpenVAICoding()
    }

    private func startGuidedWebsite() {
        guard !isProcessing else { return }
        HapticService.shared.buttonTap()
        activeAgent = .esther
        isComposerFocused = false
        onSend("Donne-moi l'agent développeur")
    }

    private func prepare3DStudioPrompt() {
        guard !isProcessing else { return }
        HapticService.shared.buttonTap()
        activeAgent = .esther
        text = "Crée-moi une scène 3D éditable. Commence par extraire les dimensions, les étages, la hauteur sous plafond, les pièces, les ouvertures, les matériaux, l'éclairage et le style, puis prépare la scène paramétrique. "
        isComposerFocused = true
    }

    private func prepareDebugPrompt() {
        guard !isProcessing else { return }
        HapticService.shared.buttonTap()
        activeAgent = .esther
        text = "Analyse ce code, trouve les bugs et propose une version corrigée : "
        isComposerFocused = true
    }

    private func prepareAppleWebsitePrompt() {
        guard !isProcessing else { return }
        HapticService.shared.buttonTap()
        activeAgent = .esther
        text = "Je veux créer un site internet avec un style Apple / Liquid Glass. "
        isComposerFocused = true
    }

    private func submitMessage() {
        guard !isProcessing else { return }
        if isRecording { onToggleMic(); return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            HapticService.shared.buttonTap()
            isComposerFocused = false
            onSend(trimmed)
            text = ""
        } else {
            onToggleMic()
        }
    }
}