import SwiftUI

/// Interface vocale moderne de Sarah.
/// Le mode vocal reste séparé du chat : on peut le réduire/fermer par geste,
/// et il réutilise le moteur Apple Speech/TTS déjà présent dans la branche stable.
@available(iOS 16.0, *)
public struct VoiceOrbModalView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var pulse = false
    @State private var draft = ""

    public init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.10, green: 0.02, blue: 0.11),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.28))
                    .frame(width: 44, height: 5)
                    .padding(.top, 10)

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Sarah")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text(statusText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.55))
                    }

                    Spacer()

                    Button {
                        viewModel.stopVoiceMode()
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(Color.white.opacity(0.09)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22)
                .padding(.top, 20)

                Spacer()

                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.pink.opacity(0.95),
                                    Color.purple.opacity(0.72),
                                    Color.blue.opacity(0.32),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 115
                            )
                        )
                        .frame(width: 235, height: 235)
                        .scaleEffect(pulse ? 1.05 : 0.96)
                        .opacity(0.95)

                    Circle()
                        .fill(Color.black.opacity(0.35))
                        .frame(width: 145, height: 145)
                        .overlay(
                            Image(systemName: "crown.fill")
                                .font(.system(size: 48, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.pink, .purple, .cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )

                    ForEach(0..<22, id: \.self) { index in
                        Capsule()
                            .fill(Color.white.opacity(0.85))
                            .frame(
                                width: 3,
                                height: 12 + CGFloat(viewModel.micInputLevel) * CGFloat(42 + (index % 5) * 4)
                            )
                            .offset(y: 122)
                            .rotationEffect(.degrees(Double(index) / 22.0 * 360.0))
                    }
                }
                .animation(
                    .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                    value: pulse
                )

                VStack(spacing: 8) {
                    Text(mainCaption)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    if !viewModel.liveTranscriptionText.isEmpty {
                        Text(viewModel.liveTranscriptionText)
                            .font(.system(size: 15))
                            .foregroundColor(Color.white.opacity(0.72))
                            .multilineTextAlignment(.center)
                            .lineLimit(4)
                            .padding(.horizontal, 28)
                    } else {
                        Text("Parle naturellement à Sarah")
                            .font(.system(size: 14))
                            .foregroundColor(Color.white.opacity(0.42))
                    }
                }
                .padding(.top, 28)

                Spacer()

                HStack(spacing: 10) {
                    TextField("Écrire à Sarah", text: $draft)
                        .textInputAutocapitalization(.sentences)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(0.09))
                        )

                    Button {
                        let clean = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !clean.isEmpty else { return }
                        viewModel.sendMessage(clean)
                        draft = ""
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(
                                Circle().fill(
                                    LinearGradient(
                                        colors: [.pink, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                HStack(spacing: 12) {
                    Button {
                        if viewModel.isMicRunning {
                            viewModel.stopVoiceMode()
                        } else {
                            viewModel.startFullDuplexVoiceMode()
                        }
                    } label: {
                        Label(
                            viewModel.isMicRunning ? "Couper le micro" : "Reprendre",
                            systemImage: viewModel.isMicRunning ? "mic.slash.fill" : "mic.fill"
                        )
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .frame(height: 46)
                        .background(Capsule().fill(Color.white.opacity(0.10)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 22)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            pulse = true
            if !viewModel.isMicRunning {
                viewModel.startFullDuplexVoiceMode()
            }
        }
        .onDisappear {
            viewModel.stopVoiceMode()
        }
    }

    private var statusText: String {
        switch viewModel.voiceStatus {
        case .idle:
            return "Mode vocal"
        case .listening:
            return "Écoute"
        case .processing:
            return "Réflexion"
        case .speaking:
            return "Sarah parle"
        case .error(let message):
            return message
        }
    }

    private var mainCaption: String {
        switch viewModel.voiceStatus {
        case .idle:
            return "Je t'écoute"
        case .listening:
            return "Je t'écoute"
        case .processing:
            return "Je réfléchis…"
        case .speaking:
            return "Je te réponds"
        case .error:
            return "Micro indisponible"
        }
    }
}
