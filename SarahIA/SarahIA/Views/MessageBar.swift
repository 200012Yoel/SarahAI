import SwiftUI

/// Barre de saisie 100% native SwiftUI (MessageBar) avec gestion du texte, dictée vocale et actions rapides adaptatives.
@available(iOS 14.0, *)
public struct MessageBar: View {
    @Binding var text: String
    var isRecording: Bool
    var onSend: (String) -> Void
    var onToggleMic: () -> Void
    var onCamera: (() -> Void)? = nil
    var onPlusTapped: (() -> Void)? = nil
    var onPikudHaOref: (() -> Void)? = nil
    var onI24News: (() -> Void)? = nil
    
    @ObservedObject private var flashlight: ObservableFlashlight
    
    public init(
        text: Binding<String>,
        isRecording: Bool,
        onSend: @escaping (String) -> Void,
        onToggleMic: @escaping () -> Void,
        onCamera: (() -> Void)? = nil,
        onPlusTapped: (() -> Void)? = nil,
        onPikudHaOref: (() -> Void)? = nil,
        onI24News: (() -> Void)? = nil
    ) {
        self._text = text
        self.isRecording = isRecording
        self.onSend = onSend
        self.onToggleMic = onToggleMic
        self.onCamera = onCamera
        self.onPlusTapped = onPlusTapped
        self.onPikudHaOref = onPikudHaOref
        self.onI24News = onI24News
        self._flashlight = ObservedObject(wrappedValue: ObservableFlashlight.shared)
    }
    
