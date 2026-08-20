import SwiftUI

/// Barre de saisie 100% native SwiftUI (MessageBar) avec gestion du texte, dictée vocale et actions rapides.
@available(iOS 14.0, *)
public struct MessageBar: View {
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
        HStack(spacing: 8) {
            // 1. Bouton Action Rapide / Ajout (+)
            Button(action: {
                HapticService.shared.buttonTap()
                onPlusTapped?()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(ScaleBounceButtonStyle())
            
            // 2. Champ de Saisie Texte
            TextField("Demander à Sarah...", text: $text, onCommit: {
                submitMessage()
            })
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white)
                .accentColor(Color(red: 0.04, green: 0.52, blue: 1.0))
                .autocapitalization(.sentences)
                .disableAutocorrection(false)
                .padding(.horizontal, 4)
            
            // 3. Bouton Dictée Vocale / Microphone
            Button(action: {
                onToggleMic()
            }) {
                ZStack {
                    Circle()
                        .fill(isRecording ? Color.red.opacity(0.2) : Color.clear)
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: isRecording ? "mic.fill" : "mic")
                        .font(.system(size: 18, weight: isRecording ? .bold : .medium))
                        .foregroundColor(isRecording ? Color.red : Color.white.opacity(0.85))
                        .scaleEffect(isRecording ? 1.15 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isRecording)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // 4. Bouton Envoi / Onde Vocale Dynamique
            Button(action: {
                submitMessage()
            }) {
                ZStack {
                    Circle()
                        .fill(
                            text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color(red: 0.18, green: 0.18, blue: 0.20)
                                : Color(red: 0.04, green: 0.52, blue: 1.0)
                        )
                        .frame(width: 38, height: 38)
                    
                    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Image(systemName: "waveform")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(ScaleBounceButtonStyle())
        }
        .padding(.leading, 10)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(Color(red: 0.11, green: 0.11, blue: 0.12))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
        )
        .padding(.horizontal, 16)
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 4)
    }
    
    private func submitMessage() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            HapticService.shared.buttonTap()
            onSend(trimmed)
            text = ""
        } else {
            onToggleMic()
        }
    }
}
