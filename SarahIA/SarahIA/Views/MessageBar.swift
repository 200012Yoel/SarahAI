import SwiftUI

/// Barre de saisie 100% native SwiftUI (MessageBar) avec Capsule Vocale Dédiée,
/// sélecteur rapide des 4 agents (Sarah, Tom, Raphaël, Yohan), dictée vocale continue et actions rapides.
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
    
    @ObservedObject private var flashlight: ObservableFlashlight
    
    public init(
        text: Binding<String>,
        activeAgent: Binding<AgentType>,
        isRecording: Bool,
        onSend: @escaping (String) -> Void,
        onToggleMic: @escaping () -> Void,
        onOpenVoiceOrb: @escaping () -> Void,
        onOpenVAICoding: @escaping () -> Void,
        onPlusTapped: (() -> Void)? = nil
    ) {
        self._text = text
        self._activeAgent = activeAgent
        self.isRecording = isRecording
        self.onSend = onSend
        self.onToggleMic = onToggleMic
        self.onOpenVoiceOrb = onOpenVoiceOrb
        self.onOpenVAICoding = onOpenVAICoding
        self.onPlusTapped = onPlusTapped
        self._flashlight = ObservedObject(wrappedValue: ObservableFlashlight.shared)
    }
    
    public var body: some View {
        GeometryReader { geo in
            let isCompact = geo.size.width <= 360
            let btnSize: CGFloat = isCompact ? 34 : 36
            let sendBtnSize: CGFloat = isCompact ? 36 : 38
            
            VStack(spacing: 8) {
                // 0. Sélecteur Défilant des 4 Agents & Raccourcis Rapides (Sarah, Tom, Raphaël, Yohan, Torche)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // 0.1 Sélecteur des 4 Agents Autonomes
                        ForEach(AgentType.allCases) { agent in
                            Button(action: {
                                HapticService.shared.buttonTap()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    activeAgent = agent
                                }
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: agent.iconName)
                                        .font(.system(size: isCompact ? 11 : 12, weight: .bold))
                                    Text(agent.rawValue)
                                        .font(.system(size: isCompact ? 11 : 12, weight: .bold))
                                }
                                .foregroundColor(activeAgent == agent ? (agent == .yohan ? .white : .black) : .white)
                                .padding(.horizontal, isCompact ? 10 : 12)
                                .padding(.vertical, 6)
                                .background(
                                    activeAgent == agent
                                        ? agent.themeColor
                                        : Color(red: 0.16, green: 0.16, blue: 0.20)
                                )
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(
                                        activeAgent == agent ? Color.white.opacity(0.8) : Color.white.opacity(0.12),
                                        lineWidth: 1
                                    )
                                )
                                .shadow(
                                    color: activeAgent == agent ? agent.themeColor.opacity(0.5) : Color.clear,
                                    radius: 6,
                                    x: 0,
                                    y: 2
                                )
                            }
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        
                        // 0.2 Bouton Torche Rapide
                        Button(action: {
                            flashlight.toggleTorch()
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: flashlight.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                    .font(.system(size: isCompact ? 11 : 12, weight: .bold))
                                Text(flashlight.isTorchOn ? "Éteindre" : "Torche")
                                    .font(.system(size: isCompact ? 11 : 12, weight: .semibold))
                            }
                            .foregroundColor(flashlight.isTorchOn ? .black : .white)
                            .padding(.horizontal, isCompact ? 10 : 12)
                            .padding(.vertical, 6)
                            .background(
                                flashlight.isTorchOn
                                    ? Color(red: 0.98, green: 0.82, blue: 0.20)
                                    : Color(red: 0.18, green: 0.18, blue: 0.22)
                            )
                            .clipShape(Capsule())
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        
                        // 0.3 Bouton Studio VAI Coding
                        Button(action: {
                            HapticService.shared.buttonTap()
                            onOpenVAICoding()
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "curlybraces")
                                    .font(.system(size: isCompact ? 11 : 12, weight: .bold))
                                Text("VAI Coding")
                                    .font(.system(size: isCompact ? 11 : 12, weight: .semibold))
                            }
                            .foregroundColor(Color(red: 0.15, green: 0.72, blue: 1.0))
                            .padding(.horizontal, isCompact ? 10 : 12)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.15, green: 0.72, blue: 1.0).opacity(0.18))
                            .clipShape(Capsule())
                        }
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.horizontal, isCompact ? 10 : 16)
                }
                .frame(maxWidth: .infinity)
                
                // 1. Barre de saisie principale avec Bouton Capsule Audio
                HStack(spacing: isCompact ? 6 : 8) {
                    // 1.1 Bouton Action Rapide / Ajout (+)
                    Button(action: {
                        HapticService.shared.buttonTap()
                        onPlusTapped?()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: btnSize, height: btnSize)
                            
                            Image(systemName: "plus")
                                .font(.system(size: isCompact ? 15 : 17, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(ScaleBounceButtonStyle())
                    
                    // 1.2 Champ de Saisie Texte Dynamique
                    TextField("Demander à \(activeAgent.rawValue)...", text: $text, onCommit: {
                        submitMessage()
                    })
                        .font(.system(size: isCompact ? 15 : 16, weight: .regular))
                        .foregroundColor(.white)
                        .accentColor(activeAgent.themeColor)
                        .autocapitalization(.sentences)
                        .disableAutocorrection(false)
                        .padding(.horizontal, 4)
                        .lineLimit(1)
                    
                    // 1.3 BOUTON CAPSULE AUDIO (Pastille à ondes blanches pour ouvrir Voice Orb)
                    Button(action: {
                        HapticService.shared.buttonTap()
                        onOpenVoiceOrb()
                    }) {
                        ZStack {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [activeAgent.themeColor, activeAgent.themeColor.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: isCompact ? 40 : 44, height: btnSize)
                                .shadow(color: activeAgent.themeColor.opacity(0.5), radius: 6)
                            
                            HStack(spacing: 2) {
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.white)
                                    .frame(width: 2.5, height: 10)
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.white)
                                    .frame(width: 2.5, height: 16)
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.white)
                                    .frame(width: 2.5, height: 8)
                            }
                        }
                    }
                    .buttonStyle(ScaleBounceButtonStyle())
                    
                    // 1.4 Bouton Dictée Vocale / Microphone Direct
                    Button(action: {
                        onToggleMic()
                    }) {
                        ZStack {
                            Circle()
                                .fill(isRecording ? Color.red.opacity(0.25) : Color.clear)
                                .frame(width: btnSize, height: btnSize)
                            
                            Image(systemName: isRecording ? "mic.fill" : "mic")
                                .font(.system(size: isCompact ? 16 : 18, weight: isRecording ? .bold : .medium))
                                .foregroundColor(isRecording ? Color.red : Color.white.opacity(0.85))
                                .scaleEffect(isRecording ? 1.15 : 1.0)
                                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isRecording)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // 1.5 Bouton Envoi / Validation
                    Button(action: {
                        submitMessage()
                    }) {
                        ZStack {
                            Circle()
                                .fill(
                                    text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                        ? Color(red: 0.18, green: 0.18, blue: 0.20)
                                        : activeAgent.themeColor
                                )
                                .frame(width: sendBtnSize, height: sendBtnSize)
                            
                            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: isCompact ? 15 : 17, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.4))
                            } else {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: isCompact ? 15 : 17, weight: .bold))
                                    .foregroundColor(activeAgent == .yohan ? .white : .black)
                            }
                        }
                    }
                    .buttonStyle(ScaleBounceButtonStyle())
                }
                .padding(.leading, isCompact ? 8 : 10)
                .padding(.trailing, isCompact ? 6 : 8)
                .padding(.vertical, 6)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.13, green: 0.13, blue: 0.16), Color(red: 0.08, green: 0.08, blue: 0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [activeAgent.themeColor.opacity(0.5), Color.white.opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.0
                        )
                )
                .padding(.horizontal, isCompact ? 10 : 16)
                .shadow(color: activeAgent.themeColor.opacity(0.15), radius: 12, x: 0, y: 4)
            }
        }
        .frame(height: 98)
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
