import SwiftUI

/// Barre de saisie 100% native SwiftUI (MessageBar) avec Capsule Vocale Dédiée,
/// sélecteur rapide des agents (Sarah, Tom, Esther, Yohan, Nathan, Ethel), dictée vocale continue et actions rapides.
@available(iOS 14.0, *)
public struct MessageBar: View {
    @Binding var text: String
    @Binding var activeAgent: AgentType
    var isRecording: Bool
    var onSend: (String) -> Void
    var onToggleMic: () -> Void
    var onOpenVoiceOrb: () -> Void
    var onOpenVAICoding: () -> Void
    var onPlusTapped: (() -> Void)? = nil
    var onShareVideo: (() -> Void)? = nil
    
    @ObservedObject private var flashlight: ObservableFlashlight
    
    public init(
        text: Binding<String>,
        activeAgent: Binding<AgentType>,
        isRecording: Bool,
        onSend: @escaping (String) -> Void,
        onToggleMic: @escaping () -> Void,
        onOpenVoiceOrb: @escaping () -> Void,
        onOpenVAICoding: @escaping () -> Void,
        onPlusTapped: (() -> Void)? = nil,
        onShareVideo: (() -> Void)? = nil
    ) {
        self._text = text
        self._activeAgent = activeAgent
        self.isRecording = isRecording
        self.onSend = onSend
        self.onToggleMic = onToggleMic
        self.onOpenVoiceOrb = onOpenVoiceOrb
        self.onOpenVAICoding = onOpenVAICoding
        self.onPlusTapped = onPlusTapped
        self.onShareVideo = onShareVideo
        self._flashlight = ObservedObject(wrappedValue: ObservableFlashlight.shared)
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // 0. Chips / Raccourcis Rapides du haut (Allume la torche, Pikoud HaOref, i24News)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // 0.1 Allume la torche
                    ActionChipButton(
                        icon: flashlight.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill",
                        text: flashlight.isTorchOn ? "Éteins la torche" : "Allume la torche",
                        color: Color(white: 0.20)
                    ) {
                        flashlight.toggleTorch()
                    }
                    
                    // 0.2 Pikoud HaOref (Alerte Rouge)
                    ActionChipButton(
                        icon: "shield.fill",
                        text: "Pikoud HaOref",
                        color: Color.red.opacity(0.75)
                    ) {
                        HapticService.shared.buttonTap()
                        onSend("Alertes Pikoud HaOref")
                    }
                    
                    // 0.3 i24News
                    ActionChipButton(
                        icon: "newspaper.fill",
                        text: "i24news",
                        color: Color.blue.opacity(0.75)
                    ) {
                        HapticService.shared.buttonTap()
                        onSend("Actualités i24news")
                    }
                    
                    // 0.4 WhatsApp (Nathan)
                    ActionChipButton(
                        icon: "bubble.left.and.bubble.right.fill",
                        text: "WhatsApp",
                        color: Color.green.opacity(0.75)
                    ) {
                        HapticService.shared.buttonTap()
                        activeAgent = .nathan
                        onSend("Nathan, je veux mettre une vidéo sur mon statut WhatsApp")
                    }
                }
                .padding(.horizontal, 16)
            }
            
            // 1. Barre de saisie principale (Capsule)
            HStack(spacing: 10) {
                // 1.1 Bouton (+) Action Rapide
                Button(action: {
                    HapticService.shared.buttonTap()
                    onPlusTapped?()
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color(white: 0.22)))
                }
                .buttonStyle(ScaleBounceButtonStyle())
                
                // 1.2 Champ de Saisie Texte
                TextField("Demander à \(activeAgent.rawValue)...", text: $text, onCommit: {
                    submitMessage()
                })
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.white)
                .accentColor(Color(red: 0.15, green: 0.72, blue: 1.0))
                .autocapitalization(.sentences)
                .disableAutocorrection(false)
                .lineLimit(1)
                
                // 1.3 Bouton Dictée Vocale (Microphone)
                Button(action: {
                    onToggleMic()
                }) {
                    Image(systemName: isRecording ? "mic.fill" : "mic")
                        .foregroundColor(isRecording ? Color.red : Color.gray)
                        .font(.system(size: 18))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(PlainButtonStyle())
                
                // 1.4 Bouton Ondes Vocales / Envoi
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(action: {
                        submitMessage()
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(Color(red: 0.15, green: 0.72, blue: 1.0))
                            .font(.system(size: 28))
                    }
                    .buttonStyle(ScaleBounceButtonStyle())
                } else {
                    Button(action: {
                        HapticService.shared.buttonTap()
                        onOpenVoiceOrb()
                    }) {
                        Image(systemName: "waveform")
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color(white: 0.22)))
                    }
                    .buttonStyle(ScaleBounceButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 28).fill(Color(white: 0.12)))
        }
        .padding(.top, 4)
        .padding(.bottom, 6)
        .background(Color.black)
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

// MARK: - ActionChipButton Helper
@available(iOS 13.0, *)
private struct ActionChipButton: View {
    let icon: String
    let text: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(text)
                    .font(.footnote)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(color))
            .foregroundColor(.white)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
