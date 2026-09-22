import SwiftUI

/// Barre de saisie native SwiftUI.
@available(iOS 14.0, *)
public struct MessageBar: View {
    @Binding var text: String
    @Binding var activeAgent: AgentType
    var isRecording: Bool
    var isProcessing: Bool
    var onSend: (String) -> Void
    var onCancel: () -> Void
    var onToggleMic: () -> Void
    var onOpenVoiceOrb: () -> Void
    var onOpenVAICoding: () -> Void

    @State private var processingRotation: Double = 0

    public init(
        text: Binding<String>,
        activeAgent: Binding<AgentType>,
        isRecording: Bool,
        isProcessing: Bool = false,
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
        self.onSend = onSend
        self.onCancel = onCancel
        self.onToggleMic = onToggleMic
        self.onOpenVoiceOrb = onOpenVoiceOrb
        self.onOpenVAICoding = onOpenVAICoding
    }

    public var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                TextField("Demander à \(activeAgent.displayName)...", text: $text, onCommit: {
                    guard !isProcessing else { return }
                    submitMessage()
                })
                .foregroundColor(.white)
                .accentColor(.blue)
                .font(.system(size: 15))

                Button(action: {
                    guard !isProcessing else { return }
                    onToggleMic()
                }) {
                    Image(systemName: isRecording ? "mic.fill" : "mic")
                        .foregroundColor(isProcessing ? .gray.opacity(0.45) : (isRecording ? .red : .gray))
                        .font(.system(size: 18))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isProcessing)
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(Color(white: 0.15))
            .cornerRadius(24)

            let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

            Button(action: {
                if isProcessing {
                    HapticService.shared.buttonTap()
                    onCancel()
                } else if hasText {
                    submitMessage()
                } else {
                    HapticService.shared.buttonTap()
                    onOpenVoiceOrb()
                }
            }) {
                ZStack {
                    if isProcessing {
                        Circle()
                            .stroke(Color.white.opacity(0.14), lineWidth: 2.5)

                        Circle()
                            .trim(from: 0.08, to: 0.72)
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        Color.sarahCyan,
                                        Color.purple,
                                        Color.sarahCyan.opacity(0.18)
                                    ]),
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 2.7, lineCap: .round)
                            )
                            .rotationEffect(.degrees(processingRotation))

                        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                            .fill(Color.white)
                            .frame(width: 10, height: 10)
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
                isProcessing
                    ? Color(white: 0.13)
                    : (hasText ? Color.blue : Color(white: 0.15))
            )
            .clipShape(Circle())
            .buttonStyle(ScaleBounceButtonStyle())
            .accessibilityLabel(isProcessing ? "Arrêter la génération" : (hasText ? "Envoyer" : "Ouvrir le mode vocal"))
            .onAppear {
                updateProcessingAnimation()
            }
            .onChange(of: isProcessing) { _ in
                updateProcessingAnimation()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private func updateProcessingAnimation() {
        if isProcessing {
            processingRotation = 0
            withAnimation(Animation.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                processingRotation = 360
            }
        } else {
            processingRotation = 0
        }
    }

    private func submitMessage() {
        guard !isProcessing else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            HapticService.shared.buttonTap()
            onSend(trimmed)
            text = ""
        } else {
            onToggleMic()
        }
    }
}
