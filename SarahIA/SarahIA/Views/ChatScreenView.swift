import SwiftUI

/// Écran principal de discussion 100% natif SwiftUI avec interface multi-agents,
/// disposition fixe Header / Messages / Barre basse au-dessus du clavier,
/// Voice Orb plein écran et Studio VAI Coding.
@available(iOS 15.0, *)
public struct ChatScreenView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject private var keyboard = KeyboardObserver.shared
    @Binding var isShowingSettings: Bool
    
    @State private var isShowingActionSheet: Bool = false
    @State private var isShowingVideoShare: Bool = false
    @State private var isShowingVoiceCallScreen: Bool = false
    @State private var isShowingWhatsAppVoiceScreen: Bool = false
    
    public init(viewModel: ChatViewModel, isShowingSettings: Binding<Bool>) {
        self.viewModel = viewModel
        self._isShowingSettings = isShowingSettings
    }
    
    private var topSafeArea: CGFloat {
        if #available(iOS 13.0, *) {
            let window = UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow }) ?? ($0 as? UIWindowScene)?.windows.first }
                .first
            if let top = window?.safeAreaInsets.top, top > 0 {
                return top
            }
        }
        return 20
    }
    
    private var bottomSafeArea: CGFloat {
        if #available(iOS 13.0, *) {
            let window = UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow }) ?? ($0 as? UIWindowScene)?.windows.first }
                .first
            if let insets = window?.safeAreaInsets {
                return insets.bottom
            }
        }
        return 0
    }
    
    private var currentBottomPadding: CGFloat {
        if keyboard.isVisible && keyboard.keyboardHeight > 0 {
            return keyboard.keyboardHeight + 6
        }
        return bottomSafeArea > 0 ? bottomSafeArea : 8
    }
    
    public var body: some View {
        ZStack {
            // Fond noir plein écran
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. En-tête (TopBar calée sous l'encoche / Dynamic Island)
                topBar
                    .padding(.top, topSafeArea)
                    .padding(.bottom, 6)
                
                // 2. Liste des messages (ScrollView)
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
                .contentShape(Rectangle())
                .onTapGesture {
                    keyboard.dismiss()
                }
                
                // 3. Zone de saisie (au-dessus du Home Indicator ou collée au clavier)
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
                    onShareVideo: {
                        isShowingVideoShare = true
                    }
                )
            }
            .padding(.bottom, currentBottomPadding)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .fullScreenCover(isPresented: $viewModel.isShowingVoiceOrbModal) {
            VoiceOrbModalView(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $viewModel.isShowingVAICodingStudio) {
            VAICodingStudioView(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $isShowingVoiceCallScreen) {
            VoiceCallScreenView()
        }
        .fullScreenCover(isPresented: $isShowingWhatsAppVoiceScreen) {
            WhatsAppVoiceCallView()
        }
        .sheet(isPresented: $isShowingVideoShare) {
            VideoShareView(viewModel: viewModel)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SarahPresentVoiceCallModal"))) { _ in
            isShowingVoiceCallScreen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SarahPresentWhatsAppVoiceModal"))) { _ in
            isShowingWhatsAppVoiceScreen = true
        }
        .actionSheet(isPresented: $isShowingActionSheet) {
            ActionSheet(
                title: Text("Écosystème Développeur & Multi-Agents"),
                buttons: [
                    .default(Text("💬 Talkie-Walkie WhatsApp (Nathan & Yoann)")) {
                        if let c = VoiceCallContactManager.shared.contacts.first {
                            OpenWAVoiceWalkieTalkieManager.shared.startSession(with: c)
                        }
                        isShowingWhatsAppVoiceScreen = true
                    },
                    .default(Text("📞 Appel Vocal WebRTC & Traduction IA")) {
                        if WebRTCVoiceCallManager.shared.callState == .idle, let c = VoiceCallContactManager.shared.contacts.first {
                            WebRTCVoiceCallManager.shared.startOutboundCall(to: c)
                        }
                        isShowingVoiceCallScreen = true
                    },
                    .default(Text("🎨 Générer une Image HD (Flux.1 Open Source)")) {
                        viewModel.inputText = "Génère une photo de "
                    },
                    .default(Text("🎵 Composer une Musique 100% Locale (DSP)")) {
                        viewModel.inputText = "Génère une musique lo-fi"
                    },
                    .default(Text("👁️ Vision & Analyse Multimodale (OCR)")) {
                        viewModel.inputText = "Analyse cette photo et décris ce que tu vois"
                    },
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
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Circle().fill(Color(white: 0.16)))
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
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Image(systemName: "chevron.down")
                        .font(.caption2)
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
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Circle().fill(Color(white: 0.16)))
            }
            .buttonStyle(ScaleBounceButtonStyle())
        }
        .padding(.horizontal, 16)
    }
}
