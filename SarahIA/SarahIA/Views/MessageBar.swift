import SwiftUI

/// Barre de saisie 100% native SwiftUI (MessageBar) avec Capsule Vocale Dédiée,
/// sélecteur rapide des agents (Sarah, Tom, Esther, Yohan, Nathan, Ethel), dictée vocale et actions rapides.
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
        VStack(spacing: 8) {
            // 1. Boutons d'actions rapides (Shortcuts)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Allume la torche
                    ShortcutButton(
                        title: flashlight.isTorchOn ? "Éteins la torche" : "Allume la torche",
                        icon: flashlight.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill",
                        color: Color(white: 0.2)
                    ) {
                        flashlight.toggleTorch()
                    }
                    
                    // Pikoud HaOref
                    ShortcutButton(
                        title: "Pikoud HaOref",
                        icon: "shield.fill",
                        color: Color(red: 0.8, green: 0.2, blue: 0.2)
                    ) {
                        HapticService.shared.buttonTap()
                        onSend("Alertes Pikoud HaOref")
                    }
                    
                    // i24news
                    ShortcutButton(
                        title: "i24news",
                        icon: "newspaper.fill",
                        color: Color(red: 0.0, green: 0.45, blue: 0.85)
                    ) {
                        HapticService.shared.buttonTap()
                        onSend("Actualités i24news")
                    }
                    
                    // WhatsApp
                    ShortcutButton(
                        title: "WhatsApp",
                        icon: "bubble.left.and.bubble.right.fill",
                        color: Color(red: 0.1, green: 0.55, blue: 0.25)
                    ) {
                        HapticService.shared.buttonTap()
                        activeAgent = .nathan
                        onSend("Nathan, je veux mettre une vidéo sur mon statut WhatsApp")
                    }
                }
                .padding(.horizontal, 16)
            }
            
            // 2. Barre de Saisie
            HStack(spacing: 12) {
                // Bouton Plus ＋
                Button(action: {
                    HapticService.shared.buttonTap()
                    onPlusTapped?()
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                .frame(width: 44, height: 44)
                .background(Color(white: 0.15))
                .clipShape(Circle())
                .buttonStyle(ScaleBounceButtonStyle())
                
                // Champ texte avec Micro intégré
                HStack(spacing: 8) {
                    TextField("Demander à \(activeAgent.rawValue)...", text: $text, onCommit: {
                        submitMessage()
                    })
                    .foregroundColor(.white)
                    .accentColor(.blue)
                    .font(.system(size: 15))
                    
                    Button(action: {
                        onToggleMic()
                    }) {
                        Image(systemName: isRecording ? "mic.fill" : "mic")
                            .foregroundColor(isRecording ? .red : .gray)
                            .font(.system(size: 18))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(Color(white: 0.15))
                .cornerRadius(24)
                
                // Bouton Waveform / Envoi
                let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                Button(action: {
                    if hasText {
                        submitMessage()
                    } else {
                        HapticService.shared.buttonTap()
                        onOpenVoiceOrb()
                    }
                }) {
                    Image(systemName: hasText ? "arrow.up" : "waveform")
                        .font(.system(size: 18, weight: hasText ? .bold : .regular))
                        .foregroundColor(.white)
                }
                .frame(width: 44, height: 44)
                .background(hasText ? Color.blue : Color(white: 0.15))
                .clipShape(Circle())
                .buttonStyle(ScaleBounceButtonStyle())
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 4)
        .padding(.bottom, 4)
        .background(Color.black.ignoresSafeArea(edges: .bottom))
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

// MARK: - ShortcutButton Helper
@available(iOS 13.0, *)
public struct ShortcutButton: View {
    public let title: String
    public let icon: String
    public let color: Color
    public var action: () -> Void
    
    public init(title: String, icon: String, color: Color, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.color = color
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(color)
            .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
