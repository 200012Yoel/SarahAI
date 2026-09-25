import SwiftUI

/// Mode vocal Sarah inspiré du comportement ChatGPT :
/// - ouverture plein écran ;
/// - glissement vers le bas = retour au chat avec un petit orbe centré ;
/// - la conversation vocale continue reste active pendant la réduction.
@available(iOS 15.0, *)
public struct VoiceOrbModalView: View {
    @ObservedObject var viewModel: ChatViewModel

    private let onOpenMenu: () -> Void
    private let onOpenSettings: () -> Void

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
        self.onOpenMenu = onOpenMenu
        self.onOpenSettings = onOpenSettings
    }

    private var accent: Color {
        viewModel.activeAgent.themeColor
    }

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
            Color.black
                .ignoresSafeArea()

            RadialGradient(
                gradient: Gradient(colors: [
                    accent.opacity(0.12),
                    accent.opacity(0.025),
                    Color.clear
                ]),
                center: .center,
                startRadius: 55,
                endRadius: 460
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 18)
                    .padding(.top, max(10, proxy.safeAreaInsets.top > 0 ? 4 : 14))

                Spacer(minLength: 20)

                orb(size: min(proxy.size.width * 0.50, 210))

                Spacer(minLength: 18)

                statusBlock
                    .frame(minHeight: 82)

                Spacer(minLength: 26)

                bottomComposer
                    .padding(.horizontal, 18)
                    .padding(.bottom, max(16, proxy.safeAreaInsets.bottom + 8))
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            circleButton(systemName: "line.3.horizontal", size: 50) {
                HapticService.shared.buttonTap()
                collapseThen(onOpenMenu)
            }

            Spacer()

            circleButton(systemName: "slider.horizontal.3", size: 50) {
                HapticService.shared.buttonTap()
                collapseThen(onOpenSettings)
            }
        }
    }

    private var statusBlock: some View {
        VStack(spacing: 8) {
            Text(statusTitle)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            if !viewModel.liveTranscriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(viewModel.liveTranscriptionText)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 26)
            } else {
                Text(statusSubtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.46))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var bottomComposer: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 23, weight: .medium))
                    .foregroundColor(.white)

                TextField("Demander…", text: $viewModel.inputText)
                    .foregroundColor(.white)
                    .accentColor(accent)
                    .font(.system(size: 16))
                    .submitLabel(.send)
                    .onSubmit { sendTextIfNeeded() }

                if !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(action: sendTextIfNeeded) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(accent))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 7)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .fill(.white.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .stroke(.white.opacity(0.09), lineWidth: 1)
            )

            circleButton(
                systemName: voiceActionIcon,
                size: 54,
                highlighted: viewModel.isMicRunning || viewModel.voiceStatus == .speaking
            ) {
                HapticService.shared.buttonTap()
                primaryVoiceAction()
            }

            Button {
                HapticService.shared.buttonTap()
                viewModel.stopVoiceConversation()
                viewModel.isShowingVoiceOrbModal = false
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 54, height: 54)
                    Image(systemName: "xmark")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.black)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
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
        let voiceBoost = 1.0 + normalizedLevel * 0.075

        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            accent.opacity(0.34),
                            accent.opacity(0.09),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: core * 0.18,
                        endRadius: size * 0.52
                    )
                )
                .frame(width: size, height: size)
                .blur(radius: size > 120 ? 15 : 7)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.92),
                                accent.opacity(0.72),
                                accent
                            ]),
                            startPoint: .bottomLeading,
                            endPoint: .topTrailing
                        )
                    )

                Circle()
                    .fill(Color.white.opacity(0.50))
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
            .overlay(Circle().stroke(.white.opacity(0.42), lineWidth: 1))
            .shadow(color: accent.opacity(0.45), radius: size > 120 ? 18 : 9)
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

    private var voiceActionIcon: String {
        switch viewModel.voiceStatus {
        case .speaking:
            return "stop.fill"
        default:
            return viewModel.isMicRunning ? "mic.fill" : "mic.slash.fill"
        }
    }

    private func primaryVoiceAction() {
        switch viewModel.voiceStatus {
        case .speaking:
            viewModel.interruptVoiceResponse()
        default:
            if viewModel.isMicRunning {
                viewModel.pauseVoiceMicrophone()
            } else {
                viewModel.resumeVoiceMicrophone()
            }
        }
    }

    private func sendTextIfNeeded() {
        let text = viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        viewModel.sendMessage(text)
    }

    private func collapseThen(_ action: @escaping () -> Void) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            isExpanded = false
            dragOffset = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            action()
        }
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
                    .fill(highlighted ? accent.opacity(0.24) : .white.opacity(0.10))
                    .frame(width: size, height: size)

                Circle()
                    .stroke(
                        highlighted ? accent.opacity(0.44) : .white.opacity(0.08),
                        lineWidth: 1
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
