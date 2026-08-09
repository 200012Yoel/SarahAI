import SwiftUI

/// Vue principale de l'application Sarah AI — Mode Avatar 3D Plein Écran & Mode Conversation Texte.
public struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @Namespace private var bottomAnchor
    @State private var isHeaderExpanded: Bool = false
    @State private var isShowingMemoryVault: Bool = false
    @State private var isShowingSettings: Bool = false
    
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
        .sheet(isPresented: $isShowingMemoryVault) {
            MemoryVaultView(viewModel: viewModel)
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(viewModel: viewModel)
        }
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
                HStack(spacing: 8) {
                    statusPillBadge
                    Spacer()
                    
                    // Bouton Cerveau Permanent / Mémoire
                    Button(action: {
                        HapticService.shared.buttonTap()
                        isShowingMemoryVault = true
                    }) {
                        HStack(spacing: 4) {
                            Text("🧠")
                                .font(.system(size: 13))
                            if !viewModel.learnedMemories.isEmpty {
                                Text("\(viewModel.learnedMemories.count)")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.cyan)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .overlay(Capsule().stroke(Color.cyan.opacity(0.35), lineWidth: 1))
                        )
                    }
                    
                    // Bouton Réglages
                    Button(action: {
                        HapticService.shared.buttonTap()
                        isShowingSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.85))
                            .padding(8)
                            .background(Circle().fill(Color.white.opacity(0.12)))
                    }
                    
                    testNotificationPill
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                
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
            // Ondes d'énergie vocale (16 barres harmoniques)
            HStack(spacing: 4) {
                ForEach(0..<16) { index in
                    let height = voiceWaveHeight(for: index)
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.20, green: 0.65, blue: 1.0),
                                    Color(red: 0.75, green: 0.35, blue: 0.95)
                                ]),
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 3.5, height: height)
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
                            .fill(Color.black.opacity(0.7))
                            .overlay(
                                Capsule().stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .transition(.opacity)
            } else {
                Text(voiceStatusText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                    )
            }
        }
    }
    
    private var voiceStatusText: String {
        switch viewModel.voiceStatus {
        case .idle:
            return "Sarah écoute en continu • Parlez librement"
        case .listening:
            return "🎙️ Sarah vous écoute..."
        case .processing:
            return "💭 Réflexion..."
        case .speaking:
            return "🗣️ Sarah parle • Interrompez à tout moment"
        case .error(let msg):
            return msg
        }
    }
    
    private func voiceWaveHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 5.0
        let multiplier = CGFloat(viewModel.micInputLevel) * 40.0
        let harmonic = sin(Double(index) * 0.5 + Double(viewModel.micInputLevel * 5.0)) * Double(multiplier)
        return max(baseHeight, min(36.0, baseHeight + CGFloat(abs(harmonic))))
    }
    
    // MARK: - 2. Disposition Mode Conversation Texte (iMessage Style)
    
    private var textConversationLayout: some View {
        VStack(spacing: 0) {
            // En-tête iMessage Dark
            textModeHeader
            
            // Liste scrollable des bulles de messages
            messagesScrollView
            
            // Chips de suggestions d'actions rapides
            quickSuggestionsChips
            
            // Barre de saisie fluide (MessageInputView)
            MessageInputView(
                text: $viewModel.inputText,
                isTyping: viewModel.isTyping,
                onSend: viewModel.sendMessage
            )
        }
    }
    
    /// Suggestions rapides en chips défilants
    private var quickSuggestionsChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                suggestionChip("💡 Apprendre un mot", query: "Apprends ")
                suggestionChip("🧠 Que sais-tu ?", query: "Qu'est-ce que tu as appris ?")
                suggestionChip("👋 Bonjour Sarah", query: "Bonjour")
                suggestionChip("😄 Raconte une blague", query: "Raconte-moi une blague")
                suggestionChip("⏰ Quelle heure ?", query: "Quelle heure est-il ?")
                suggestionChip("✨ Qui es-tu ?", query: "Qui es-tu ?")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.09))
    }
    
    private func suggestionChip(_ label: String, query: String) -> some View {
        Button(action: {
            HapticService.shared.buttonTap()
            viewModel.sendQuickSuggestion(query)
        }) {
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
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
                    Text("VRoid 3D • Vocal & Texte")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            // Bouton Mémoire
            Button(action: {
                HapticService.shared.buttonTap()
                isShowingMemoryVault = true
            }) {
                HStack(spacing: 4) {
                    Text("🧠")
                    if !viewModel.learnedMemories.isEmpty {
                        Text("\(viewModel.learnedMemories.count)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.cyan)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Bouton Réglages
            Button(action: {
                HapticService.shared.buttonTap()
                isShowingSettings = true
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.75))
                    .padding(7)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
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
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 20)
            }
            .onChange(of: viewModel.messages.count) { _ in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    proxy.scrollTo("bottomAnchor", anchor: .bottom)
                }
            }
            .onChange(of: viewModel.isTyping) { isTyping in
                if isTyping {
                    withAnimation {
                        proxy.scrollTo("typingIndicator", anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - 3. Composants et Badges
    
    private var statusPillBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusIndicatorColor)
                .frame(width: 8, height: 8)
            
            Text(statusIndicatorLabel)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.6))
                .overlay(
                    Capsule().stroke(statusIndicatorColor.opacity(0.4), lineWidth: 1)
                )
        )
    }
    
    private var statusIndicatorColor: Color {
        switch viewModel.voiceStatus {
        case .idle:
            return .green
        case .listening:
            return .cyan
        case .processing:
            return .purple
        case .speaking:
            return .blue
        case .error:
            return .red
        }
    }
    
    private var statusIndicatorLabel: String {
        switch viewModel.voiceStatus {
        case .idle:
            return "Sarah Prête"
        case .listening:
            return "Écoute Active"
        case .processing:
            return "Réflexion..."
        case .speaking:
            return "Sarah Parle"
        case .error:
            return "Erreur"
        }
    }
    
    /// Bouton de test rapide en arrière-plan
    private var testNotificationPill: some View {
        Button {
            viewModel.sendBackgroundTest()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 11))
                Text("Bg Test")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.white.opacity(0.85))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.blue.opacity(0.25))
                    .overlay(
                        Capsule().stroke(Color.blue.opacity(0.4), lineWidth: 0.5)
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
                            .shadow(color: Color.black.opacity(0.5), radius: 10, x: 0, y: 5)
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

