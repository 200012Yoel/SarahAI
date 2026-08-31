import SwiftUI

/// Écran principal de discussion 100% natif SwiftUI avec interface multi-agents,
/// disposition fixe Header / Messages / Barre basse au-dessus du clavier,
/// Voice Orb plein écran et Studio VAI Coding.
@available(iOS 15.0, *)
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
        ZStack {
            // Fond noir plein écran
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. En-tête (TopBar)
                topBar
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
                
                // 3. Zone de saisie
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
                // 16 pt au repos pour surélever la barre au-dessus du Home Indicator, 6 pt quand le clavier est actif
                .padding(.bottom, keyboard.isVisible ? 6 : 16)
            }
        }
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
