import SwiftUI

/// Bulle de message stylisée au format natif iMessage Dark Mode.
public struct ChatBubbleView: View {
    public let message: Message
    
    public init(message: Message) {
        self.message = message
    }
    
    public var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isFromUser {
                Spacer(minLength: 50)
                userBubble
            } else {
                aiBubble
                Spacer(minLength: 50)
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
    
    // MARK: - Bulle Sarah AI (Gris Charcoal Sombre Haute Lisibilité)
    
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
            
            VStack(alignment: .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Color(red: 0.16, green: 0.16, blue: 0.18) // Apple Dark Bubble Gray
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 19, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
                
                Text(message.formattedTime)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.4))
                    .padding(.leading, 4)
            }
        }
    }
}

// MARK: - Preview

struct ChatBubbleView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ChatBubbleView(message: Message(content: "Bonjour Sarah !", isFromUser: true))
            ChatBubbleView(message: Message(content: "Bonjour ! Comment puis-je vous aider ?", isFromUser: false))
        }
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}

