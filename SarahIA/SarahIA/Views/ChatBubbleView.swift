import SwiftUI

/// Bulle de message stylisée pour les messages utilisateur et IA.
struct ChatBubbleView: View {
    let message: Message
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isFromUser {
                Spacer(minLength: 60)
                userBubble
            } else {
                aiBubble
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 3)
    }
    
    // MARK: - Bulle utilisateur (bleue, à droite)
    
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
                            Color(red: 0.0, green: 0.34, blue: 0.64),  // #0058A3
                            Color(red: 0.0, green: 0.45, blue: 0.78)   // #0073C8
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(BubbleShape(isFromUser: true))
            
            Text(message.formattedTime)
                .font(.system(size: 11, weight: .light, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.trailing, 4)
        }
    }
    
    // MARK: - Bulle IA (grise, à gauche)
    
    private var aiBubble: some View {
        HStack(alignment: .top, spacing: 8) {
            // Avatar Sarah
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.55, green: 0.35, blue: 0.85),
                                Color(red: 0.35, green: 0.25, blue: 0.75)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                
                Text("🤖")
                    .font(.system(size: 16))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Sarah IA")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(red: 0.55, green: 0.35, blue: 0.85))
                
                Text(message.content)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Color(.systemGray6)
                    )
                    .clipShape(BubbleShape(isFromUser: false))
                
                Text(message.formattedTime)
                    .font(.system(size: 11, weight: .light, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
            }
        }
    }
}

// MARK: - Forme de bulle personnalisée

/// Forme de bulle avec un coin pointu du côté de l'expéditeur.
struct BubbleShape: Shape {
    let isFromUser: Bool
    
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18
        let tailSize: CGFloat = 6
        
        var path = Path()
        
        if isFromUser {
            // Bulle utilisateur : coin pointu en bas à droite
            path.addRoundedRect(
                in: CGRect(x: rect.minX, y: rect.minY, width: rect.width - tailSize, height: rect.height),
                cornerSize: CGSize(width: radius, height: radius)
            )
        } else {
            // Bulle IA : coin pointu en bas à gauche
            path.addRoundedRect(
                in: CGRect(x: rect.minX + tailSize, y: rect.minY, width: rect.width - tailSize, height: rect.height),
                cornerSize: CGSize(width: radius, height: radius)
            )
        }
        
        return path
    }
}

// MARK: - Preview

struct ChatBubbleView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ChatBubbleView(message: Message(content: "Bonjour Sarah !", isFromUser: true))
            ChatBubbleView(message: Message(content: "Bonjour ! 👋 Comment puis-je vous aider ?", isFromUser: false))
        }
        .padding()
    }
}
