import SwiftUI

/// Écran principal de discussion 100% natif SwiftUI avec synchronisation dynamique du clavier au-dessus de MessageBar.
public struct ChatScreenView: View {
    @ObservedObject var viewModel: ChatViewModel
    @StateObject private var keyboard = KeyboardObserver()
    
    public init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        GeometryReader { geo in
            let bottomInset = geo.safeAreaInsets.bottom
            
            VStack(spacing: 0) {
                // 1. Topbar Native
                topBar
                
                // 2. Fil de discussion (MessageList)
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
                
                // 3. Barre de saisie (MessageBar) synchronisée au-dessus du clavier
                MessageBar(
                    text: $viewModel.inputText,
                    isRecording: viewModel.isMicRunning,
                    onSend: { text in
                        viewModel.sendMessage(text)
                    },
                    onToggleMic: {
                        viewModel.toggleMicrophone()
                    }
                )
                .padding(.bottom, keyboard.keyboardHeight > 0 ? (keyboard.keyboardHeight + 8) : max(16, bottomInset + 8))
            }
            .background(Color.black)
        }
        .ignoresSafeArea(.keyboard)
    }
    
    // MARK: - Topbar
    
    private var topBar: some View {
        HStack(alignment: .center) {
            // Bouton Menu Tiroir (Sidebar)
            Button(action: {
                HapticService.shared.buttonTap()
                keyboard.dismiss()
                viewModel.openDrawer()
            }) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.11, green: 0.11, blue: 0.12))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(ScaleBounceButtonStyle())
            
            Spacer()
            
            // Titre & Indicateur d'état Sarah IA
            VStack(spacing: 2) {
                Text("Sarah IA")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                HStack(spacing: 5) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    
                    Text(statusText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.6))
                }
            }
            
            Spacer()
            
            // Bouton Nouvelle Discussion
            Button(action: {
                HapticService.shared.buttonTap()
                keyboard.dismiss()
                viewModel.startNewChat()
            }) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.11, green: 0.11, blue: 0.12))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(ScaleBounceButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.top, 50)
        .padding(.bottom, 6)
    }
    
    private var statusColor: Color {
        if viewModel.isMicRunning {
            return .red
        } else if viewModel.isSpeaking {
            return .cyan
        } else if viewModel.isTyping {
            return .yellow
        } else {
            return .green
        }
    }
    
    private var statusText: String {
        if viewModel.isMicRunning {
            return "Écoute en direct..."
        } else if viewModel.isSpeaking {
            return "Parle..."
        } else if viewModel.isTyping {
            return "Réflexion..."
        } else {
            return "Prête"
        }
    }
}
