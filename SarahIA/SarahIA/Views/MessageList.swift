import SwiftUI

/// Vue de liste de messages 100% native SwiftUI (MessageList) assurant un affichage fluide et performant du fil de discussion.
@available(iOS 15.0, *)
public struct MessageList: View {
    public let messages: [Message]
    public let isTyping: Bool
    public var isKeyboardVisible: Bool = false
    public var onToggleSpeech: ((Message) -> Void)?
    public var onRetryUserMessage: ((Message) -> Void)?
    public var onSelectSuggestion: ((String) -> Void)?
    public var onIntroduceSarah: (() -> Void)?
    public var onDismissKeyboard: (() -> Void)?
    public var onOpenStudio: (() -> Void)?
    
    public init(
        messages: [Message],
        isTyping: Bool,
        isKeyboardVisible: Bool = false,
        onToggleSpeech: ((Message) -> Void)? = nil,
        onRetryUserMessage: ((Message) -> Void)? = nil,
        onSelectSuggestion: ((String) -> Void)? = nil,
        onIntroduceSarah: (() -> Void)? = nil,
        onDismissKeyboard: (() -> Void)? = nil,
        onOpenStudio: (() -> Void)? = nil
    ) {
        self.messages = messages
        self.isTyping = isTyping
        self.isKeyboardVisible = isKeyboardVisible
        self.onToggleSpeech = onToggleSpeech
        self.onRetryUserMessage = onRetryUserMessage
        self.onSelectSuggestion = onSelectSuggestion
        self.onIntroduceSarah = onIntroduceSarah
        self.onDismissKeyboard = onDismissKeyboard
        self.onOpenStudio = onOpenStudio
    }
    
    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    if messages.isEmpty {
                        // Écran épuré et vierge : discussion directe sans encombrement
                        Spacer()
                            .frame(height: 40)
                    } else {
                        ForEach(visibleMessages) { message in
                            ChatBubbleView(
                                message: message,
                                isPlayingAudio: SpeechManager.shared.isSpeaking && SpeechManager.shared.currentSpokenText == message.content,
                                onPlayTapped: {
                                    onToggleSpeech?(message)
                                },
                                onRetry: message.isFromUser ? {
                                    onRetryUserMessage?(message)
                                } : nil,
                                onOpenStudio: onOpenStudio
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
    
    private var visibleMessages: [Message] {
        messages.filter { !$0.isInternalEngineLeak }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let last = visibleMessages.last {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}

