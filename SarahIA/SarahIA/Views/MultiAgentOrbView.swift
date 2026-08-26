import SwiftUI

/// Vue Immersive de l'Orbe Multi-Agents (Metal Shader / CoreAnimation style)
/// Réagit de manière organique aux décibels du micro et effectue un morphing dynamique de couleurs selon l'agent actif :
/// - Sarah : Rose néon / Magenta
/// - Tom : Vert émeraude
/// - Raphaël : Bleu ciel / Azur
/// - Yohan : Bicolore Bleu Mer & Blanc pur
@available(iOS 14.0, *)
public struct MultiAgentOrbView: View {
    @Binding var currentAgent: AgentType
    var audioLevel: CGFloat // 0.0 à 1.0 (réactivité en décibels)
    
    @State private var pulse: Bool = false
    @State private var rotationAngle: Double = 0.0
    @State private var innerMorph: CGFloat = 1.0
    
    public init(currentAgent: Binding<AgentType>, audioLevel: CGFloat = 0.5) {
        self._currentAgent = currentAgent
        self.audioLevel = audioLevel
    }
    
    public var body: some View {
        ZStack {
            // 1. Halo Externe de Diffusion Organique (Atmospheric Glow)
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            currentAgent.themeColor.opacity(0.45),
                            currentAgent.themeColor.opacity(0.12),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 40,
                        endRadius: 170
                    )
                )
                .frame(
                    width: 320 * (1.0 + audioLevel * 0.35),
                    height: 320 * (1.0 + audioLevel * 0.35)
                )
                .blur(radius: 45)
                .animation(.spring(response: 0.25, dampingFraction: 0.65), value: audioLevel)
            
            // 2. Anneaux d'ondes concentriques réactives
            ForEach(0..<2) { i in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                currentAgent.themeColor.opacity(0.6 / Double(i + 1)),
                                Color.white.opacity(0.2 / Double(i + 1))
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .frame(
                        width: CGFloat(230 + (i * 35)) * (1.0 + audioLevel * 0.2),
                        height: CGFloat(230 + (i * 35)) * (1.0 + audioLevel * 0.2)
                    )
                    .scaleEffect(pulse ? 1.05 : 0.95)
                    .animation(
                        .easeInOut(duration: 1.8 + Double(i) * 0.4)
                        .repeatForever(autoreverses: true),
                        value: pulse
                    )
            }
            
            // 3. Cœur de l'Orbe avec Rendu Spécial Yohan (Bicolore Bleu Mer & Blanc pur) et Dégradé fluide
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: currentAgent.gradientColors),
                        center: .center,
                        startRadius: currentAgent == .yohan ? 8 : 22,
                        endRadius: 115
                    )
                )
                .frame(width: 215, height: 215)
                .shadow(
                    color: currentAgent.themeColor.opacity(0.85),
                    radius: 28,
                    x: 0,
                    y: 0
                )
                .scaleEffect(pulse ? 1.04 : 0.96)
                .animation(
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                    value: pulse
                )
                .overlay(
                    // Reflet cristallin Apple Intelligence
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.85), Color.clear, currentAgent.themeColor.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2.0
                        )
                )
            
            // 4. Noyau Lumineux Central & Icône d'Agent
            ZStack {
                Circle()
                    .fill(Color.white.opacity(currentAgent == .yohan ? 0.95 : 0.25))
                    .frame(width: 58, height: 58)
                    .blur(radius: 8)
                
                Image(systemName: currentAgent.iconName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(currentAgent == .yohan ? Color(red: 0.0, green: 0.4, blue: 0.8) : Color.white)
                    .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 2)
            }
            .scaleEffect(1.0 + (audioLevel * 0.2))
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: audioLevel)
        }
        .onAppear {
            pulse = true
        }
    }
}
