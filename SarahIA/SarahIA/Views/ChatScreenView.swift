import SwiftUI

/// Écran principal de discussion 100% natif SwiftUI avec interface multi-agents,
/// synchronisation dynamique du clavier au-dessus de MessageBar, Voice Orb plein écran et Studio VAI Coding.
@available(iOS 14.0, *)
public struct ChatScreenView: View {
    @ObservedObject var viewModel: ChatViewModel
    @StateObject private var keyboard = KeyboardObserver()
    @Binding var isShowingSettings: Bool
    
    @State private var isShowingActionSheet: Bool = false
    @State private var isShowingVideoShare: Bool = false
    
    public init(viewModel: ChatViewModel, isShowingSettings: Binding<Bool>) {
        self.viewModel = viewModel
        self._isShowingSettings = isShowingSettings
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let windowTop: CGFloat = {
                if #available(iOS 13.0, *) {
                    return UIApplication.shared.connectedScenes
                        .compactMap { ($0 as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow }) ?? ($0 as? UIWindowScene)?.windows.first }
                        .first?.safeAreaInsets.top ?? 47
                }
                return 20
            }()
            let topPadding = geometry.safeAreaInsets.top > 0 ? geometry.safeAreaInsets.top : windowTop
            let bottomInset = geometry.safeAreaInsets.bottom
            
            VStack(spacing: 0) {
                // 1. Topbar Native avec indicateur d'Agent Actif (calée sous l'encoche / Dynamic Island)
                topBar
                    .padding(.top, topPadding)
                    .padding(.bottom, 6)
                
                // 2. Fil de discussion (MessageList)
                MessageList(
                    messages: viewModel.messages,
                    isTyping: viewModel.isTyping,
                    isKeyboardVisible: keyboard.isVisible,
                    onToggleSpeech: { message in
                        viewModel.toggleSpeechForMessage(message.content)
                    },
                    onSelectSuggestion: { suggestionText in
                        viewModel.sendMessage(suggestionText)
                    },
                    onIntroduceSarah: {
                        viewModel.introduceSarah()
                    },
                    onDismissKeyboard: {
                        keyboard.dismiss()
                    }
                )
                
                // 3. Barre de saisie (MessageBar) avec Capsule Vocale et switch des agents
                MessageBar(
                    text: $viewModel.inputText,
                    activeAgent: $viewModel.activeAgent,
                    isRecording: viewModel.isMicRunning,
                    onSend: { text in
                        viewModel.sendMessage(text)
                    },
                    onToggleMic: {
                        viewModel.toggleMicrophone()
                    },
                    onOpenVoiceOrb: {
                        viewModel.isShowingVoiceOrbModal = true
                    },
                    onOpenVAICoding: {
                        viewModel.isShowingVAICodingStudio = true
                    },
                    onPlusTapped: {
                        isShowingActionSheet = true
                    },
                    onShareVideo: {
                        isShowingVideoShare = true
                    }
                )
                .padding(.bottom, keyboard.keyboardHeight > 0 ? (keyboard.keyboardHeight + 8) : max(16, bottomInset + 8))
                .animation(.interpolatingSpring(stiffness: 300, damping: 30), value: keyboard.keyboardHeight)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .ignoresSafeArea(edges: .top)
        }
        .ignoresSafeArea(.keyboard)
        .fullScreenCover(isPresented: $viewModel.isShowingVoiceOrbModal) {
            VoiceOrbModalView(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $viewModel.isShowingVAICodingStudio) {
            VAICodingStudioView(viewModel: viewModel)
        }
        .sheet(isPresented: $isShowingVideoShare) {
            VideoShareView(viewModel: viewModel)
        }
        .actionSheet(isPresented: $isShowingActionSheet) {
            ActionSheet(
                title: Text("Écosystème Développeur & Multi-Agents"),
                buttons: [
                    .default(Text("💬 Nathan — Statut & Vidéo WhatsApp")) {
                        viewModel.activeAgent = .nathan
                        viewModel.sendMessage("Nathan, je veux mettre une vidéo sur mon statut WhatsApp")
                    },
                    .default(Text("📱 Nathan — Publier sur les Réseaux Sociaux")) {
                        viewModel.activeAgent = .nathan
                        viewModel.sendMessage("Nathan, quels sont mes réseaux sociaux connectés ?")
                    },
                    .default(Text("🎨 Ethel — Créativité & Studio Graphique")) {
                        viewModel.activeAgent = .ethel
                        viewModel.sendMessage("Bonjour Ethel ! Raconte-moi ce que tu prépares.")
                    },
                    .default(Text("🎵 Nathan — Générer une Musique Rapide")) {
                        viewModel.activeAgent = .nathan
                        viewModel.inputText = "Compose une musique "
                    },
                    .default(Text("🤖 Nathan — Meilleurs modèles d'IA")) {
                        viewModel.activeAgent = .nathan
                        viewModel.sendMessage("Quels sont les meilleurs modèles d'IA disponibles en ce moment ?")
                    },
                    .default(Text("💻 Studio VAI Coding & Build (Esther)")) {
                        viewModel.activeAgent = .esther
                        viewModel.isShowingVAICodingStudio = true
                    },
                    .default(Text("🐙 Se Connecter à GitHub")) {
                        viewModel.activeAgent = .esther
                        viewModel.sendMessage("Connecte-toi à GitHub")
                    },
                    .default(Text("📧 Boîte Google Gmail")) {
                        viewModel.activeAgent = .esther
                        viewModel.sendMessage("Ouvre mes mails Gmail")
                    },
                    .default(Text("🔮 Ouvrir l'Orbe Vocal Immersif")) {
                        viewModel.isShowingVoiceOrbModal = true
                    },
                    .default(Text("🇮🇱 Traduction Hébreu ⇄ Français (Yohan)")) {
                        viewModel.activeAgent = .yohan
                        viewModel.inputText = "Comment on dit en hébreu : "
                    },
                    .default(Text("🌍 Débat Géopolitique & Histoire (Tom)")) {
                        viewModel.activeAgent = .tom
                        viewModel.inputText = "Raconte-moi l'histoire de "
                    },
                    .default(Text("👑 Parler à Sarah (Pilote)")) {
                        viewModel.activeAgent = .sarah
                        viewModel.introduceSarah()
                    },
                    .cancel(Text("Annuler"))
                ]
            )
        }
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
            
            // Titre de l'agent actif (centre)
            Button(action: {
                viewModel.isShowingVoiceOrbModal = true
            }) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.activeAgent.themeColor)
                        .frame(width: 8, height: 8)
                    
                    Text(viewModel.activeAgent.rawValue)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Bouton Paramètres — Roue crantée ⚙️
            Button(action: {
                HapticService.shared.buttonTap()
                keyboard.dismiss()
                isShowingSettings = true
            }) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.11, green: 0.11, blue: 0.12))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(ScaleBounceButtonStyle())
        }
        .padding(.horizontal, 16)
    }
}
