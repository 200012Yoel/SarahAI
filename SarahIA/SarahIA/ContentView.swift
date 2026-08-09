import SwiftUI

/// Vue principale de l'application Sarah AI — Mode Avatar 3D Plein Écran & Mode Conversation Texte.
public struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @Namespace private var bottomAnchor
    @State private var isHeaderExpanded: Bool = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Fond noir absolu (#000000) pour le mode Avatar ou dégradé sombre iMessage pour le mode Texte
            if viewModel.appMode == .avatar {
                Color.black
                    .ignoresSafeArea()
                    .transition(.opacity)
            } else {
                Color(red: 0.05, green: 0.05, blue: 0.07)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
            
            // CONTENU SELON LE MODE ACTIF
            if viewModel.appMode == .avatar {
                // ==========================================
                // 1. CLEAN FULL-SCREEN AVATAR MODE
                // ==========================================
                avatarFullScreenLayout
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .scale(scale: 1.05).combined(with: .opacity)
                    ))
            } else {
                // ==========================================
                // 2. TEXT THREAD MODE (iMessage Style)
                // ==========================================
                textConversationLayout
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
            }
            
            // BOUTON FLOTTANT DE BASCULEMENT DE MODE (Toujours accessible et fluide)
            floatingModeToggleBar
        }
        .statusBarHidden(viewModel.appMode == .avatar)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: viewModel.appMode)
    }
    
    // MARK: - 1. Disposition Mode Avatar Plein Écran
    
    private var avatarFullScreenLayout: some View {
        ZStack {
            // Fond noir absolu pitch black (#000000)
            Color.black
                .ignoresSafeArea()
            
            // Rendu 3D SceneKit Centré en Plein Écran
            Avatar3DView()
                .ignoresSafeArea()
            
            // Interface vocale épurée et indicateurs flottants
            VStack {
                // Barre supérieure discrète
                HStack {
                    statusPillBadge
                    Spacer()
                    testNotificationPill
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Spacer()
                
                // Transcription vocale en direct et ondelettes audio
                liveVoiceOverlay
                    .padding(.bottom, 90) // Espace pour la barre de contrôle flottante
            }
        }
    }
    
    /// Overlay vocal affichant l'état en direct et les ondes
    private var liveVoiceOverlay: some View {
        VStack(spacing: 12) {
            // Ondes d'énergie vocale
            HStack(spacing: 5) {
                ForEach(0..<12) { index in
                    let height = voiceWaveHeight(for: index)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.20, green: 0.60, blue: 1.0),
                                    Color(red: 0.75, green: 0.35, blue: 0.95)
                                ]),
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 4, height: height)
                }
            }
            .frame(height: 36)
            .animation(.spring(response: 0.15, dampingFraction: 0.5), value: viewModel.micInputLevel)
            
            // Transcription partielle en direct ou état
            if !viewModel.liveTranscriptionText.isEmpty {
                Text(viewModel.liveTranscriptionText)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.65))
                            .overlay(
                                Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    )
                    .transition(.opacity)
            } else {
                Text(voiceStatusText)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                    )
            }
        }
    }
    
    private var voiceStatusText: String {
        switch viewModel.voiceStatus {
        case .idle:
            return "Sarah est prête • Dites quelque chose"
        case .listening:
            return "Sarah écoute..."
        case .processing:
            return "Sarah réfléchit..."
        case .speaking:
            return "Sarah parle • Vous pouvez l'interrompre"
        case .error(let msg):
            return msg
        }
    }
    
    private func voiceWaveHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 6.0
        let multiplier = CGFloat(viewModel.micInputLevel) * 35.0
        let harmonic = sin(Double(index) * 0.6) * Double(multiplier)
        return max(baseHeight, min(36.0, baseHeight + CGFloat(abs(harmonic))))
    }
    
    // MARK: - 2. Disposition Mode Conversation Texte (iMessage Style)
    
    private var textConversationLayout: some View {
        VStack(spacing: 0) {
            // En-tête iMessage Dark
            textModeHeader
            
            // Liste scrollable des bulles de messages
            messagesScrollView
            
            // Barre de saisie fluide (MessageInputView)
            MessageInputView(
                text: $viewModel.inputText,
                isTyping: viewModel.isTyping,
                onSend: viewModel.sendMessage
            )
        }
    }
    
    /// En-tête supérieur en mode texte
    private var textModeHeader: some View {
        HStack(spacing: 12) {
            // Avatar miniature
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.35, green: 0.55, blue: 1.0),
                                Color(red: 0.70, green: 0.30, blue: 0.95)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 38, height: 38)
                
                Text("👩🏻‍💼")
                    .font(.system(size: 20))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Sarah AI")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                    Text("Vocal & Texte • En ligne")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            // Menu d'options (Réinitialisation conversation)
            Menu {
                Button(role: .destructive) {
                    viewModel.resetConversation()
                } label: {
                    Label("Effacer la conversation", systemImage: "trash")
                }
                
                Button {
                    viewModel.sendBackgroundTest()
                } label: {
                    Label("Tester notification background", systemImage: "bell.badge")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Color(red: 0.10, green: 0.10, blue: 0.12)
                .ignoresSafeArea(edges: .top)
        )
    }
    
    /// Liste scrollable des messages avec auto-scroll
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(viewModel.messages) { message in
                        ChatBubbleView(message: message)
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
                .padding(.horizontal, 12)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
            .onChange(of: viewModel.messages.count) { _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo("bottomAnchor", anchor: .bottom)
                }
            }
            .onChange(of: viewModel.isTyping) { _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo("bottomAnchor", anchor: .bottom)
                }
            }
        }
    }
    
    // MARK: - Composants UI Flottants & Pilules
    
    /// Badge d'état dans le coin supérieur gauche
    private var statusPillBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
                .shadow(color: .green.opacity(0.8), radius: 4)
            
            Text("Sarah AI 3D")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.12))
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
        )
    }
    
    /// Bouton de test rapide en arrière-plan
    private var testNotificationPill: some View {
        Button {
            viewModel.sendBackgroundTest()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 12))
                Text("Test Bg")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
            }
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.blue.opacity(0.3))
                    .overlay(
                        Capsule().stroke(Color.blue.opacity(0.5), lineWidth: 0.5)
                    )
            )
        }
    }
    
    /// Barre flottante de basculement de mode (Avatar 3D <-> Texte)
    private var floatingModeToggleBar: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 16) {
                // Bouton Bascule Mode
                Button(action: viewModel.toggleMode) {
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.appMode == .avatar ? "bubble.left.and.bubble.right.fill" : "person.crop.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                        
                        Text(viewModel.appMode == .avatar ? "Mode Conversation" : "Mode Avatar 3D")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.25, green: 0.45, blue: 0.95),
                                        Color(red: 0.65, green: 0.25, blue: 0.85)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 5)
                            .overlay(
                                Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1)
                            )
                    )
                }
            }
            .padding(.bottom, viewModel.appMode == .avatar ? 24 : 80)
        }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .preferredColorScheme(.dark)
    }
}

