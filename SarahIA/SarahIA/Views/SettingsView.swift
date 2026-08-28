import SwiftUI

/// Vue Réglages épurée et optimisée de Sarah AI Multi-Agents :
/// - Section Connexions : GitHub, Google, réseaux sociaux (Instagram, TikTok, YouTube, Twitter/X)
/// - Section Modèle IA adaptatif : détection automatique selon l'appareil
/// - Contrôles de vitesse, tonalité et détection vocale VAD
/// - Les 5 agents autonomes : Sarah, Tom, Raphaël, Yohan, Nathan
@available(iOS 15.0, *)
public struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: ChatViewModel
    
    @State private var speechRate: Double = 0.52
    @State private var speechPitch: Double = 1.05
    @State private var vadSensitivity: Double = 0.65
    
    // Connexions
    @State private var isGitHubConnected: Bool = false
    @State private var isGoogleConnected: Bool = false
    @State private var isInstagramConnected: Bool = false
    @State private var isTikTokConnected: Bool = false
    @State private var isYouTubeConnected: Bool = false
    @State private var isTwitterConnected: Bool = false
    @State private var showConnectionAlert: Bool = false
    @State private var connectionAlertTitle: String = ""
    @State private var connectionAlertMessage: String = ""
    
    public init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.07)
                    .ignoresSafeArea()
                
                Form {
                    // 0. Section Modèle IA Adaptatif
                    Section(header: Text("🤖 Intelligence Artificielle Adaptative").foregroundColor(Color(red: 0.85, green: 0.55, blue: 1.0))) {
                        let profile = AIResourceManager.shared.activeProfile
                        let capability = DeviceCapabilityDetector.shared.detectProfile()
                        
                        HStack {
                            Label("Statut du Moteur", systemImage: "bolt.fill")
                                .foregroundColor(.white)
                            Spacer()
                            Text("Actif (100% Local)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.green)
                        }
                        
                        HStack {
                            Label("Appareil Détecté", systemImage: "iphone")
                                .foregroundColor(.white)
                            Spacer()
                            Text(capability.hardwareTier.tierName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(red: 0.85, green: 0.55, blue: 1.0))
                        }
                        
                        HStack {
                            Label("Modèle Embarqué", systemImage: "cpu")
                                .foregroundColor(.white)
                            Spacer()
                            Text(profile?.internalEngineId ?? "Sarah Adaptive Core v2")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }
                        
                        HStack {
                            Label("Mémoire Allouée", systemImage: "memorychip")
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(capability.safeMemoryBudgetBytes / (1024 * 1024)) Mo")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }
                        
                        // Meilleur modèle selon l'iPhone
                        HStack {
                            Label("Meilleur Modèle Dispo", systemImage: "star.fill")
                                .foregroundColor(.white)
                            Spacer()
                            Text(bestModelForDevice())
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(red: 0.0, green: 0.78, blue: 1.0))
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.16))
                    
                    // 1. Section Connexions
                    Section(header: Text("🔗 Connexions").foregroundColor(Color(red: 0.0, green: 0.78, blue: 1.0))) {
                        
                        // GitHub
                        connectionRow(
                            title: "GitHub",
                            icon: "chevron.left.forwardslash.chevron.right",
                            iconColor: Color.white,
                            isConnected: $isGitHubConnected,
                            description: "Accès dépôts & code",
                            onConnect: {
                                openURL("https://github.com/login")
                            }
                        )
                        
                        // Google / Firebase Stitch
                        connectionRow(
                            title: "Google / Firebase",
                            icon: "g.circle.fill",
                            iconColor: Color(red: 0.98, green: 0.45, blue: 0.15),
                            isConnected: $isGoogleConnected,
                            description: "Google Stitch & Play Console",
                            onConnect: {
                                openURL("https://accounts.google.com")
                            }
                        )
                        
                        // Instagram
                        connectionRow(
                            title: "Instagram",
                            icon: "camera.fill",
                            iconColor: Color(red: 0.85, green: 0.15, blue: 0.55),
                            isConnected: $isInstagramConnected,
                            description: "Partage de photos & reels",
                            onConnect: {
                                openURL("https://www.instagram.com/accounts/login/")
                            }
                        )
                        
                        // TikTok
                        connectionRow(
                            title: "TikTok",
                            icon: "music.note",
                            iconColor: Color(red: 0.95, green: 0.15, blue: 0.35),
                            isConnected: $isTikTokConnected,
                            description: "Partage de vidéos courtes",
                            onConnect: {
                                openURL("https://www.tiktok.com/login")
                            }
                        )
                        
                        // YouTube
                        connectionRow(
                            title: "YouTube",
                            icon: "play.rectangle.fill",
                            iconColor: Color.red,
                            isConnected: $isYouTubeConnected,
                            description: "Upload & gestion chaîne",
                            onConnect: {
                                openURL("https://youtube.com")
                            }
                        )
                        
                        // Twitter / X
                        connectionRow(
                            title: "Twitter / X",
                            icon: "xmark.circle.fill",
                            iconColor: Color.white,
                            isConnected: $isTwitterConnected,
                            description: "Tweets & threads",
                            onConnect: {
                                openURL("https://twitter.com/login")
                            }
                        )
                    }
                    .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.16))
                    
                    // 2. Les 5 Agents Autonomes & Voix Siri Locales
                    Section(header: Text("Écosystème des 5 Agents Autonomes").foregroundColor(.white)) {
                        agentRow(
                            agent: .sarah,
                            subtitle: "Voix système principale (Rose néon)",
                            testPhrase: "Bonjour ! Je suis Sarah, votre agent pilote."
                        )
                        
                        agentRow(
                            agent: .tom,
                            subtitle: "Voix conversationnelle dédiée (Vert émeraude)",
                            testPhrase: "Salut ! C'est Tom. Je suis prêt pour analyser l'histoire et la géopolitique mondiale."
                        )
                        
                        agentRow(
                            agent: .raphael,
                            subtitle: "Voix de synthèse build & code (Bleu ciel)",
                            testPhrase: "Raphaël au rapport ! Prêt à générer vos applications et raccourcis Apple."
                        )
                        
                        agentRow(
                            agent: .yohan,
                            subtitle: "Voix bilingue FR ⇄ HE (Bleu Mer & Blanc)",
                            testPhrase: "Shalom ! Yohan à votre service pour toutes vos traductions en hébreu."
                        )
                        
                        agentRow(
                            agent: .nathan,
                            subtitle: "Expert IA mondial & Créatif (Violet Électrique)",
                            testPhrase: "Bonjour ! Je suis Nathan. Je suis connecté aux derniers modèles d'IA et je peux générer des vidéos et de la musique."
                        )
                    }
                    .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.16))
                    
                    // 3. Microphone & Détection Vocale Full-Duplex
                    Section(header: Text("Microphone & Détection Vocale VAD").foregroundColor(Color(red: 0.0, green: 0.78, blue: 1.0))) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Sensibilité VAD Full-Duplex")
                                Spacer()
                                Text("\(Int(vadSensitivity * 100))%")
                                    .foregroundColor(.gray)
                            }
                            Slider(value: $vadSensitivity, in: 0.3...0.9, step: 0.05)
                                .tint(Color(red: 0.0, green: 0.78, blue: 1.0))
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Vitesse de parole")
                                Spacer()
                                Text(String(format: "%.2fx", speechRate * 2.0))
                                    .foregroundColor(.gray)
                            }
                            Slider(value: $speechRate, in: 0.35...0.65, step: 0.01)
                                .tint(Color(red: 0.0, green: 0.78, blue: 1.0))
                        }
                    }
                    .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.16))
                    
                    // 4. Historique & Réinitialisation
                    Section(header: Text("Historique de Discussion").foregroundColor(.red)) {
                        Button(role: .destructive, action: {
                            HapticService.shared.buttonTap()
                            viewModel.startNewChat()
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Réinitialiser la conversation")
                            }
                        }
                    }
                    .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.16))
                }
                .hideScrollContentBackground()
            }
            .navigationTitle("⚙️ Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("OK") {
                        HapticService.shared.buttonTap()
                        viewModel.saveVoiceSettings(
                            rate: Float(speechRate),
                            pitch: Float(speechPitch),
                            vadSensitivity: Float(vadSensitivity)
                        )
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(Color(red: 0.0, green: 0.78, blue: 1.0))
                }
            }
            .onAppear {
                let s = StorageService.shared.loadState().voiceSettings
                self.speechRate = Double(s.speechRate)
                self.speechPitch = Double(s.speechPitch)
                self.vadSensitivity = Double(s.vadSensitivity)
            }
        }
    }
    
    // MARK: - Meilleur modèle selon l'appareil
    
    private func bestModelForDevice() -> String {
        let capability = DeviceCapabilityDetector.shared.detectProfile()
        switch capability.hardwareTier {
        case _ where capability.safeMemoryBudgetBytes >= 4 * 1024 * 1024 * 1024:
            // iPhone 14 Pro / 15 Pro / 16 Pro — 6 Go RAM
            return "GPT-4o · Claude 3.7 Sonnet"
        case _ where capability.safeMemoryBudgetBytes >= 2 * 1024 * 1024 * 1024:
            // iPhone 12 / 13 / 14 — 4 Go RAM
            return "GPT-4o mini · Llama 3.1 8B"
        case _ where capability.safeMemoryBudgetBytes >= 1 * 1024 * 1024 * 1024:
            // iPhone 11 / XR — 3 Go RAM
            return "Gemini Flash · Mistral 7B Q4"
        default:
            // iPhone plus ancien (5s, 6, 7, 8)
            return "Phi-3 Mini · TinyLlama 1.1B"
        }
    }
    
    // MARK: - Ligne de connexion réseau social
    
    @ViewBuilder
    private func connectionRow(
        title: String,
        icon: String,
        iconColor: Color,
        isConnected: Binding<Bool>,
        description: String,
        onConnect: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if isConnected.wrappedValue {
                // Connecté — bouton déconnecter
                Button(action: {
                    HapticService.shared.buttonTap()
                    isConnected.wrappedValue = false
                }) {
                    Text("Connecté")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // Non connecté — bouton se connecter
                Button(action: {
                    HapticService.shared.buttonTap()
                    onConnect()
                }) {
                    Text("Connecter")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(red: 0.0, green: 0.78, blue: 1.0))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(red: 0.0, green: 0.78, blue: 1.0).opacity(0.12))
                        .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Ouverture URL
    
    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
    
    // MARK: - Ligne Agent
    
    @ViewBuilder
    private func agentRow(agent: AgentType, subtitle: String, testPhrase: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(agent.themeColor.opacity(0.2))
                    .frame(width: 36, height: 36)
                
                Image(systemName: agent.iconName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(agent.themeColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(agent.rawValue)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button(action: {
                HapticService.shared.buttonTap()
                MultiAgentVoiceManager.shared.speak(text: testPhrase, for: agent)
            }) {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(agent.themeColor)
                    .padding(8)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Compatibility Extension
@available(iOS 13.0, *)
extension View {
    @ViewBuilder
    func hideScrollContentBackground() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}
