import SwiftUI

/// Barre de saisie de message avec effet glassmorphism.
struct MessageInputView: View {
    @Binding var text: String
    let isTyping: Bool
    let onSend: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Champ de saisie
            TextField("Posez votre question...", text: $text)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color(.systemGray6))
                )
                .disabled(isTyping)
                .submitLabel(.send)
                .onSubmit {
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isTyping {
                        onSend()
                    }
                }
            
            // Bouton d'envoi
            Button(action: onSend) {
                ZStack {
                    Circle()
                        .fill(
                            canSend
                            ? LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.0, green: 0.34, blue: 0.64),
                                    Color(red: 0.0, green: 0.45, blue: 0.78)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                gradient: Gradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.3)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(45))
                        .offset(x: -1, y: -1)
                }
            }
            .disabled(!canSend)
            .scaleEffect(canSend ? 1.0 : 0.9)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: canSend)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
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
        MessageInputView(text: .constant("Bonjour !"), isTyping: false) {
            // Action d'envoi
        }
    }
}
