import SwiftUI

/// Mode vocal Sarah inspiré du comportement ChatGPT :
/// - ouverture plein écran ;
/// - trois commandes seulement : chat, micro, fermer ;
/// - glissement vers le bas = retour au chat avec un petit orbe centré ;
/// - la conversation vocale continue reste active pendant la réduction.
@available(iOS 15.0, *)
public struct VoiceOrbModalView: View {
    @ObservedObject var viewModel: ChatViewModel

    @State private var isExpanded = true
    @State private var dragOffset: CGFloat = 0
    @State private var pulse = false
    @State private var drift = false

    public init(
        viewModel: ChatViewModel,
        onOpenMenu: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        _ = onOpenMenu
        _ = onOpenSettings
    }

    private let orbTint = Color(red: 0.60, green: 0.72, blue: 0.86)

    private var normalizedLevel: CGFloat {
        min(max(CGFloat(viewModel.micInputLevel), 0), 1)
    }

    public var body: some View {
        GeometryReader { proxy in
            Group {
                if isExpanded {
                    expandedScreen(proxy: proxy)
                        .offset(y: max(0, dragOffset))
                        .gesture(expandedDragGesture)
                        .transition(.opacity)
                } else {
                    compactOverlay
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            pulse = true
            drift = true
            if !viewModel.isContinuousConversationActive {
                DispatchQueue.main.async {
                    viewModel.startVoiceConversation()
                }
            }
        }
    }

    // MARK: - Plein écran

    private func expandedScreen(proxy: GeometryProxy) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()

            RadialGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.055),
                    orbTint.opacity(0.035),
                    Color.clear
                ]),
                center: .center,
                startRadius: 45,
                endRadius: 470
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: max(32, proxy.safeAreaInsets.top + 20))

                orb(size: min(proxy.size.width * 0.50, 208))

                Spacer(minLength: 24)

                statusBlock
                    .frame(minHeight: 88)

                Spacer()

                voiceControls
                    .padding(.horizontal, 32)
                    .padding(.bottom, max(22, proxy.safeAreaInsets.bottom + 14))
            }
        }
    }

    private var statusBlock: some View {
        VStack(spacing: 8) {
            Text(statusTitle)
                .font(.system(size: 23, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            if !viewModel.liveTranscriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(viewModel.liveTranscriptionText)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.70))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 30)
            } else {
                Text(statusSubtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.46))
                    .multilineTextAlignment(.center)
            }
        }
    }

    /// Trois boutons, rien d'autre : chat, micro, fermer.
    private var voiceControls: some View {
        HStack(spacing: 28) {
            controlButton(systemName: "text.bubble.fill") {
                HapticService.shared.buttonTap()
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    isExpanded = false
                    dragOffset = 0
                }
            }
            .accessibilityLabel("Revenir au chat")

            controlButton(
                systemName: viewModel.isMicRunning ? "mic.fill" : "mic.slash.fill",
                emphasized: viewModel.isMicRunning
            ) {
                HapticService.shared.buttonTap()
                if viewModel.isMicRunning {
                    viewModel.pauseVoiceMicrophone()
                } else {
                    viewModel.resumeVoiceMicrophone()
                }
            }
            .accessibilityLabel(viewModel.isMicRunning ? "Couper le micro" : "Réactiver le micro")

            Button {
                HapticService.shared.buttonTap()
                viewModel.stopVoiceConversation()
                viewModel.isShowingVoiceOrbModal = false
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 58, height: 58)
                    Image(systemName: "xmark")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundColor(.black)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Fermer le mode vocal")
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Petit orbe au-dessus de la vraie barre du chat

    private var compactOverlay: some View {
        VStack(spacing: 0) {
            Spacer()

            Button {
                HapticService.shared.buttonTap()
                withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                    isExpanded = true
                    dragOffset = 0
                }
            } label: {
                orb(size: 82)
                    .frame(width: 96, height: 96)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Rouvrir le mode vocal Sarah")
            .padding(.bottom, 88)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var expandedDragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                if value.translation.height > 0 {
                    dragOffset = value.translation.height
                }
            }
            .onEnded { value in
                if value.translation.height > 90 || value.predictedEndTranslation.height > 150 {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        isExpanded = false
                        dragOffset = 0
                    }
                } else {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                        dragOffset = 0
                    }
                }
            }
    }

    // MARK: - Orbe

    private func orb(size: CGFloat) -> some View {
        let core = size * 0.78
        let voiceBoost = 1.0 + normalizedLevel * 0.07

        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            orbTint.opacity(0.30),
                            orbTint.opacity(0.07),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: core * 0.16,
                        endRadius: size * 0.54
                    )
                )
                .frame(width: size, height: size)
                .blur(radius: size > 120 ? 15 : 7)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.95),
                                Color(red: 0.74, green: 0.80, blue: 0.87),
                                Color(red: 0.42, green: 0.52, blue: 0.64)
                            ]),
                            startPoint: .bottomLeading,
                            endPoint: .topTrailing
                        )
                    )

                Circle()
                    .fill(Color.white.opacity(0.46))
                    .frame(width: core * 0.58, height: core * 0.30)
                    .blur(radius: size > 120 ? 18 : 8)
                    .offset(
                        x: drift ? -core * 0.05 : core * 0.07,
                        y: drift ? core * 0.13 : -core * 0.10
                    )
                    .animation(
                        Animation.easeInOut(duration: 3.0).repeatForever(autoreverses: true),
                        value: drift
                    )
            }
            .frame(width: core, height: core)
            .clipShape(Circle())
            .overlay(Circle().stroke(.white.opacity(0.38), lineWidth: 1))
            .shadow(color: orbTint.opacity(0.22), radius: size > 120 ? 18 : 9)
            .scaleEffect((pulse ? 1.012 : 0.992) * voiceBoost)
            .animation(
                Animation.easeInOut(duration: 1.55).repeatForever(autoreverses: true),
                value: pulse
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.74), value: normalizedLevel)
        }
        .frame(width: size, height: size)
    }

    private var statusTitle: String {
        switch viewModel.voiceStatus {
        case .starting:
            return "Activation…"
        case .processing:
            return "Je réfléchis…"
        case .speaking:
            return "Sarah parle"
        case .error:
            return "Micro indisponible"
        default:
            return viewModel.isMicRunning ? "Je t’écoute." : "Micro coupé"
        }
    }

    private var statusSubtitle: String {
        switch viewModel.voiceStatus {
        case .starting:
            return "Activation de la voix"
        case .processing:
            return "Un instant…"
        case .speaking:
            return "Sarah te répond"
        case .error(let message):
            return message.isEmpty ? "Touchez le micro pour réessayer" : message
        default:
            return viewModel.isMicRunning ? "Parle normalement" : "Touchez le micro pour reprendre"
        }
    }

    private func controlButton(
        systemName: String,
        emphasized: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(emphasized ? Color.white.opacity(0.18) : Color.white.opacity(0.10))
                    .frame(width: 58, height: 58)

                Circle()
                    .stroke(Color.white.opacity(emphasized ? 0.22 : 0.08), lineWidth: 1)
                    .frame(width: 58, height: 58)

                Image(systemName: systemName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
