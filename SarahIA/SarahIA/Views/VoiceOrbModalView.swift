import SwiftUI

/// Mode vocal plein écran de Sarah.
/// L'interface reprend les grands principes d'un assistant vocal moderne :
/// - une scène immersive plein écran,
/// - un orbe organique réactif au niveau du micro,
/// - des contrôles simples et lisibles,
/// - la transcription en direct sans surcharger l'écran.
@available(iOS 14.0, *)
public struct VoiceOrbModalView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var haloPulse = false
    @State private var drift = false
    @State private var wavePulse = false

    public init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
    }

    private var accent: Color {
        viewModel.activeAgent.themeColor
    }

    private var normalizedLevel: CGFloat {
        min(max(CGFloat(viewModel.micInputLevel), 0), 1)
    }

    private var statusTitle: String {
        if !viewModel.liveTranscriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Je vous écoute"
        }
        return viewModel.isMicRunning ? "Écoute…" : "Micro coupé"
    }

    private var statusSubtitle: String {
        viewModel.isMicRunning ? "Vous pouvez parler maintenant" : "Touchez le micro pour reprendre"
    }

    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            // Léger halo ambiant pour éviter un écran totalement plat.
            RadialGradient(
                gradient: Gradient(colors: [
                    accent.opacity(0.16),
                    accent.opacity(0.04),
                    Color.clear
                ]),
                center: .center,
                startRadius: 70,
                endRadius: 420
            )
            .ignoresSafeArea()
            .scaleEffect(haloPulse ? 1.08 : 0.96)
            .animation(
                Animation.easeInOut(duration: 2.8).repeatForever(autoreverses: true),
                value: haloPulse
            )

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                Spacer(minLength: 18)

                voiceOrb
                    .frame(width: 330, height: 330)
                    .padding(.horizontal, 18)

                Spacer(minLength: 22)

                transcriptionArea
                    .padding(.horizontal, 28)

                Spacer(minLength: 28)

                bottomControls
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)
            }
        }
        .onAppear {
            haloPulse = true
            drift = true
            wavePulse = true

            if !viewModel.isMicRunning {
                viewModel.toggleMicrophone()
            }
        }
        .onDisappear {
            // Un mode vocal fermé ne doit jamais laisser le micro tourner.
            if viewModel.isMicRunning {
                viewModel.toggleMicrophone()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            roundButton(
                systemName: "xmark",
                foreground: .white,
                background: Color.white.opacity(0.10),
                size: 48
            ) {
                HapticService.shared.buttonTap()
                presentationMode.wrappedValue.dismiss()
            }

            Spacer()

            VStack(spacing: 3) {
                Text(viewModel.activeAgent.displayName)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Mode vocal")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.48))
            }

            Spacer()

            // Espace miroir du bouton gauche pour garder le titre parfaitement centré.
            Color.clear
                .frame(width: 48, height: 48)
        }
    }

    // MARK: - Orbe

    private var voiceOrb: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let core = side * 0.70
            let voiceBoost = 1.0 + normalizedLevel * 0.085

            ZStack {
                // Aura externe respirante.
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                accent.opacity(0.34),
                                accent.opacity(0.10),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: side * 0.17,
                            endRadius: side * 0.52
                        )
                    )
                    .frame(width: side, height: side)
                    .blur(radius: 24)
                    .scaleEffect((haloPulse ? 1.06 : 0.95) * voiceBoost)

                // Ondes fines autour de l'orbe.
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(
                            accent.opacity(index == 0 ? 0.45 : 0.20),
                            lineWidth: index == 0 ? 1.4 : 1.0
                        )
                        .frame(
                            width: core + CGFloat(index * 34),
                            height: core + CGFloat(index * 34)
                        )
                        .scaleEffect(
                            (wavePulse ? 1.035 : 0.975)
                            + normalizedLevel * CGFloat(index + 1) * 0.018
                        )
                        .opacity(wavePulse ? 0.95 : 0.55)
                        .animation(
                            Animation.easeInOut(duration: 1.55 + Double(index) * 0.28)
                                .repeatForever(autoreverses: true),
                            value: wavePulse
                        )
                }

                // Sphère centrale "liquide".
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.98),
                                    accent.opacity(0.96),
                                    accent
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Circle()
                        .fill(accent.opacity(0.62))
                        .frame(width: core * 0.72, height: core * 0.72)
                        .blur(radius: 24)
                        .offset(
                            x: drift ? core * 0.14 : -core * 0.12,
                            y: drift ? -core * 0.08 : core * 0.12
                        )
                        .animation(
                            Animation.easeInOut(duration: 2.7).repeatForever(autoreverses: true),
                            value: drift
                        )

                    Circle()
                        .fill(Color.white.opacity(0.72))
                        .frame(width: core * 0.48, height: core * 0.48)
                        .blur(radius: 30)
                        .offset(
                            x: drift ? -core * 0.10 : core * 0.11,
                            y: drift ? core * 0.09 : -core * 0.10
                        )
                        .animation(
                            Animation.easeInOut(duration: 3.1).repeatForever(autoreverses: true),
                            value: drift
                        )

                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.82),
                            Color.white.opacity(0.16),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 4,
                        endRadius: core * 0.34
                    )

                    Image(systemName: viewModel.activeAgent.iconName)
                        .font(.system(size: 35, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.22), radius: 5, x: 0, y: 2)
                        .scaleEffect(1.0 + normalizedLevel * 0.08)
                }
                .frame(width: core, height: core)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.78),
                                    accent.opacity(0.55),
                                    Color.white.opacity(0.12)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: accent.opacity(0.78), radius: 34)
                .scaleEffect((haloPulse ? 1.018 : 0.985) * voiceBoost)
                .animation(
                    Animation.spring(response: 0.24, dampingFraction: 0.72),
                    value: normalizedLevel
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .contentShape(Circle())
        .onTapGesture {
            HapticService.shared.buttonTap()
            viewModel.toggleMicrophone()
        }
    }

    // MARK: - État et transcription

    private var transcriptionArea: some View {
        VStack(spacing: 9) {
            Text(statusTitle)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            if !viewModel.liveTranscriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(viewModel.liveTranscriptionText)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .transition(.opacity)
            } else {
                Text(statusSubtitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.50))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 78)
    }

    // MARK: - Contrôles

    private var bottomControls: some View {
        HStack(spacing: 0) {
            roundButton(
                systemName: viewModel.isMicRunning ? "mic.fill" : "mic.slash.fill",
                foreground: .white,
                background: Color.white.opacity(0.10),
                size: 64
            ) {
                HapticService.shared.buttonTap()
                viewModel.toggleMicrophone()
            }

            Spacer()

            liveWaveform
                .frame(width: 118, height: 46)

            Spacer()

            roundButton(
                systemName: "xmark",
                foreground: .white,
                background: accent,
                size: 64
            ) {
                HapticService.shared.buttonTap()
                if viewModel.isMicRunning {
                    viewModel.toggleMicrophone()
                }
                presentationMode.wrappedValue.dismiss()
            }
            .shadow(color: accent.opacity(0.42), radius: 18)
        }
    }

    private var liveWaveform: some View {
        HStack(alignment: .center, spacing: 5) {
            ForEach(0..<9) { index in
                Capsule()
                    .fill(accent.opacity(viewModel.isMicRunning ? 0.96 : 0.35))
                    .frame(
                        width: 5,
                        height: waveformHeight(for: index)
                    )
            }
        }
        .animation(
            Animation.easeOut(duration: 0.16),
            value: normalizedLevel
        )
    }

    private func waveformHeight(for index: Int) -> CGFloat {
        let profile: [CGFloat] = [0.28, 0.42, 0.62, 0.82, 1.0, 0.82, 0.62, 0.42, 0.28]
        let base = 10 + profile[index] * 12
        let dynamic = normalizedLevel * profile[index] * 24
        return viewModel.isMicRunning ? base + dynamic : 8
    }

    private func roundButton(
        systemName: String,
        foreground: Color,
        background: Color,
        size: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(background)
                    .frame(width: size, height: size)

                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    .frame(width: size, height: size)

                Image(systemName: systemName)
                    .font(.system(size: size * 0.32, weight: .semibold))
                    .foregroundColor(foreground)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
