import SwiftUI

/// Interface vocale Sarah simple et redimensionnable.
///
/// En grand : orbe, état de la conversation et une seule barre de saisie.
/// En glissant vers le bas : petit orbe centré juste au-dessus de la saisie.
/// Il n'y a plus de bouton X, ni de commandes Écrire/Interrompre en double.
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
            return "Activation…"
        case .processing:
            return "Je réfléchis…"
        case .speaking:
            return "Sarah parle"
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
        case .starting:
            return "Activation de la voix"
        case .processing:
            return "Un instant…"
        case .speaking:
            return "Touchez le micro pour interrompre Sarah"
        case .error(let message):
            return message.isEmpty ? "Touchez le micro pour réessayer" : message
        default:
            return viewModel.isMicRunning ? "Parle normalement" : "Touchez le micro pour reprendre"
        }
    }

    public var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 430

            ZStack {
                Color.black.ignoresSafeArea()

                RadialGradient(
                    gradient: Gradient(colors: [
                        accent.opacity(compact ? 0.08 : 0.14),
                        accent.opacity(0.025),
                        Color.clear
                    ]),
                    center: compact ? .bottom : .center,
                    startRadius: 40,
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
            DispatchQueue.main.async {
                viewModel.startVoiceConversation()
            }
        }
        .onDisappear {
            viewModel.stopVoiceConversation()
        }
    }

    // MARK: - Grand mode

    private var expandedLayout: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 12)

            Spacer(minLength: 20)

            orb(size: 292)
                .frame(width: 320, height: 320)

            Spacer(minLength: 22)

            statusBlock
                .frame(minHeight: 78)

            Spacer(minLength: 24)

            composer
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
        }
    }

    // MARK: - Petit mode après glissement

    private var compactLayout: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 6)

            orb(size: 86)
                .frame(width: 108, height: 108)

            Text(statusTitle)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.84))
                .lineLimit(1)

            composer
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
        }
    }

    private var statusBlock: some View {
        VStack(spacing: 8) {
            Text(statusTitle)
                .font(.system(size: 25, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            if !viewModel.liveTranscriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(viewModel.liveTranscriptionText)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.70))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 24)
            } else {
                Text(statusSubtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.46))
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - En-tête minimal

    private var header: some View {
        HStack(spacing: 14) {
            circleButton(systemName: "line.3.horizontal") {
                HapticService.shared.buttonTap()
                closeAndThen(onOpenMenu)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(viewModel.activeAgent.displayName)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Mode vocal")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.46))
            }

            Spacer()

            circleButton(systemName: "slider.horizontal.3") {
                HapticService.shared.buttonTap()
                closeAndThen(onOpenSettings)
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
                        gradient: Gradient(colors: [
                            accent.opacity(0.30),
                            accent.opacity(0.08),
                            Color.clear
                        ]),
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
                        accent.opacity(index == 0 ? 0.40 : 0.18),
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
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.96),
                                accent.opacity(0.94),
                                accent
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(Color.white.opacity(0.54))
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
                    .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)
            }
            .frame(width: core, height: core)
            .clipShape(Circle())
            .overlay(Circle().stroke(.white.opacity(0.46), lineWidth: 1.5))
            .shadow(color: accent.opacity(0.58), radius: size > 150 ? 18 : 10)
            .scaleEffect((pulse ? 1.012 : 0.992) * voiceBoost)
            .animation(.spring(response: 0.26, dampingFraction: 0.76), value: normalizedLevel)
        }
        .contentShape(Circle())
        .onTapGesture {
            HapticService.shared.buttonTap()
            primaryVoiceAction()
        }
    }

    // MARK: - Saisie unique

    private var composer: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                TextField("Demander à Sarah…", text: $viewModel.inputText)
                    .foregroundColor(.white)
                    .accentColor(accent)
                    .font(.system(size: 16))
                    .submitLabel(.send)
                    .onSubmit { sendTextIfNeeded() }

                if !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(action: sendTextIfNeeded) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(accent))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 7)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.white.opacity(0.09))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )

            circleButton(
                systemName: voiceActionIcon,
                size: 50,
                highlighted: viewModel.isMicRunning || viewModel.voiceStatus == .speaking
            ) {
                HapticService.shared.buttonTap()
                primaryVoiceAction()
            }
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

    private func closeAndThen(_ action: @escaping () -> Void) {
        viewModel.stopVoiceConversation()
        viewModel.isShowingVoiceOrbModal = false
        presentationMode.wrappedValue.dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
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
