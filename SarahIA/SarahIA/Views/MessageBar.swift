import SwiftUI

/// Barre de saisie 100% native SwiftUI (MessageBar) avec Capsule Élargie,
/// champ texte, microphone intégré et bouton waveform / envoi.
@available(iOS 14.0, *)
public struct MessageBar: View {
    @Binding var text: String
    @Binding var activeAgent: AgentType
    var isRecording: Bool
    var onSend: (String) -> Void
    var onToggleMic: () -> Void
    var onOpenVoiceOrb: () -> Void
    var onOpenVAICoding: () -> Void
    var onShareVideo: (() -> Void)? = nil
    
    public init(
        text: Binding<String>,
        activeAgent: Binding<AgentType>,
        isRecording: Bool,
        onSend: @escaping (String) -> Void,
        onToggleMic: @escaping () -> Void,
        onOpenVoiceOrb: @escaping () -> Void,
        onOpenVAICoding: @escaping () -> Void,
        onShareVideo: (() -> Void)? = nil
    ) {
        self._text = text
        self._activeAgent = activeAgent
        self.isRecording = isRecording
        self.onSend = onSend
        self.onToggleMic = onToggleMic
        self.onOpenVoiceOrb = onOpenVoiceOrb
        self.onOpenVAICoding = onOpenVAICoding
        self.onShareVideo = onShareVideo
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // Champ texte étendu naturellement avec Micro intégré à droite de la capsule
            HStack(spacing: 8) {
                TextField("Demander à \(activeAgent.rawValue)...", text: $text, onCommit: {
                    submitMessage()
                })
                .foregroundColor(.white)
                .accentColor(.blue)
                .font(.system(size: 15))
                
                Button(action: {
                    onToggleMic()
                }) {
                    Image(systemName: isRecording ? "mic.fill" : "mic")
                        .foregroundColor(isRecording ? .red : .gray)
                        .font(.system(size: 18))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(Color(white: 0.15))
            .cornerRadius(24)
            
            // Bouton Waveform / Envoi
            let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            Button(action: {
                if hasText {
                    submitMessage()
                } else {
                    HapticService.shared.buttonTap()
                    onOpenVoiceOrb()
                }
            }) {
                Image(systemName: hasText ? "arrow.up" : "waveform")
                    .font(.system(size: 18, weight: hasText ? .bold : .regular))
                    .foregroundColor(.white)
            }
            .frame(width: 44, height: 44)
            .background(hasText ? Color.blue : Color(white: 0.15))
            .clipShape(Circle())
            .buttonStyle(ScaleBounceButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
    
    private func submitMessage() {
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
