import SwiftUI

/// Barre de saisie native SwiftUI.
@available(iOS 15.0, *)
public struct MessageBar: View {
    @Binding var text: String
    @Binding var activeAgent: AgentType
    var isRecording: Bool
    var isProcessing: Bool
    var onOpenActions: () -> Void
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
        self.onSend = onSend
        self.onCancel = onCancel
        self.onToggleMic = onToggleMic
        self.onOpenVoiceOrb = onOpenVoiceOrb
        self.onOpenVAICoding = onOpenVAICoding
    }

    public var body: some View {
        HStack(spacing: 10) {
            Menu {
                Button(action: {
                    HapticService.shared.buttonTap()
                    isComposerFocused = false
                    onOpenVAICoding()
                }) {
                    Label("Studio Raphaël · Code", systemImage: "chevron.left.forwardslash.chevron.right")
                }

                Button(action: {
                    HapticService.shared.buttonTap()
                    isComposerFocused = false
                    onOpenVoiceOrb()
                }) {
                    Label("Mode vocal", systemImage: "waveform.circle.fill")
                }

                Divider()

                Button(action: {
                    HapticService.shared.buttonTap()
                    isComposerFocused = false
                    onOpenActions()
                }) {
                    Label("Tous les outils", systemImage: "square.grid.2x2")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .sarahLiquidGlass(
                        cornerRadius: 22,
                        tint: activeAgent.themeColor,
                        intensity: 0.10
                    )
            }
            .accessibilityLabel("Ouvrir les outils rapides")

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
                    .accessibilityLabel("Ouvrir le Studio Raphaël")
                }

                Button(action: {
                    guard !isProcessing else { return }
                    onToggleMic()
                }) {
                    Image(systemName: isRecording ? "mic.fill" : "mic")
                        .foregroundColor(isProcessing ? .gray.opacity(0.45) : (isRecording ? activeAgent.themeColor : .gray))
                        .font(.system(size: 18))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isProcessing)
            }
            .padding(.leading, 15)
            .padding(.trailing, 9)
            .frame(height: 48)
            .sarahLiquidGlass(
                cornerRadius: 24,
                tint: activeAgent.themeColor,
                intensity: activeAgent == .esther ? 0.12 : 0.08
            )

            let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

            Button(action: {
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
            }) {
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
                .contentShape(Circle())
            }
            .frame(width: 44, height: 44)
            .background(
                ZStack {
                    Circle().fill(.ultraThinMaterial)
                    Circle().fill(
                        (isProcessing || hasText)
                            ? activeAgent.themeColor.opacity(0.92)
                            : Color.white.opacity(0.06)
                    )
                    Circle().stroke(
                        (isProcessing || hasText)
                            ? Color.white.opacity(0.26)
                            : Color.white.opacity(0.12),
                        lineWidth: 0.8
                    )
                }
            )
            .clipShape(Circle())
            .buttonStyle(ScaleBounceButtonStyle())
            .accessibilityLabel(isProcessing ? "Arrêter la génération" : (hasText ? "Envoyer" : "Ouvrir le mode vocal"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("--sarah-ui-smoke-keyboard") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    isComposerFocused = true
                }
            }
        }
    }

    private func submitMessage() {
        guard !isProcessing else { return }
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
