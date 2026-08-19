import SwiftUI

/// Barre de composition iMessage / ChatGPT style avec bouton Plus, Dictée et Bascule Onde/Flèche dynamique.
public struct MessageInputView: View {
    @Binding public var text: String
    public let isTyping: Bool
    public var isMicActive: Bool
    public let onSend: () -> Void
    public var onMicTap: (() -> Void)?
    public var onPlusTap: (() -> Void)?
    public var onVoiceModeTap: (() -> Void)?
    
    public init(
        text: Binding<String>,
        isTyping: Bool,
        isMicActive: Bool = false,
        onSend: @escaping () -> Void,
        onMicTap: (() -> Void)? = nil,
        onPlusTap: (() -> Void)? = nil,
        onVoiceModeTap: (() -> Void)? = nil
    ) {
        self._text = text
        self.isTyping = isTyping
        self.isMicActive = isMicActive
        self.onSend = onSend
        self.onMicTap = onMicTap
        self.onPlusTap = onPlusTap
        self.onVoiceModeTap = onVoiceModeTap
    }
    
    public var body: some View {
        HStack(spacing: 10) {
            // Bouton Plus (+)
            Button(action: {
                HapticService.shared.buttonTap()
                onPlusTap?()
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 34, height: 34)
            }
            
            // Champ de texte
            TextField("Demander à Sarah", text: $text)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(.white)
                .disabled(isTyping)
                .submitLabel(.send)
                .onSubmit {
                    if canSend {
                        onSend()
                    }
                }
            
            // Bouton Dictée Microphone
            Button(action: {
                onMicTap?()
            }) {
                Image(systemName: isMicActive ? "mic.fill" : "mic")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isMicActive ? .red : .white.opacity(0.85))
                    .frame(width: 34, height: 34)
            }
            
            // Bouton Envoi / Onde Vocale Dynamique
            Button(action: {
                if canSend {
                    onSend()
                } else {
                    onVoiceModeTap?()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(canSend ? Color(red: 0.04, green: 0.52, blue: 1.0) : Color.white.opacity(0.12))
                        .frame(width: 38, height: 38)
                    
                    if canSend {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        // Icône d'onde vocale
                        Image(systemName: "waveform")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .scaleEffect(canSend ? 1.04 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: canSend)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(red: 0.11, green: 0.11, blue: 0.12))
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }
    
    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isTyping
    }
}
