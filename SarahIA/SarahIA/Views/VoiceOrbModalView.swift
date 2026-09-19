import SwiftUI
import UIKit

/// Mode vocal immersif de Sarah.
/// S'ouvre directement en grand, reste entièrement local et libère l'audio à la fermeture.
@available(iOS 14.0, *)
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
        if viewModel.pendingVoiceConfirmation != nil {
            return "Confirmer l’action ?"
        }
        
        switch viewModel.voiceStatus {
        case .processing:
            return "Je réfléchis…"
        case .speaking:
            return "\(viewModel.activeAgent.displayName) parle"
        case .error:
            return "Micro indisponible"
        default:
            if !viewModel.liveTranscriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Je t’écoute"
            }
            return viewModel.isMicRunning ? "Je t’écoute" : "Micro en pause"
        }
    }

    private var statusSubtitle: String {
        if viewModel.pendingVoiceConfirmation != nil {
            return "Dis « confirme » ou « annule »"
        }
        
        switch viewModel.voiceStatus {
        case .error:
            return "Touchez le micro pour réessayer"
        case .processing:
            return "Traitement local en cours"
        case .speaking:
            return "Tu peux reprendre la parole à tout moment"
        default:
            return viewModel.isMicRunning ? "Parle normalement" : "Touchez le micro pour reprendre"
        }
    }

    public var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 520
            let orbSize = compact
                ? min(CGFloat(150), proxy.size.width * 0.38)
                : min(CGFloat(210), proxy.size.width * 0.54, proxy.size.height * 0.29)

            ZStack {
                Color.black
                    .ignoresSafeArea()

                RadialGradient(
                    colors: [
                        accent.opacity(compact ? 0.10 : 0.15),
                        accent.opacity(0.025),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 24,
                    endRadius: max(250, proxy.size.width * 0.82)
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    Spacer(minLength: compact ? 8 : 18)

                    orb(size: orbSize)
                        .frame(width: orbSize + 26, height: orbSize + 26)

                    Spacer(minLength: compact ? 8 : 18)

                    statusBlock(compact: compact)

                    Spacer(minLength: compact ? 10 : 22)

                    composer
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            pulse = true
            drift = true
            viewModel.startVoiceConversation()
        }
        .onDisappear {
            viewModel.stopVoiceConversation()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.willResignActiveNotification
            )
        ) { _ in
            viewModel.stopVoiceConversation()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            circleButton(systemName: "line.3.horizontal", size: 40) {
                HapticService.shared.buttonTap()
                viewModel.stopVoiceConversation()
                presentationMode.wrappedValue.dismiss()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                    onOpenMenu()
                }
            }

            Spacer()

            VStack(spacing: 1) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(accent)
                        .frame(width: 7, height: 7)

                    Text(viewModel.activeAgent.displayName)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                Text("Mode vocal")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.40))
            }

            Spacer()

            circleButton(systemName: "gearshape", size: 40) {
                HapticService.shared.buttonTap()
                viewModel.stopVoiceConversation()
                presentationMode.wrappedValue.dismiss()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                    onOpenSettings()
                }
            }
        }
    }

    private func statusBlock(compact: Bool) -> some View {
        VStack(spacing: 6) {
            Text(statusTitle)
                .font(.system(size: compact ? 19 : 23, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            if let confirmation = viewModel.pendingVoiceConfirmation {
                VStack(spacing: 7) {
                    Text("« \(confirmation) »")
                        .font(.system(size: compact ? 14 : 15, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.84))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                    
                    Text(statusSubtitle)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(accent.opacity(0.90))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.065))
                )
                .padding(.horizontal, 18)
            } else if !viewModel.liveTranscriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(viewModel.liveTranscriptionText)
                    .font(.system(size: compact ? 14 : 15.5))
                    .foregroundColor(Color.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .lineLimit(compact ? 2 : 3)
                    .padding(.horizontal, 22)
            } else {
                Text(statusSubtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.42))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(minHeight: compact ? 48 : 64)
    }

    private func orb(size: CGFloat) -> some View {
        let core = size * 0.70
        let voiceBoost = 1.0 + normalizedLevel * 0.07

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
                        startRadius: core * 0.18,
                        endRadius: size * 0.54
                    )
                )
                .frame(width: size, height: size)
                .blur(radius: size > 180 ? 14 : 8)

            ForEach(0..<2) { index in
                Circle()
                    .stroke(
                        accent.opacity(index == 0 ? 0.38 : 0.16),
                        lineWidth: 1
                    )
                    .frame(
                        width: core + CGFloat(index * 27),
                        height: core + CGFloat(index * 27)
                    )
                    .scaleEffect(
                        (pulse ? 1.025 : 0.985)
                        + normalizedLevel * CGFloat(index + 1) * 0.016
                    )
                    .animation(
                        .easeInOut(duration: 1.65 + Double(index) * 0.24)
                            .repeatForever(autoreverses: true),
                        value: pulse
                    )
            }

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.94),
                                accent.opacity(0.94),
                                accent
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(Color.white.opacity(0.50))
                    .frame(width: core * 0.46, height: core * 0.46)
                    .blur(radius: size > 180 ? 16 : 8)
                    .offset(
                        x: drift ? -core * 0.08 : core * 0.08,
                        y: drift ? core * 0.07 : -core * 0.07
                    )
                    .animation(
                        .easeInOut(duration: 3.0)
                            .repeatForever(autoreverses: true),
                        value: drift
                    )

                Image(systemName: viewModel.activeAgent.iconName)
                    .font(.system(size: max(18, core * 0.15), weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.16), radius: 4, y: 2)
            }
            .frame(width: core, height: core)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.42), lineWidth: 1)
            )
            .shadow(color: accent.opacity(0.48), radius: size > 180 ? 18 : 10)
            .scaleEffect((pulse ? 1.012 : 0.992) * voiceBoost)
            .animation(
                .spring(response: 0.25, dampingFraction: 0.78),
                value: normalizedLevel
            )
        }
        .contentShape(Circle())
        .onTapGesture {
            HapticService.shared.buttonTap()

            if viewModel.isMicRunning {
                viewModel.toggleMicrophone()
            } else {
                viewModel.startVoiceConversation()
            }
        }
    }

    private var composer: some View {
        HStack(spacing: 8) {
            HStack(spacing: 7) {
                TextField(
                    "Demander à Sarah…",
                    text: $viewModel.inputText,
                    onCommit: sendTextIfNeeded
                )
                .foregroundColor(.white)
                .accentColor(accent)
                .font(.system(size: 15))

                Button {
                    HapticService.shared.buttonTap()

                    if viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        viewModel.toggleMicrophone()
                    } else {
                        sendTextIfNeeded()
                    }
                } label: {
                    Image(
                        systemName: viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? (viewModel.isMicRunning ? "mic.fill" : "mic")
                            : "arrow.up"
                    )
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(
                        viewModel.isMicRunning
                            ? accent
                            : Color.white.opacity(0.75)
                    )
                    .frame(width: 32, height: 32)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.leading, 13)
            .padding(.trailing, 5)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.09))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.7)
            )

            circleButton(
                systemName: viewModel.isMicRunning ? "waveform.circle.fill" : "mic.slash",
                size: 42,
                highlighted: viewModel.isMicRunning
            ) {
                HapticService.shared.buttonTap()
                viewModel.toggleMicrophone()
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
        size: CGFloat,
        highlighted: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundColor(highlighted ? accent : .white)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(
                            highlighted
                                ? accent.opacity(0.20)
                                : Color.white.opacity(0.09)
                        )
                )
                .overlay(
                    Circle()
                        .stroke(
                            highlighted
                                ? accent.opacity(0.34)
                                : Color.white.opacity(0.055),
                            lineWidth: 0.7
                        )
                )
        }
        .buttonStyle(ScaleBounceButtonStyle())
    }
}
