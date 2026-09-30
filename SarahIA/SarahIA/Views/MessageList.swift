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
    public var onRegenerate: ((Message) -> Void)?
    public var onOpenStudio: (() -> Void)?

    public init(
        messages: [Message],
        isTyping: Bool,
        isKeyboardVisible: Bool = false,
        onToggleSpeech: ((Message) -> Void)? = nil,
        onSelectSuggestion: ((String) -> Void)? = nil,
        onIntroduceSarah: (() -> Void)? = nil,
        onDismissKeyboard: (() -> Void)? = nil,
        onRegenerate: ((Message) -> Void)? = nil,
        onOpenStudio: (() -> Void)? = nil
    ) {
        self.messages = messages
        self.isTyping = isTyping
        self.isKeyboardVisible = isKeyboardVisible
        self.onToggleSpeech = onToggleSpeech
        self.onSelectSuggestion = onSelectSuggestion
        self.onIntroduceSarah = onIntroduceSarah
        self.onDismissKeyboard = onDismissKeyboard
        self.onRegenerate = onRegenerate
        self.onOpenStudio = onOpenStudio
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    if messages.isEmpty {
                        Spacer()
                            .frame(height: 40)
                    } else {
                        ForEach(messages) { message in
                            ChatBubbleView(
                                message: message,
                                isPlayingAudio: SpeechManager.shared.isSpeaking && SpeechManager.shared.currentSpokenText == message.content,
                                onPlayTapped: {
                                    onToggleSpeech?(message)
                                },
                                onRegenerate: {
                                    onRegenerate?(message)
                                },
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
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) { _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: isTyping) { typing in
                if typing {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo("typing_indicator", anchor: .bottom)
                    }
                }
            }
            .onChange(of: isKeyboardVisible) { visible in
                if visible {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        scrollToBottom(proxy: proxy)
                    }
                }
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let last = messages.last {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}
