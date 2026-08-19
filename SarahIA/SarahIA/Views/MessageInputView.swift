import SwiftUI

/// Barre de Saisie (Composer) Pixel-Perfect 100% Native SwiftUI reproduisant la classe .composer de la maquette.
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
        HStack(spacing: 10) {
            // 1. Bouton Plus (+) (#btnPlus)
            Button(action: {
                HapticService.shared.buttonTap()
                onPlusTapped?()
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(PlainButtonStyle())
            
            // 2. Champ de saisie (#input)
            TextField("Demander à Sarah", text: $text)
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(.white)
                .accentColor(Color(red: 0.04, green: 0.52, blue: 1.0)) // #0a84ff
                .autocapitalization(.sentences)
                .disableAutocorrection(false)
                .submitLabel(.send)
                .onSubmit {
                    submitMessage()
                }
            
            // 3. Bouton Dictée Microphone (#btnMic)
            Button(action: {
                onToggleMic()
            }) {
                Image(systemName: isRecording ? "mic.fill" : "mic")
                    .font(.system(size: 20, weight: isRecording ? .bold : .regular))
                    .foregroundColor(isRecording ? Color.red : Color.white)
                    .frame(width: 38, height: 38)
                    .scaleEffect(isRecording ? 1.15 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isRecording)
            }
            .buttonStyle(PlainButtonStyle())
            
            // 4. Bouton Dynamique Onde / Flèche Bleue (#btnSend)
            Button(action: {
                submitMessage()
            }) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.04, green: 0.52, blue: 1.0)) // #0a84ff
                        .frame(width: 40, height: 40)
                    
                    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        // Icône d'ondes vocales
                        Image(systemName: "waveform")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    } else {
                        // Icône flèche d'envoi vers le haut
                        Image(systemName: "arrow.up")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(ScaleBounceButtonStyle())
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(Color(red: 0.11, green: 0.11, blue: 0.12)) // #1c1c1e
        .cornerRadius(30)
        .padding(.horizontal, 14)
    }
    
    private func submitMessage() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            HapticService.shared.buttonTap()
            onSend(trimmed)
            text = ""
        } else {
            // Si le texte est vide, déclenche le mode vocal
            onToggleMic()
        }
    }
}
