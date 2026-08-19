import SwiftUI

/// Barre de saisie de message iMessage Dark Mode avec effet glassmorphism et bouton microphone intégré.
public struct MessageInputView: View {
    @Binding public var text: String
    public let isTyping: Bool
    public var isMicActive: Bool
    public let onSend: () -> Void
    public var onMicTap: (() -> Void)?
    
    public init(
        text: Binding<String>,
        isTyping: Bool,
        isMicActive: Bool = false,
        onSend: @escaping () -> Void,
        onMicTap: (() -> Void)? = nil
    ) {
        self._text = text
        self.isTyping = isTyping
        self.isMicActive = isMicActive
        self.onSend = onSend
        self.onMicTap = onMicTap
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            // Champ de texte style iMessage Capsule Dark
            HStack(spacing: 8) {
                TextField("Message Sarah AI...", text: $text)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(.white)
                    .disabled(isTyping)
                    .submitLabel(.send)
                    .onSubmit {
                        if canSend {
                            onSend()
                        }
                    }
                
                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.white.opacity(0.4))
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(red: 0.16, green: 0.16, blue: 0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
            )
            
            // Bouton Microphone Dictée Rapide
            if let onMicTap = onMicTap {
                Button(action: onMicTap) {
                    ZStack {
                        Circle()
                            .fill(
                                isMicActive
                                ? LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 1.0, green: 0.25, blue: 0.35),
                                        Color(red: 0.85, green: 0.10, blue: 0.40)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.12),
                                        Color.white.opacity(0.12)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 38, height: 38)
                        
                        Image(systemName: isMicActive ? "mic.fill" : "mic")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(isMicActive ? .white : Color.white.opacity(0.75))
                    }
                }
                .scaleEffect(isMicActive ? 1.08 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isMicActive)
            }
            
            // Bouton d'envoi iMessage Arrow
            Button(action: onSend) {
                ZStack {
                    Circle()
                        .fill(
                            canSend
                            ? LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.12, green: 0.53, blue: 0.98),
                                    Color(red: 0.05, green: 0.45, blue: 0.90)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.12),
                                    Color.white.opacity(0.12)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)
                    
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(canSend ? .white : Color.white.opacity(0.3))
                }
            }
            .disabled(!canSend)
            .scaleEffect(canSend ? 1.0 : 0.92)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: canSend)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Color(red: 0.10, green: 0.10, blue: 0.12)
                .ignoresSafeArea(edges: .bottom)
        )
    }
    
    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isTyping
    }
}

// MARK: - Preview

struct MessageInputView_Previews: PreviewProvider {
    static var previews: some View {
        MessageInputView(text: .constant("Bonjour !"), isTyping: false, isMicActive: true, onSend: {}, onMicTap: {})
            .background(Color.black)
            .preferredColorScheme(.dark)
    }
}
