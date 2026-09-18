import SwiftUI
import UIKit

/// Écran principal stable de Sarah avec chat, tiroir et interface vocale dédiée.
@available(iOS 16.0, *)
public struct ChatScreenView: View {
    @ObservedObject var viewModel: ChatViewModel
    @StateObject private var keyboard = KeyboardObserver()
    @State private var isShowingVoice = false

    public init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        GeometryReader { geo in
            let bottomInset = geo.safeAreaInsets.bottom

            VStack(spacing: 0) {
                topBar

                MessageList(
                    messages: viewModel.messages,
                    isTyping: viewModel.isTyping,
                    isKeyboardVisible: keyboard.isVisible,
                    onToggleSpeech: { message in
                        viewModel.toggleSpeechForMessage(message.content)
                    },
                    onSelectSuggestion: { suggestionText in
                        viewModel.inputText = suggestionText
                    },
                    onIntroduceSarah: {
                        viewModel.introduceSarah()
                    },
                    onDismissKeyboard: {
                        keyboard.dismiss()
                    }
                )

                MessageBar(
                    text: $viewModel.inputText,
                    isRecording: viewModel.isMicRunning,
                    onSend: { text in
                        viewModel.sendMessage(text)
                    },
                    onToggleMic: {
                        keyboard.dismiss()
                        HapticService.shared.buttonTap()
                        isShowingVoice = true
                    }
                )
                .padding(.bottom, keyboard.keyboardHeight > 0
                         ? keyboard.keyboardHeight + 8
                         : max(14, bottomInset + 8))
            }
            .background(Color.black)
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $isShowingVoice) {
            VoiceOrbModalView(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                HapticService.shared.buttonTap()
                keyboard.dismiss()
                viewModel.openDrawer()
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(ScaleBounceButtonStyle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Sarah")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                HStack(spacing: 5) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)

                    Text(statusText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.52))
                }
            }

            Spacer()

            Button {
                keyboard.dismiss()
                HapticService.shared.buttonTap()
                isShowingVoice = true
            } label: {
                Image(systemName: "waveform")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle().fill(
                            LinearGradient(
                                colors: [Color.pink.opacity(0.78), Color.purple.opacity(0.76)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    )
            }
            .buttonStyle(ScaleBounceButtonStyle())

            Button {
                HapticService.shared.buttonTap()
                keyboard.dismiss()
                viewModel.startNewChat()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(ScaleBounceButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.top, max(10, topSafeArea + 4))
        .padding(.bottom, 8)
        .background(Color.black.opacity(0.96))
    }

    private var topSafeArea: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .safeAreaInsets.top ?? 20
    }

    private var statusColor: Color {
        if viewModel.isMicRunning {
            return .pink
        } else if viewModel.isSpeaking {
            return .cyan
        } else if viewModel.isTyping {
            return .yellow
        }
        return .green
    }

    private var statusText: String {
        if viewModel.isMicRunning {
            return "Écoute"
        } else if viewModel.isSpeaking {
            return "Sarah parle"
        } else if viewModel.isTyping {
            return "Réflexion"
        }
        return "Prête"
    }
}