    public var body: some View {
        GeometryReader { geo in
            let isCompact = geo.size.width <= 360
            let btnSize: CGFloat = isCompact ? 34 : 36
            let sendBtnSize: CGFloat = isCompact ? 36 : 38
            
            VStack(spacing: 8) {
                // 0. Barre de Raccourcis Rapides Défilante & Adaptative (Torche, Pikoud HaOref, i24NEWS, Batterie)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // 0.1 Bouton d'État de la Torche (Allumer / Éteindre)
                        Button(action: {
                            flashlight.toggleTorch()
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: flashlight.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                    .font(.system(size: isCompact ? 11 : 12, weight: .bold))
                                Text(flashlight.isTorchOn ? "Éteindre" : "Allume la torche")
                                    .font(.system(size: isCompact ? 11 : 12, weight: .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
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
                            .overlay(
                                Capsule().stroke(
                                    flashlight.isTorchOn
                                        ? Color(red: 0.98, green: 0.82, blue: 0.20)
                                        : Color.white.opacity(0.18),
                                    lineWidth: 1
                                )
                            )
                            .shadow(
                                color: flashlight.isTorchOn ? Color(red: 0.98, green: 0.82, blue: 0.20).opacity(0.4) : Color.clear,
                                radius: 6,
                                x: 0,
                                y: 2
                            )
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        
                        // 0.2 Bouton d'Alerte Pikoud HaOref (Interrogation Directe)
                        Button(action: {
                            HapticService.shared.buttonTap()
                            if let onPikud = onPikudHaOref {
                                onPikud()
                            } else {
                                onSend("Y a-t-il des alertes Pikoud HaOref en Israël en ce moment ?")
                            }
                        }) {
                            HStack(spacing: 5) {
                                Text("🚨")
                                    .font(.system(size: isCompact ? 11 : 12))
                                Text("Pikoud HaOref")
                                    .font(.system(size: isCompact ? 11 : 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                            }
                            .padding(.horizontal, isCompact ? 10 : 12)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.22, green: 0.08, blue: 0.08))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(Color.red.opacity(0.4), lineWidth: 1)
                            )
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        
                        // 0.3 Bouton i24NEWS en Direct (Interrogation Directe)
                        Button(action: {
                            HapticService.shared.buttonTap()
                            if let onNews = onI24News {
                                onNews()
                            } else {
                                onSend("Donne-moi les dernières actualités de i24NEWS")
                            }
                        }) {
                            HStack(spacing: 5) {
                                Text("📰")
                                    .font(.system(size: isCompact ? 11 : 12))
                                Text("i24NEWS")
                                    .font(.system(size: isCompact ? 11 : 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                            }
                            .padding(.horizontal, isCompact ? 10 : 12)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.08, green: 0.16, blue: 0.28))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(Color(red: 0.0, green: 0.78, blue: 1.0).opacity(0.4), lineWidth: 1)
                            )
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        
                        // 0.4 Bouton Niveau de Batterie
                        Button(action: {
                            HapticService.shared.buttonTap()
                            onSend("Quel est le niveau de batterie ?")
                        }) {
                            HStack(spacing: 5) {
                                Text("🔋")
                                    .font(.system(size: isCompact ? 11 : 12))
                                Text("Batterie")
                                    .font(.system(size: isCompact ? 11 : 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                            }
                            .padding(.horizontal, isCompact ? 10 : 12)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.12, green: 0.22, blue: 0.15))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(Color.green.opacity(0.4), lineWidth: 1)
                            )
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        
                        // 0.5 Bouton Que sais-tu faire ?
                        Button(action: {
                            HapticService.shared.buttonTap()
                            onSend("Que sais-tu faire ?")
                        }) {
                            HStack(spacing: 5) {
                                Text("✨")
                                    .font(.system(size: isCompact ? 11 : 12))
                                Text("Que sais-tu faire ?")
                                    .font(.system(size: isCompact ? 11 : 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                            }
                            .padding(.horizontal, isCompact ? 10 : 12)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.22, green: 0.14, blue: 0.32))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(Color.purple.opacity(0.4), lineWidth: 1)
                            )
                        }
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.horizontal, isCompact ? 12 : 16)
                }
                .frame(maxWidth: .infinity)
                
                // 1. Barre de saisie principale
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
                    
                    // 1.2 Champ de Saisie Texte
                    TextField("Demander à Sarah...", text: $text, onCommit: {
                        submitMessage()
                    })
                        .font(.system(size: isCompact ? 15 : 16, weight: .regular))
                        .foregroundColor(.white)
                        .accentColor(Color(red: 0.04, green: 0.52, blue: 1.0))
                        .autocapitalization(.sentences)
                        .disableAutocorrection(false)
                        .padding(.horizontal, 4)
                        .lineLimit(1)
                    
                    // 1.3 Bouton Caméra
                    Button(action: {
                        HapticService.shared.buttonTap()
                        onCamera?()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: btnSize, height: btnSize)
                            
                            Image(systemName: "camera.fill")
                                .font(.system(size: isCompact ? 15 : 17, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.85))
                        }
                    }
                    .buttonStyle(ScaleBounceButtonStyle())
                    
                    // 1.4 Bouton Dictée Vocale / Microphone
                    Button(action: {
                        onToggleMic()
                    }) {
                        ZStack {
                            Circle()
                                .fill(isRecording ? Color.red.opacity(0.2) : Color.clear)
                                .frame(width: btnSize, height: btnSize)
                            
                            Image(systemName: isRecording ? "mic.fill" : "mic")
                                .font(.system(size: isCompact ? 16 : 18, weight: isRecording ? .bold : .medium))
                                .foregroundColor(isRecording ? Color.red : Color.white.opacity(0.85))
                                .scaleEffect(isRecording ? 1.15 : 1.0)
                                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isRecording)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // 1.5 Bouton Envoi / Onde Vocale Dynamique
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
                                .frame(width: sendBtnSize, height: sendBtnSize)
                            
                            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Image(systemName: "waveform")
                                    .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.8))
                            } else {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: isCompact ? 15 : 17, weight: .bold))
                                    .foregroundColor(.white)
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
                                colors: [Color(red: 0.0, green: 0.78, blue: 1.0).opacity(0.4), Color.white.opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.0
                        )
                )
                .padding(.horizontal, isCompact ? 10 : 16)
                .shadow(color: Color(red: 0.0, green: 0.78, blue: 1.0).opacity(0.12), radius: 12, x: 0, y: 4)
                .shadow(color: Color.black.opacity(0.45), radius: 15, x: 0, y: 6)
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
