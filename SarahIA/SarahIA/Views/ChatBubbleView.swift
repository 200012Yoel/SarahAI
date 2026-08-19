import SwiftUI

/// Bulle de message stylisée au format natif iMessage Dark Mode avec bouton de lecture vocale TTS.
public struct ChatBubbleView: View {
    public let message: Message
    public var isSpeaking: Bool
    public var onSpeak: (() -> Void)?
    
    public init(
        message: Message,
        isSpeaking: Bool = false,
        isPlayingAudio: Bool = false,
        onSpeak: (() -> Void)? = nil,
        onPlayTapped: (() -> Void)? = nil
    ) {
        self.message = message
        self.isSpeaking = isSpeaking || isPlayingAudio
        self.onSpeak = onSpeak ?? onPlayTapped
    }
    
    public var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isFromUser {
                Spacer(minLength: 40)
                userBubble
            } else {
                aiBubble
                Spacer(minLength: 40)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }
    
    // MARK: - Bulle Utilisateur (iMessage Bleu)
    
    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(message.content)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.12, green: 0.53, blue: 0.98), // Apple iMessage Blue
                            Color(red: 0.05, green: 0.45, blue: 0.90)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 1)
            
            Text(message.formattedTime)
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundColor(Color.white.opacity(0.4))
                .padding(.trailing, 4)
        }
    }
    
    // MARK: - Bulle Sarah AI (Gris Charcoal Sombre Haute Lisibilité + Bouton Écouter)
    
    private var aiBubble: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Miniature Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.35, green: 0.55, blue: 1.0),
                                Color(red: 0.70, green: 0.30, blue: 0.95)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                
                Text("👩🏻‍💼")
                    .font(.system(size: 14))
            }
            
            VStack(alignment: .leading, spacing: 6) {
                // Contenu du message
                Text(message.content)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(.white)
                    .lineSpacing(3)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Color(red: 0.16, green: 0.16, blue: 0.18) // Apple Dark Bubble Gray
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 19, style: .continuous)
                            .stroke(
                                isSpeaking ? Color.cyan.opacity(0.6) : Color.white.opacity(0.08),
                                lineWidth: isSpeaking ? 1.5 : 0.5
                            )
                    )
                    .shadow(color: isSpeaking ? Color.cyan.opacity(0.2) : Color.clear, radius: 8, x: 0, y: 0)
                
                // Barre d'action inférieure : Heure + Bouton Écouter la réponse
                HStack(spacing: 8) {
                    Text(message.formattedTime)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.4))
                        .padding(.leading, 4)
                    
                    // 🔊 Bouton Écouter / Relire la réponse de Sarah
                    Button(action: {
                        onSpeak?()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(isSpeaking ? .cyan : .white.opacity(0.8))
                            
                            Text(isSpeaking ? "En lecture..." : "Écouter")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(isSpeaking ? .cyan : .white.opacity(0.8))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(isSpeaking ? Color.cyan.opacity(0.2) : Color.white.opacity(0.08))
                                .overlay(
                                    Capsule().stroke(isSpeaking ? Color.cyan.opacity(0.5) : Color.white.opacity(0.12), lineWidth: 0.5)
                                )
                        )
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
        }
    }
}

// MARK: - Preview

struct ChatBubbleView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            ChatBubbleView(message: Message(content: "Bonjour Sarah !", isFromUser: true))
            ChatBubbleView(
                message: Message(content: "Bonjour ! Je suis Sarah, comment puis-je vous aider ?", isFromUser: false),
                isSpeaking: true
            )
            ChatBubbleView(
                message: Message(content: "Voici votre réponse personnalisée.", isFromUser: false),
                isSpeaking: false
            )
        }
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}
