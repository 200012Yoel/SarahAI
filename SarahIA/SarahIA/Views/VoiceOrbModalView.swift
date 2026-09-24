import SwiftUI
import UIKit

/// Interface vocale Sarah.
/// La feuille peut être fermée sans interrompre la session vocale : la mini-barre
/// reste alors visible dans le chat jusqu'à ce que l'utilisateur touche X.
@available(iOS 15.0, *)
public struct VoiceOrbModalView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.presentationMode) private var presentationMode

    private let onOpenMenu: () -> Void
    private let onOpenSettings: () -> Void

    @State private var pulse = false
    @State private var drift = false

    public init(
        viewModel: ChatViewModel,
        onOpenMenu: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.onOpenMenu = onOpenMenu
        self.onOpenSettings = onOpenSettings
    }

    private var accent: Color {
        viewModel.activeAgent.themeColor
    }

    private var normalizedLevel: CGFloat {
        min(max(CGFloat(viewModel.micInputLevel), 0), 1)
    }

    private var statusTitle: String {
        switch viewModel.voiceStatus {
        case .starting:
            return "Activation du micro…"
        case .processing:
            return "Je réfléchis…"
        case .speaking:
            return "\(viewModel.activeAgent.displayName) parle"
        case .error:
            return "Micro indisponible"
        default:
            if !viewModel.liveTranscriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Je t’écoute."
            }
            return viewModel.isMicRunning ? "Je t’écoute." : "Micro coupé"
        }
    }

    private var statusSubtitle: String {
        switch viewModel.voiceStatus {
        case .error(let message):
            return message.isEmpty ? "Touchez le micro pour réessayer" : message
        case .starting:
            return "Autorisez le micro et la reconnaissance vocale si iOS vous le demande"
        case .processing:
            return "Un instant…"
        case .speaking:
            return "Tu peux couper le micro ou interrompre la session avec X"
        default:
            return viewModel.isMicRunning ? "Parle normalement" : "Touchez le micro pour reprendre"
        }
    }

    public var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 430

            ZStack {
                Color.black
                    .ignoresSafeArea()

                RadialGradient(
                    colors: [
                        accent.opacity(compact ? 0.07 : 0.12),
                        accent.opacity(0.018),
                        Color.clear
                    ],
                    center: compact ? .bottom : .center,
                    startRadius: 36,
                    endRadius: compact ? 260 : 430
                )
                .ignoresSafeArea()

                if compact {
                    compactLayout
                } else {
                    expandedLayout
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            pulse = true
            drift = true

            if !viewModel.isContinuousConversationActive {
                viewModel.startVoiceConversation()
            } else if !viewModel.isVoiceMicrophoneMuted,
                      !viewModel.isMicRunning,
                      !viewModel.isSpeaking {
                // Réouvrir la feuille doit aussi réarmer le micro si la session
                // est encore active mais que la reconnaissance s'est arrêtée.
                viewModel.resumeVoiceMicrophone()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            // On coupe uniquement si l'application entière passe en arrière-plan.
            // Fermer la feuille ou revenir au chat ne coupe jamais la session.
            viewModel.stopVoiceConversation()
        }
    }

    // MARK: - Grand mode vocal

    private var expandedLayout: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 12)

            Spacer(minLength: 20)

            orb(size: 292)
                .frame(width: 320, height: 320)

            Spacer(minLength: 22)

            VStack(spacing: 8) {
                Text(statusTitle)
                    .font(.system(size: 25, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                if !viewModel.liveTranscriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(viewModel.liveTranscriptionText)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.70))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 24)
                } else {
                    Text(statusSubtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.48))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 22)
                }
            }
            .frame(minHeight: 76)

            Spacer(minLength: 24)

            composer
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
        }
    }

    // MARK: - Mode réduit

    private var compactLayout: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 8)

            orb(size: 86)
                .frame(width: 112, height: 112)

            Text(statusTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.82))
                .lineLimit(1)

            composer
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
        }
    }

    // MARK: - En-tête

    private var header: some View {
        HStack(spacing: 14) {
            circleButton(systemName: "line.3.horizontal") {
                HapticService.shared.buttonTap()
                presentationMode.wrappedValue.dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    onOpenMenu()
                }
            }

            Spacer()

            VStack(spacing: 2) {
                Text(viewModel.activeAgent.displayName)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Mode vocal")
                    .accessibilityIdentifier("voice.title")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.46))
            }

            Spacer()

            HStack(spacing: 8) {
                circleButton(systemName: "slider.horizontal.3", size: 44) {
                    HapticService.shared.buttonTap()
                    presentationMode.wrappedValue.dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        onOpenSettings()
                    }
                }

                circleButton(systemName: "xmark", size: 44, highlighted: true) {
                    HapticService.shared.buttonTap()
                    viewModel.endVoiceConversation()
                    presentationMode.wrappedValue.dismiss()
                }
                .accessibilityIdentifier("voice.close")
            }
        }
    }

    // MARK: - Orbe Sarah

    private func orb(size: CGFloat) -> some View {
        let core = size * 0.72
        let voiceBoost = 1.0 + normalizedLevel * 0.065

        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accent.opacity(0.28),
                            accent.opacity(0.07),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: core * 0.20,
                        endRadius: size * 0.52
                    )
                )
                .frame(width: size, height: size)
                .blur(radius: size > 150 ? 15 : 8)

            ForEach(0..<2) { index in
                Circle()
                    .stroke(
                        accent.opacity(index == 0 ? 0.38 : 0.16),
                        lineWidth: 1
                    )
                    .frame(
                        width: core + CGFloat(index * 30),
                        height: core + CGFloat(index * 30)
                    )
                    .scaleEffect(
                        (pulse ? 1.025 : 0.985)
                        + normalizedLevel * CGFloat(index + 1) * 0.014
                    )
                    .animation(
                        Animation.easeInOut(duration: 1.7 + Double(index) * 0.25)
                            .repeatForever(autoreverses: true),
                        value: pulse
                    )
            }

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.95),
                                accent.opacity(0.88),
                                accent
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(Color.white.opacity(0.48))
                    .frame(width: core * 0.48, height: core * 0.48)
                    .blur(radius: size > 150 ? 17 : 8)
                    .offset(
                        x: drift ? -core * 0.08 : core * 0.09,
                        y: drift ? core * 0.07 : -core * 0.07
                    )
                    .animation(
                        Animation.easeInOut(duration: 3.0).repeatForever(autoreverses: true),
                        value: drift
                    )

                Image(systemName: viewModel.activeAgent.iconName)
                    .font(.system(size: max(18, core * 0.16), weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.18), radius: 4, x: 0, y: 2)
            }
            .frame(width: core, height: core)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.44), lineWidth: 1.3)
            )
            .shadow(color: accent.opacity(0.50), radius: size > 150 ? 18 : 10)
            .scaleEffect((pulse ? 1.012 : 0.992) * voiceBoost)
            .animation(
                Animation.spring(response: 0.26, dampingFraction: 0.76),
                value: normalizedLevel
            )
        }
        .contentShape(Circle())
        .onTapGesture {
            HapticService.shared.buttonTap()
            if viewModel.isMicRunning {
                viewModel.pauseVoiceMicrophone()
            } else {
                viewModel.resumeVoiceMicrophone()
            }
        }
    }

    // MARK: - Barre inférieure

    private var composer: some View {
        HStack(spacing: 10) {
            circleButton(systemName: "plus", size: 50) {
                HapticService.shared.buttonTap()
            }

            HStack(spacing: 10) {
                TextField(
                    "Demander à \(viewModel.activeAgent.displayName)…",
                    text: $viewModel.inputText,
                    onCommit: {
                        sendTextIfNeeded()
                    }
                )
                    .foregroundColor(.white)
                    .accentColor(accent)
                    .font(.system(size: 16))

                Button(action: {
                    HapticService.shared.buttonTap()
                    if viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        if viewModel.isMicRunning {
                            viewModel.pauseVoiceMicrophone()
                        } else {
                            viewModel.resumeVoiceMicrophone()
                        }
                    } else {
                        sendTextIfNeeded()
                    }
                }) {
                    Image(systemName: viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "waveform" : "arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(accent)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(accent.opacity(0.10)))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.leading, 14)
            .padding(.trailing, 7)
            .frame(height: 52)
            .sarahLiquidGlass(
                cornerRadius: 26,
                tint: accent,
                intensity: 0.08
            )

            circleButton(
                systemName: viewModel.isVoiceMicrophoneMuted ? "mic.slash.fill" : "mic.fill",
                size: 50,
                highlighted: !viewModel.isVoiceMicrophoneMuted
            ) {
                HapticService.shared.buttonTap()
                viewModel.toggleMicrophone()
            }

            circleButton(
                systemName: "xmark",
                size: 50,
                highlighted: true
            ) {
                HapticService.shared.buttonTap()
                viewModel.endVoiceConversation()
                presentationMode.wrappedValue.dismiss()
            }
        }
    }

    private func sendTextIfNeeded() {
        let text = viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        viewModel.sendMessage(text)
    }

    private func circleButton(
        systemName: String,
        size: CGFloat = 48,
        highlighted: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: size, height: size)

                Circle()
                    .fill(highlighted ? accent.opacity(0.12) : Color.white.opacity(0.025))
                    .frame(width: size, height: size)

                Circle()
                    .stroke(
                        highlighted ? accent.opacity(0.34) : Color.white.opacity(0.16),
                        lineWidth: 0.75
                    )
                    .frame(width: size, height: size)

                Image(systemName: systemName)
                    .font(.system(size: size * 0.34, weight: .semibold))
                    .foregroundColor(highlighted ? accent : .white)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
