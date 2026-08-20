import SwiftUI

/// Barre de Saisie (Composer) réutilisant le composant natif standard MessageBar.
@available(iOS 14.0, *)
public struct MessageInputView: View {
    @Binding var text: String
    var isRecording: Bool
    var onSend: (String) -> Void
    var onToggleMic: () -> Void
    var onPlusTapped: (() -> Void)? = nil
    
    public init(
        text: Binding<String>,
        isRecording: Bool,
        onSend: @escaping (String) -> Void,
        onToggleMic: @escaping () -> Void,
        onPlusTapped: (() -> Void)? = nil
    ) {
        self._text = text
        self.isRecording = isRecording
        self.onSend = onSend
        self.onToggleMic = onToggleMic
        self.onPlusTapped = onPlusTapped
    }
    
    public var body: some View {
        MessageBar(
            text: $text,
            isRecording: isRecording,
            onSend: onSend,
            onToggleMic: onToggleMic,
            onPlusTapped: onPlusTapped
        )
    }
}

