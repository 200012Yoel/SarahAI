import SwiftUI
import UIKit

/// Mode vocal plein écran de Sarah.
/// Cette vue reprend l'interface complète : grand orbe, menu, réglages,
/// fermeture explicite, saisie texte, contrôle micro et interruption de Sarah.
@available(iOS 15.0, *)
public struct VoiceOrbModalView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.presentationMode) private var presentationMode

    private let onOpenMenu: () -> Void
    private let onOpenSettings: () -> Void

    @State private var pulse = false
    @State private var drift = false
    @State private var showTextComposer = false
    @FocusState private var textComposerFocused: Bool

    public init(
        viewModel: ChatViewModel,
        onOpenMenu: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.onOpenMenu = onOpenMenu
        self.onOpenSettings = onOpenSettings
    }

    private var accent: Color { viewModel.activeAgent.themeColor }
    private var normalizedLevel: CGFloat { min(max(CGFloat(viewModel.micInputLevel), 0), 1) }

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
        case .starting:
            return "Activation de la reconnaissance vocale"
        case .processing:
            return "Un instant…"
        case .speaking:
            return "Tu peux couper le micro ou interrompre la session avec X"
        case .error(let message):
            return message.isEmpty ? "Touchez le micro pour réessayer" : message
        default:
            return viewModel.isMicRunning ? "Parle normalement" : "Touchez le micro pour reprendre"
        }
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                RadialGradient(
                    gradient: Gradient(colors: [
                        accent.opacity(0.12),
                        accent.opacity(0.025),
                        Color.clear
                    ]),
                    center: .center,
                    startRadius: 60,
                    endRadius: 460
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 18)
                        .padding(.top, max(10, proxy.safeAreaInsets.top > 0 ? 4 : 14))

                    Spacer(minLength: 26)

                    orb(size: min(proxy.size.width * 0.72, 322))

                    Spacer(minLength: 34)

                    VStack(spacing: 10) {
                        Text(statusTitle)
                            .font(.system(size: 27, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        if !viewModel.liveTranscriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(viewModel.liveTranscriptionText)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.white.opacity(0.72))
                                .multilineTextAlignment(.center)
                                .lineLimit(4)
                                .padding(.horizontal, 28)
                        } else {
                            Text(statusSubtitle)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.47))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                    }
                    .frame(minHeight: 92)

                    Spacer(minLength: 28)

                    if showTextComposer {
                        textComposer
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    bottomControls
                        .padding(.horizontal, 28)
                        .padding(.bottom, max(18, proxy.safeAreaInsets.bottom + 8))
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
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            viewModel.stopVoiceConversation()
        }
    }

    // MARK: - En-tête

    private var header: some View {
        HStack(spacing: 12) {
            circleButton(systemName: "line.3.horizontal", size: 50) {
                HapticService.shared.buttonTap()
                closeVoiceMode()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                    onOpenMenu()
                }
            }

            Spacer()

            VStack(spacing: 3) {
                Text(viewModel.activeAgent.displayName)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Mode vocal")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.43))
            }

            Spacer()

            HStack(spacing: 8) {
                circleButton(systemName: "slider.horizontal.3", size: 48) {
                    HapticService.shared.buttonTap()
                    closeVoiceMode()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                        onOpenSettings()
                    }
                }

                circleButton(systemName: "xmark", size: 48, highlighted: true) {
                    HapticService.shared.buttonTap()
                    closeVoiceMode()
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
                            accent.opacity(0.30),
                            accent.opacity(0.08),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: core * 0.18,
                        endRadius: size * 0.52
                    )
                )
                .frame(width: size, height: size)
                .blur(radius: 16)

            ForEach(0..<2) { index in
                Circle()
                    .stroke(accent.opacity(index == 0 ? 0.42 : 0.18), lineWidth: 1.2)
                    .frame(width: core + CGFloat(index * 34), height: core + CGFloat(index * 34))
                    .scaleEffect((pulse ? 1.026 : 0.986) + normalizedLevel * CGFloat(index + 1) * 0.014)
                    .animation(
                        Animation.easeInOut(duration: 1.65 + Double(index) * 0.28)
                            .repeatForever(autoreverses: true),
                        value: pulse
                    )
            }

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.82),
                                accent.opacity(0.82),
                                accent
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(Color.white.opacity(0.42))
                    .frame(width: core * 0.50, height: core * 0.50)
                    .blur(radius: 18)
                    .offset(
                        x: drift ? -core * 0.09 : core * 0.10,
                        y: drift ? core * 0.08 : -core * 0.08
                    )
                    .animation(
                        Animation.easeInOut(duration: 3.0).repeatForever(autoreverses: true),
                        value: drift
                    )

                Image(systemName: viewModel.activeAgent.iconName)
                    .font(.system(size: max(28, core * 0.16), weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            }
            .frame(width: core, height: core)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.50), lineWidth: 1.5))
            .shadow(color: accent.opacity(0.58), radius: 22)
            .scaleEffect((pulse ? 1.012 : 0.992) * voiceBoost)
            .animation(.spring(response: 0.25, dampingFraction: 0.74), value: normalizedLevel)
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .onTapGesture {
            HapticService.shared.buttonTap()
            toggleVoiceMicrophone()
        }
    }

    // MARK: - Saisie écrite

    private var textComposer: some View {
        HStack(spacing: 10) {
            TextField("Écrire à \(viewModel.activeAgent.displayName)…", text: $viewModel.inputText)
                .focused($textComposerFocused)
                .foregroundColor(.white)
                .accentColor(accent)
                .font(.system(size: 16))
                .submitLabel(.send)
                .onSubmit { sendWrittenMessage() }

            Button(action: sendWrittenMessage) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(accent))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.leading, 16)
        .padding(.trailing, 7)
        .frame(height: 54)
        .background(
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    // MARK: - Contrôles inférieurs

    private var bottomControls: some View {
        HStack(spacing: 0) {
            Button {
                HapticService.shared.buttonTap()
                if !showTextComposer {
                    viewModel.pauseVoiceMicrophone()
                }
                withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                    showTextComposer.toggle()
                }
                if showTextComposer {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        textComposerFocused = true
                    }
                } else {
                    textComposerFocused = false
                    viewModel.resumeVoiceMicrophone()
                }
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 20, weight: .medium))
                    Text("Écrire")
                        .font(.system(size: 18, weight: .medium))
                }
                .foregroundColor(.white)
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            Button {
                HapticService.shared.buttonTap()
                toggleVoiceMicrophone()
            } label: {
                ZStack {
                    Circle()
                        .fill(viewModel.isMicRunning ? accent.opacity(0.23) : Color.white.opacity(0.10))
                        .frame(width: 64, height: 64)
                    Circle()
                        .stroke(viewModel.isMicRunning ? accent.opacity(0.52) : Color.white.opacity(0.12), lineWidth: 1)
                        .frame(width: 64, height: 64)
                    Image(systemName: viewModel.isMicRunning ? "mic.fill" : "mic.slash.fill")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundColor(viewModel.isMicRunning ? accent : .white)
                }
            }
            .buttonStyle(ScaleBounceButtonStyle())

            Spacer()

            Button {
                HapticService.shared.buttonTap()
                viewModel.interruptVoiceResponse()
            } label: {
                Text("Interrompre")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func toggleVoiceMicrophone() {
        if viewModel.isMicRunning {
            viewModel.pauseVoiceMicrophone()
        } else {
            viewModel.resumeVoiceMicrophone()
        }
    }

    private func sendWrittenMessage() {
        let text = viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        textComposerFocused = false
        withAnimation(.easeOut(duration: 0.18)) {
            showTextComposer = false
        }
        viewModel.sendMessage(text)
    }

    private func closeVoiceMode() {
        textComposerFocused = false
        viewModel.stopVoiceConversation()
        viewModel.isShowingVoiceOrbModal = false
        presentationMode.wrappedValue.dismiss()
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
                    .fill(Color.white.opacity(highlighted ? 0.13 : 0.10))
                    .frame(width: size, height: size)
                Circle()
                    .stroke(highlighted ? accent.opacity(0.42) : Color.white.opacity(0.10), lineWidth: 1)
                    .frame(width: size, height: size)
                Image(systemName: systemName)
                    .font(.system(size: size * 0.34, weight: .semibold))
                    .foregroundColor(highlighted ? accent : .white)
            }
        }
        .buttonStyle(ScaleBounceButtonStyle())
    }
}