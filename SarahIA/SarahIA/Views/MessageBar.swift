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
                // 0. Chips / Raccourcis Rapides du haut (Allume la torche, Pikoud HaOref, i24News, YouTube)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // 0.1 Allume la torche
                        Button(action: {
                            flashlight.toggleTorch()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: flashlight.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                    .font(.system(size: isCompact ? 12 : 13, weight: .semibold))
                                Text(flashlight.isTorchOn ? "Éteins la torche" : "Allume la torche")
                                    .font(.system(size: isCompact ? 12 : 13, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, isCompact ? 12 : 14)
                            .padding(.vertical, 7)
                            .background(Color(red: 0.14, green: 0.16, blue: 0.20))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        
                        // 0.2 Pikoud HaOref (Alerte Rouge)
                        Button(action: {
                            HapticService.shared.buttonTap()
                            onSend("Alertes Pikoud HaOref")
                        }) {
                            HStack(spacing: 6) {
                                Text("🚨")
                                    .font(.system(size: isCompact ? 12 : 13))
                                Text("Pikoud HaOref")
                                    .font(.system(size: isCompact ? 12 : 13, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, isCompact ? 12 : 14)
                            .padding(.vertical, 7)
                            .background(Color(red: 0.35, green: 0.12, blue: 0.14))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        
                        // 0.3 i24News
                        Button(action: {
                            HapticService.shared.buttonTap()
                            onSend("Actualités i24news")
                        }) {
                            HStack(spacing: 6) {
                                Text("📰")
                                    .font(.system(size: isCompact ? 12 : 13))
                                Text("i24news")
                                    .font(.system(size: isCompact ? 12 : 13, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, isCompact ? 12 : 14)
                            .padding(.vertical, 7)
                            .background(Color(red: 0.12, green: 0.18, blue: 0.28))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        
                        // 0.4 YouTube
                        Button(action: {
                            HapticService.shared.buttonTap()
                            onSend("YouTube")
                        }) {
                            HStack(spacing: 6) {
                                Text("▶️")
                                    .font(.system(size: isCompact ? 12 : 13))
                                Text("YouTube")
                                    .font(.system(size: isCompact ? 12 : 13, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, isCompact ? 12 : 14)
                            .padding(.vertical, 7)
                            .background(Color(red: 0.20, green: 0.12, blue: 0.12))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.horizontal, isCompact ? 10 : 16)
                }
                .frame(maxWidth: .infinity)
                
                // 1. Barre de saisie principale (Capsule)
                HStack(spacing: isCompact ? 6 : 8) {
                    // 1.1 Bouton (+) Action Rapide
                    Button(action: {
                        HapticService.shared.buttonTap()
                        onPlusTapped?()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.10))
                                .frame(width: btnSize, height: btnSize)
                            
                            Image(systemName: "plus")
                                .font(.system(size: isCompact ? 16 : 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(ScaleBounceButtonStyle())
                    
                    // 1.2 Champ de Saisie Texte
                    TextField("Demander à Sarah...", text: $text, onCommit: {
                        submitMessage()
                    })
                        .font(.system(size: isCompact ? 14 : 15, weight: .regular))
                        .foregroundColor(.white)
                        .accentColor(Color(red: 0.15, green: 0.72, blue: 1.0))
                        .autocapitalization(.sentences)
                        .disableAutocorrection(false)
                        .padding(.horizontal, 4)
                        .lineLimit(1)
                    
                    // 1.3 Bouton Caméra
                    Button(action: {
                        HapticService.shared.buttonTap()
                        onPlusTapped?()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.10))
                                .frame(width: btnSize, height: btnSize)
                            
                            Image(systemName: "camera.fill")
                                .font(.system(size: isCompact ? 13 : 15, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(ScaleBounceButtonStyle())
                    
                    // 1.4 Bouton Dictée Vocale (Microphone)
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
                    
                    // 1.5 Bouton Mode Vocal / Ondes (Ouvre le mode vocal / Voice Orb)
                    Button(action: {
                        HapticService.shared.buttonTap()
                        onOpenVoiceOrb()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.12))
                                .frame(width: sendBtnSize, height: sendBtnSize)
                            
                            HStack(spacing: 2.5) {
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.white)
                                    .frame(width: 2.5, height: 10)
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.white)
                                    .frame(width: 2.5, height: 18)
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.white)
                                    .frame(width: 2.5, height: 14)
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.white)
                                    .frame(width: 2.5, height: 8)
                            }
                        }
                    }
                    .buttonStyle(ScaleBounceButtonStyle())
                }
                .padding(.leading, isCompact ? 8 : 10)
                .padding(.trailing, isCompact ? 6 : 8)
                .padding(.vertical, 6)
                .background(Color(red: 0.10, green: 0.11, blue: 0.14))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [Color(red: 0.15, green: 0.72, blue: 1.0).opacity(0.4), Color.white.opacity(0.10)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.0
                        )
                )
                .padding(.horizontal, isCompact ? 10 : 16)
                .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
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
