import SwiftUI

/// Écran de Discussion (Chat Screen) Pixel-Perfect 100% Natif SwiftUI reproduisant la section #chat de la maquette.
public struct ChatScreenView: View {
    @ObservedObject var viewModel: ChatViewModel
    
    public init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Topbar (#topbar)
            HStack {
                // Bouton Menu Tiroir (#btnMenu)
                Button(action: {
                    HapticService.shared.buttonTap()
                    viewModel.openDrawer()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.11, green: 0.11, blue: 0.12)) // #1c1c1e
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(ScaleBounceButtonStyle())
                
                Spacer()
                
                // Bouton Rond Avatar 3D (#btnAvatar)
                Button(action: {
                    HapticService.shared.buttonTap()
                    viewModel.switchToAvatar()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.11, green: 0.11, blue: 0.12)) // #1c1c1e
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 19, weight: .regular))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(ScaleBounceButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)
            
            // Fil de Discussion (.thread)
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            ChatBubbleView(
                                message: message,
                                isPlayingAudio: SpeechManager.shared.isSpeaking && SpeechManager.shared.currentSpokenText == message.content,
                                onPlayTapped: {
                                    viewModel.toggleSpeechForMessage(message.content)
                                }
                            )
                            .id(message.id)
                        }
                        
                        if viewModel.isTyping {
                            HStack {
                                TypingIndicatorView()
                                    .padding(.leading, 8)
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let last = viewModel.messages.last {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Suggestions d'Actions (.suggests) affichées quand le fil est vierge
            if viewModel.messages.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    suggestionRow(
                        title: "Créer une image",
                        icon: "photo",
                        prefill: "Créer une image de "
                    )
                    suggestionRow(
                        title: "Écrire ou modifier",
                        icon: "square.and.pencil",
                        prefill: "Écrire un texte sur "
                    )
                    suggestionRow(
                        title: "Rechercher sur le Web",
                        icon: "globe",
                        prefill: "Rechercher sur le Web : "
                    )
                    suggestionRow(
                        title: "✨ Présente-toi",
                        icon: "sparkles",
                        action: {
                            viewModel.introduceSarah()
                        }
                    )
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 14)
                .transition(.opacity)
            }
            
            // Barre de Saisie (Composer)
            MessageInputView(
                text: $viewModel.inputText,
                isRecording: viewModel.isMicRunning,
                onSend: { text in
                    viewModel.sendMessage(text)
                },
                onToggleMic: {
                    viewModel.toggleMicrophone()
                }
            )
            .padding(.bottom, 8)
        }
        .background(Color.black)
    }
    
    // MARK: - Ligne de Suggestion (.sug)
    
    @ViewBuilder
    private func suggestionRow(
        title: String,
        icon: String,
        prefill: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        Button(action: {
            HapticService.shared.buttonTap()
            if let act = action {
                act()
            } else if let p = prefill {
                viewModel.inputText = p
            }
        }) {
            HStack(spacing: 22) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                
                Text(title)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.white)
                    .tracking(-0.2)
                
                Spacer()
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
