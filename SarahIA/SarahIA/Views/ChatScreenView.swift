import SwiftUI

/// Écran de discussion (Chat) reproduit fidèlement selon la maquette avec suggestions, fil de discussion et bouton avatar.
public struct ChatScreenView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Namespace private var bottomID
    
    public init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Barre supérieure (Top bar)
            topBar
            
            // Corps de discussion (Messages ou Suggestions)
            if viewModel.messages.isEmpty {
                Spacer()
                suggestionsBlock
                    .padding(.bottom, 20)
            } else {
                messagesThread
            }
            
            // Barre de saisie (Composer)
            MessageInputView(
                text: $viewModel.inputText,
                isTyping: viewModel.isTyping,
                isMicActive: viewModel.isMicRunning,
                onSend: viewModel.sendMessage,
                onMicTap: viewModel.toggleMicrophone,
                onPlusTap: {
                    // Actions d'ajout
                    HapticService.shared.buttonTap()
                },
                onVoiceModeTap: {
                    // Basculer directement vers l'avatar / mode vocal
                    viewModel.switchToAvatar()
                }
            )
        }
        .background(Color.black.ignoresSafeArea())
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            // Bouton Menu latéral (Tiroir)
            Button(action: {
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
            
            Spacer()
            
            // 👩🏻‍💼 Bouton Rond avec l'Avatar de Sarah -> Mène à l'Avatar 3D
            Button(action: {
                viewModel.switchToAvatar()
            }) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.25, green: 0.50, blue: 1.0),
                                    Color(red: 0.65, green: 0.25, blue: 0.90)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                        )
                        .shadow(color: Color.purple.opacity(0.3), radius: 6, x: 0, y: 2)
                    
                    Text("👩🏻‍💼")
                        .font(.system(size: 22))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }
    
    // MARK: - Fil de messages (Thread)
    
    private var messagesThread: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        ChatBubbleView(
                            message: message,
                            isSpeaking: (viewModel.isSpeaking && viewModel.currentSpeakingText == message.content),
                            onSpeak: {
                                viewModel.toggleSpeechForMessage(message.content)
                            }
                        )
                        .id(message.id)
                    }
                    
                    if viewModel.isTyping {
                        TypingIndicatorView()
                            .id("typingIndicator")
                    }
                    
                    Color.clear
                        .frame(height: 1)
                        .id("bottomAnchor")
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 16)
            }
            .onChange(of: viewModel.messages.count) { _ in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    proxy.scrollTo("bottomAnchor", anchor: .bottom)
                }
            }
        }
    }
    
    // MARK: - Bloc de Suggestions initiales
    
    private var suggestionsBlock: some View {
        VStack(spacing: 4) {
            suggestionRow(title: "✨ Présente-toi", icon: "sparkles", prompt: "Présente-toi")
            suggestionRow(title: "Créer une image", icon: "photo", prompt: "Créer une image de ")
            suggestionRow(title: "Écrire ou modifier", icon: "square.and.pencil", prompt: "Écrire un texte sur ")
            suggestionRow(title: "Rechercher sur le Web", icon: "globe", prompt: "Rechercher sur le Web : ")
        }
        .padding(.horizontal, 22)
    }
    
    private func suggestionRow(title: String, icon: String, prompt: String) -> some View {
        Button(action: {
            HapticService.shared.buttonTap()
            viewModel.sendQuickSuggestion(prompt)
        }) {
            HStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 28)
                
                Text(title)
                    .font(.system(size: 19, weight: .regular))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
