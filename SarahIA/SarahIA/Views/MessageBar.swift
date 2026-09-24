import SwiftUI

/// Barre de saisie compacte de Sarah IA.
/// Le micro dans le champ sert à la dictée ; le bouton onde ouvre le vrai mode vocal.
@available(iOS 14.0, *)
public struct MessageBar: View {
    @Binding var text: String
    @Binding var activeAgent: AgentType

    var isRecording: Bool
    var onSend: (String) -> Void
    var onToggleMic: () -> Void
    var onOpenVoiceOrb: () -> Void
    var onOpenVAICoding: () -> Void

    public init(
        text: Binding<String>,
        activeAgent: Binding<AgentType>,
        isRecording: Bool,
        onSend: @escaping (String) -> Void,
        onToggleMic: @escaping () -> Void,
        onOpenVoiceOrb: @escaping () -> Void,
        onOpenVAICoding: @escaping () -> Void
    ) {
        self._text = text
        self._activeAgent = activeAgent
        self.isRecording = isRecording
        self.onSend = onSend
        self.onToggleMic = onToggleMic
        self.onOpenVoiceOrb = onOpenVoiceOrb
        self.onOpenVAICoding = onOpenVAICoding
    }

    public var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 7) {
                TextField(
                    "Demander à \(activeAgent.displayName)…",
                    text: $text,
                    onCommit: submitMessage
                )
                .foregroundColor(.white)
                .accentColor(activeAgent.themeColor)
                .font(.system(size: 15, weight: .regular))
                .lineLimit(1)

                Button {
                    HapticService.shared.buttonTap()
                    onToggleMic()
                } label: {
                    ZStack {
                        if isRecording {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(Color.white.opacity(0.10))
                                .frame(width: 32, height: 32)

                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(activeAgent.themeColor)
                                .frame(width: 11, height: 11)
                        } else {
                            Image(systemName: "mic")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.52))
                                .frame(width: 32, height: 32)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(isRecording ? "Arrêter la dictée et conserver le texte" : "Dicter un message")
            }
            .padding(.leading, 14)
            .padding(.trailing, 6)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.055), lineWidth: 0.7)
            )

            Button {
                let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                HapticService.shared.buttonTap()

                if hasText {
                    submitMessage()
                } else {
                    onOpenVoiceOrb()
                }
            } label: {
                let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

                Image(systemName: hasText ? "arrow.up" : "waveform")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        Circle()
                            .fill(
                                hasText
                                    ? activeAgent.themeColor
                                    : Color.white.opacity(0.12)
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(hasText ? 0.12 : 0.07), lineWidth: 0.7)
                    )
            }
            .buttonStyle(ScaleBounceButtonStyle())
            .accessibilityLabel(
                text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "Ouvrir le mode vocal"
                    : "Envoyer"
            )
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 7)
    }

    private func submitMessage() {
        if isRecording {
            onToggleMic()
            return
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            onToggleMic()
            return
        }

        HapticService.shared.buttonTap()
        onSend(trimmed)
        text = ""
    }
}
