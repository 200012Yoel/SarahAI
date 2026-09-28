from pathlib import Path

repo = Path("SarahIA/SarahIA/Views")
chat_bubble = repo / "ChatBubbleView.swift"
message_list = repo / "MessageList.swift"
chat_screen = repo / "ChatScreenView.swift"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"Missing patch target: {label}")
    return text.replace(old, new, 1)

# 1) ChatBubbleView: restore ChatGPT-like long press actions on user prompts.
s = chat_bubble.read_text()
s = replace_once(
    s,
    '''    public var onSpeak: (() -> Void)?\n    public var onOpenStudio: (() -> Void)?\n''',
    '''    public var onSpeak: (() -> Void)?\n    public var onRegenerate: (() -> Void)?\n    public var onOpenStudio: (() -> Void)?\n''',
    "ChatBubbleView properties"
)
s = replace_once(
    s,
    '''        onSpeak: (() -> Void)? = nil,\n        onPlayTapped: (() -> Void)? = nil,\n        onOpenStudio: (() -> Void)? = nil\n''',
    '''        onSpeak: (() -> Void)? = nil,\n        onPlayTapped: (() -> Void)? = nil,\n        onRegenerate: (() -> Void)? = nil,\n        onOpenStudio: (() -> Void)? = nil\n''',
    "ChatBubbleView init parameters"
)
s = replace_once(
    s,
    '''        self.isSpeaking = isSpeaking || isPlayingAudio\n        self.onSpeak = onSpeak ?? onPlayTapped\n        self.onOpenStudio = onOpenStudio\n''',
    '''        self.isSpeaking = isSpeaking || isPlayingAudio\n        self.onSpeak = onSpeak ?? onPlayTapped\n        self.onRegenerate = onRegenerate\n        self.onOpenStudio = onOpenStudio\n''',
    "ChatBubbleView init assignments"
)
s = replace_once(
    s,
    '''            Text(message.formattedTime)\n                .font(.system(size: 11, weight: .regular, design: .rounded))\n                .foregroundColor(Color.white.opacity(0.4))\n                .padding(.trailing, 4)\n        }\n    }\n\n    private var aiBubble: some View {\n''',
    '''            Text(message.formattedTime)\n                .font(.system(size: 11, weight: .regular, design: .rounded))\n                .foregroundColor(Color.white.opacity(0.4))\n                .padding(.trailing, 4)\n        }\n        .contentShape(Rectangle())\n        .contextMenu {\n            if !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {\n                Button(action: {\n                    UIPasteboard.general.string = message.content\n                    HapticService.shared.notificationSuccess()\n                }) {\n                    Label("Copier", systemImage: "doc.on.doc")\n                }\n\n                Button(action: {\n                    HapticService.shared.buttonTap()\n                    onRegenerate?()\n                }) {\n                    Label("Régénérer", systemImage: "arrow.clockwise")\n                }\n            }\n        }\n        .accessibilityHint("Maintenez appuyé pour copier ou régénérer ce message")\n    }\n\n    private var aiBubble: some View {\n''',
    "user message context menu"
)
chat_bubble.write_text(s)

# 2) MessageList: expose the regenerate callback and avoid an exclusive drag gesture
# stealing interaction from the bubble's long-press context menu.
s = message_list.read_text()
s = replace_once(
    s,
    '''    public var onDismissKeyboard: (() -> Void)?\n    public var onOpenStudio: (() -> Void)?\n''',
    '''    public var onDismissKeyboard: (() -> Void)?\n    public var onRegenerate: ((Message) -> Void)?\n    public var onOpenStudio: (() -> Void)?\n''',
    "MessageList properties"
)
s = replace_once(
    s,
    '''        onIntroduceSarah: (() -> Void)? = nil,\n        onDismissKeyboard: (() -> Void)? = nil,\n        onOpenStudio: (() -> Void)? = nil\n''',
    '''        onIntroduceSarah: (() -> Void)? = nil,\n        onDismissKeyboard: (() -> Void)? = nil,\n        onRegenerate: ((Message) -> Void)? = nil,\n        onOpenStudio: (() -> Void)? = nil\n''',
    "MessageList init parameters"
)
s = replace_once(
    s,
    '''        self.onIntroduceSarah = onIntroduceSarah\n        self.onDismissKeyboard = onDismissKeyboard\n        self.onOpenStudio = onOpenStudio\n''',
    '''        self.onIntroduceSarah = onIntroduceSarah\n        self.onDismissKeyboard = onDismissKeyboard\n        self.onRegenerate = onRegenerate\n        self.onOpenStudio = onOpenStudio\n''',
    "MessageList init assignments"
)
s = replace_once(
    s,
    '''                                onPlayTapped: {\n                                    onToggleSpeech?(message)\n                                },\n                                onOpenStudio: onOpenStudio\n''',
    '''                                onPlayTapped: {\n                                    onToggleSpeech?(message)\n                                },\n                                onRegenerate: {\n                                    onRegenerate?(message)\n                                },\n                                onOpenStudio: onOpenStudio\n''',
    "MessageList ChatBubble callback"
)
s = replace_once(
    s,
    '''            .gesture(\n                DragGesture()\n''',
    '''            .simultaneousGesture(\n                DragGesture()\n''',
    "MessageList simultaneous drag gesture"
)
message_list.write_text(s)

# 3) ChatScreenView: Regenerate really re-asks the selected user prompt.
s = chat_screen.read_text()
s = replace_once(
    s,
    '''                    onDismissKeyboard: {\n                        keyboard.dismiss()\n                    },\n                    onOpenStudio: {\n''',
    '''                    onDismissKeyboard: {\n                        keyboard.dismiss()\n                    },\n                    onRegenerate: { message in\n                        let prompt = message.content.trimmingCharacters(in: .whitespacesAndNewlines)\n                        guard !prompt.isEmpty else { return }\n                        keyboard.dismiss()\n                        viewModel.cancelCurrentGeneration()\n                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {\n                            viewModel.sendMessage(prompt)\n                        }\n                    },\n                    onOpenStudio: {\n''',
    "ChatScreen regenerate wiring"
)
chat_screen.write_text(s)

print("Long-press message actions restored: Copy + Regenerate")
