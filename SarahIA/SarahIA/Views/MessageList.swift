import SwiftUI

/// Vue de liste de messages 100% native SwiftUI (MessageList) assurant un affichage fluide et performant du fil de discussion.
@available(iOS 14.0, *)
public struct MessageList: View {
    public let messages: [Message]
    public let isTyping: Bool
    public var isKeyboardVisible: Bool = false
    public var onToggleSpeech: ((Message) -> Void)?
    public var onSelectSuggestion: ((String) -> Void)?
    public var onIntroduceSarah: (() -> Void)?
    public var onDismissKeyboard: (() -> Void)?
    
    public init(
        messages: [Message],
        isTyping: Bool,
        isKeyboardVisible: Bool = false,
        onToggleSpeech: ((Message) -> Void)? = nil,
        onSelectSuggestion: ((String) -> Void)? = nil,
        onIntroduceSarah: (() -> Void)? = nil,
        onDismissKeyboard: (() -> Void)? = nil
    ) {
        self.messages = messages
        self.isTyping = isTyping
        self.isKeyboardVisible = isKeyboardVisible
        self.onToggleSpeech = onToggleSpeech
        self.onSelectSuggestion = onSelectSuggestion
        self.onIntroduceSarah = onIntroduceSarah
        self.onDismissKeyboard = onDismissKeyboard
    }
    
    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    if messages.isEmpty {
                        emptyStateSuggestions
                            .padding(.top, 24)
                    } else {
                        ForEach(messages) { message in
                            ChatBubbleView(
                                message: message,
                                isPlayingAudio: SpeechManager.shared.isSpeaking && SpeechManager.shared.currentSpokenText == message.content,
                                onPlayTapped: {
                                    onToggleSpeech?(message)
                                }
                            )
                            .id(message.id)
                        }
                        
                        if isTyping {
                            HStack {
                                TypingIndicatorView()
                                    .padding(.leading, 8)
                                Spacer()
                            }
                            .id("typing_indicator")
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 12)
            }
            // Défilement automatique lors de nouveaux messages
            .onChange(of: messages.count) { _ in
                scrollToBottom(proxy: proxy)
            }
            // Défilement automatique lors de la saisie par Sarah
            .onChange(of: isTyping) { typing in
                if typing {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo("typing_indicator", anchor: .bottom)
                    }
                }
            }
            // Défilement automatique lors de l'ouverture du clavier
            .onChange(of: isKeyboardVisible) { visible in
                if visible {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        scrollToBottom(proxy: proxy)
                    }
                }
            }
            // Fermeture du clavier au glissement vers le bas
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 15 && isKeyboardVisible {
                            onDismissKeyboard?()
                        }
                    }
            )
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let last = messages.last {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
    
    // MARK: - Suggestions d'accueil quand la discussion est vierge
    
    private var emptyStateSuggestions: some View {
        VStack(alignment: .leading, spacing: 10) {
            // En-tête d'accueil Sarah IA
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("👋")
                        .font(.system(size: 26))
                    Text("Comment puis-je vous aider ?")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Text("Posez une question, dictez vocalement ou explorez les suggestions ci-dessous.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.6))
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 14)
            
            // Liste des suggestions
            VStack(spacing: 8) {
                suggestionCard(
                    title: "🔦 Allumer la torche",
                    subtitle: "Contrôler la lampe de l'appareil instantanément",
                    icon: "flashlight.on.fill",
                    prefill: "Allume la torche"
                )
                
                suggestionCard(
                    title: "🔋 Niveau de batterie",
                    subtitle: "Vérifier le pourcentage et la charge",
                    icon: "battery.100.bolt",
                    prefill: "Quel est le niveau de batterie ?"
                )
                
                suggestionCard(
                    title: "⏰ Demander l'heure & la date",
                    subtitle: "Heure exacte et date du jour",
                    icon: "clock.fill",
                    prefill: "Quelle heure est-il ?"
                )
                
                suggestionCard(
                    title: "😂 Raconter une blague",
                    subtitle: "Un moment de détente et d'humour",
                    icon: "face.smiling.fill",
                    prefill: "Raconte-moi une blague"
                )
                
                suggestionCard(
                    title: "✨ Présente-toi",
                    subtitle: "Découvrez les capacités de Sarah",
                    icon: "sparkles",
                    action: {
                        onIntroduceSarah?()
                    }
                )
            }
        }
        .padding(.horizontal, 6)
        .transition(.opacity)
    }
    
    @ViewBuilder
    private func suggestionCard(
        title: String,
        subtitle: String,
        icon: String,
        prefill: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        Button(action: {
            HapticService.shared.buttonTap()
            if let act = action {
                act()
            } else if let p = prefill {
                onSelectSuggestion?(p)
            }
        }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(red: 0.16, green: 0.16, blue: 0.18))
                        .frame(width: 38, height: 38)
                    
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.55))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.3))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(red: 0.11, green: 0.11, blue: 0.12))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
            )
        }
        .buttonStyle(ScaleBounceButtonStyle())
    }
}
