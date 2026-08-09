import SwiftUI

/// Barre de saisie de message iMessage Dark Mode avec effet glassmorphism.
public struct MessageInputView: View {
    @Binding public var text: String
    public let isTyping: Bool
    public let onSend: () -> Void
    
    public init(text: Binding<String>, isTyping: Bool, onSend: @escaping () -> Void) {
        self._text = text
        self.isTyping = isTyping
        self.onSend = onSend
    }
    
    public var body: some View {
        HStack(spacing: 10) {
            // Champ de texte style iMessage Capsule Dark
            HStack {
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
        MessageInputView(text: .constant("Bonjour !"), isTyping: false) {}
            .background(Color.black)
            .preferredColorScheme(.dark)
    }
}
