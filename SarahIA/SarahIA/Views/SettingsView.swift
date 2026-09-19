import SwiftUI
import UIKit

/// Vue Réglages épurée et optimisée de Sarah AI Multi-Agents (100% Moteur Local On-Device) :
/// - Section Mode : Bouton et sélecteur interactif des Modes (Sarah, Nathan, Esther, Tom, Yohan, Ethel)
/// - Section Connexions : Instagram, TikTok, YouTube, Twitter/X, GitHub, Google
/// - Écosystème des 6 Agents & Voix Siri dédiées
/// - Contrôles de vitesse, tonalité et détection vocale VAD
@available(iOS 15.0, *)
public struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: ChatViewModel
    
    @State private var speechRate: Double = 0.52
    @State private var speechPitch: Double = 1.05
    @State private var vadSensitivity: Double = 0.65
    
    // Connexions Réseaux Sociaux
    @State private var isInstagramConnected: Bool = false
    @State private var isTikTokConnected: Bool = false
    @State private var isYouTubeConnected: Bool = false
    @State private var isTwitterConnected: Bool = false
    @State private var isGitHubConnected: Bool = false
    @State private var isGoogleConnected: Bool = false
    
    public init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
    }

    /// Accueil des réglages : sombre, compact et cohérent avec le menu latéral.
    public var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        engineHeader

                        Text("RÉGLAGES")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.42))
                            .padding(.horizontal, 4)

                        VStack(spacing: 0) {
                            settingsLink(
                                destination: AgentsSettingsView(viewModel: viewModel),
                                icon: "person.2.fill",
                                tint: .sarahIndigo,
                                title: "Agents",
                                detail: "Les assistants et leurs rôles"
                            )

                            settingsDivider

                            settingsLink(
                                destination: ConnectionsSettingsView(),
                                icon: "link",
                                tint: .sarahCyan,
                                title: "Connexions",
                                detail: "Services disponibles et leur état"
                            )

                            settingsDivider

                            settingsLink(
                                destination: VoiceAndSpeechSettingsView(
                                    viewModel: viewModel,
                                    speechRate: $speechRate,
                                    speechPitch: $speechPitch,
                                    vadSensitivity: $vadSensitivity
                                ),
                                icon: "waveform",
                                tint: .purple,
                                title: "Voix et parole",
                                detail: "Voix, vitesse et microphone"
                            )

                            settingsDivider

                            settingsLink(
                                destination: SarahEngineSettingsView(viewModel: viewModel),
                                icon: "sparkles",
                                tint: .pink,
                                title: "Sarah Engine",
                                detail: "Activation et mode vocal"
                            )

                            settingsDivider

                            settingsLink(
                                destination: LocalGenerationSettingsView(),
                                icon: "wand.and.stars",
                                tint: .purple,
                                title: "Création locale",
                                detail: "Images et vidéo adaptées à l’iPhone"
                            )

                            settingsDivider

                            settingsLink(
                                destination: DataAndConversationsSettingsView(
                                    viewModel: viewModel,
                                    onStartNewChat: startNewChatAndDismiss
                                ),
                                icon: "bubble.left.and.bubble.right.fill",
                                tint: .orange,
                                title: "Données et discussions",
                                detail: "Historique et nouvelle conversation"
                            )

                            settingsDivider

                            settingsLink(
                                destination: AboutSettingsView(),
                                icon: "info.circle.fill",
                                tint: .gray,
                                title: "À propos",
                                detail: "Version, licences et notices"
                            )
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color.white.opacity(0.085))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Terminé") {
                        saveVoiceSettingsAndDismiss()
                    }
                    .foregroundColor(viewModel.activeAgent.themeColor)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: loadVoiceSettings)
    }

    private var engineHeader: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.sarahCyan.opacity(0.15))

                Image(systemName: "cpu.fill")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundColor(.sarahCyan)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text("Sarah Engine")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)

                Text("Agents, voix et modèles locaux")
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.52))
            }

            Spacer(minLength: 8)

            Text(HardwareDetector.detectTier() == .highEnd ? "Optimisé" : "Adapté")
                .font(.caption.weight(.semibold))
                .foregroundColor(.green)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.085))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var settingsDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.065))
            .frame(height: 1)
            .padding(.leading, 62)
    }

    private func settingsLink<Destination: View>(
        destination: Destination,
        icon: String,
        tint: Color,
        title: String,
        detail: String
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 13) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(tint)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(tint.opacity(0.14))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.white)

                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.46))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.30))
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 68)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func loadVoiceSettings() {
        let settings = StorageService.shared.loadState().voiceSettings
        speechRate = Double(settings.speechRate)
        speechPitch = Double(settings.speechPitch)
        vadSensitivity = Double(settings.vadSensitivity)
    }

    private func saveVoiceSettingsAndDismiss() {
        HapticService.shared.buttonTap()
        viewModel.saveVoiceSettings(
            rate: Float(speechRate),
            pitch: Float(speechPitch),
            vadSensitivity: Float(vadSensitivity)
        )
        presentationMode.wrappedValue.dismiss()
    }

    private func startNewChatAndDismiss() {
        HapticService.shared.buttonTap()
        viewModel.startNewChat()
        presentationMode.wrappedValue.dismiss()
    }

    // Conservé temporairement comme référence des anciens réglages détaillés.
    // L'interface affichée par `body` est désormais l'accueil hiérarchisé ci-dessus.
    private var legacySettingsBody: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.07)
                    .ignoresSafeArea()
                
                Form {
                    // 0. Section Mode de Fonctionnement & Agent Actif
                    Section(header: Text("✨ Mode de Fonctionnement").foregroundColor(Color(red: 0.85, green: 0.55, blue: 1.0))) {
                        
                        // Carte du Mode Actuel avec bouton interactif
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(viewModel.activeAgent.themeColor.opacity(0.20))
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: viewModel.activeAgent.iconName)
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(viewModel.activeAgent.themeColor)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text("Mode \(viewModel.activeAgent.rawValue)")
                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                        
                                        Text("ACTIF")
                                            .font(.system(size: 9, weight: .black, design: .rounded))
                                            .foregroundColor(.black)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(viewModel.activeAgent.themeColor)
                                            .cornerRadius(4)
                                    }
                                    
                                    Text(viewModel.activeAgent.specialtySubtitle)
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                            }
                            
                            // Barre horizontale des 6 capsules d'agents
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(AgentType.allCases) { agent in
                                        Button(action: {
                                            HapticService.shared.buttonTap()
                                            viewModel.activeAgent = agent
                                        }) {
                                            HStack(spacing: 5) {
                                                Image(systemName: agent.iconName)
                                                    .font(.system(size: 11, weight: .bold))
                                                Text(agent.rawValue)
                                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            }
                                            .foregroundColor(viewModel.activeAgent == agent ? .white : .gray)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(
                                                viewModel.activeAgent == agent ?
                                                agent.themeColor.opacity(0.35) :
                                                Color.white.opacity(0.06)
                                            )
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(
                                                        viewModel.activeAgent == agent ? agent.themeColor : Color.clear,
                                                        lineWidth: 1
                                                    )
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    
                    // 1. Section Moteur IA Local On-Device (Sarah Neural Engine)
                    Section(header: Text("🧠 Moteur 100% Local On-Device").foregroundColor(Color(red: 0.0, green: 0.78, blue: 1.0))) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Moteur Actif :")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("Sarah Neural Engine")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color(red: 0.0, green: 0.78, blue: 1.0))
                            }
                            
                            HStack {
                                Text("Mode d'Inférence :")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("100% Local (Apple Neural Engine / GPU)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.green)
                            }
                            
                            Text("Toutes les réponses textuelles et traitements neuronaux sont exécutés localement sur la puce de votre iPhone, sans aucun recours à des serveurs distants.")
                                .font(.system(size: 11))
                                .foregroundColor(.gray.opacity(0.85))
                                .padding(.top, 2)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.16))
                    
                    // 2. Section Connexions & Réseaux Sociaux
                    Section(header: Text("🔗 Réseaux Sociaux & Connexions").foregroundColor(Color(red: 0.85, green: 0.55, blue: 1.0))) {
                        
                        // Instagram
                        connectionRow(
                            title: "Instagram",
                            icon: "camera.fill",
                            iconColor: Color(red: 0.85, green: 0.15, blue: 0.55),
                            isConnected: $isInstagramConnected,
                            description: "Partage de photos & publications",
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
                            description: "Partage & publications",
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
                            description: "Gestion de chaîne & vidéos",
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
                            description: "Publications & interactions",
                            onConnect: {
                                openURL("https://twitter.com/login")
                            }
                        )
                        
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
                        
                        // Google / Firebase
                        connectionRow(
                            title: "Google / Firebase",
                            icon: "g.circle.fill",
                            iconColor: Color(red: 0.98, green: 0.45, blue: 0.15),
                            isConnected: $isGoogleConnected,
                            description: "Services & synchronisation",
                            onConnect: {
                                openURL("https://accounts.google.com")
                            }
                        )
                    }
                    .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.16))
                    
                    // 3. Écosystème des 6 Agents & Voix Siri Dédiées
                    Section(header: Text("Écosystème des 6 Agents Autonomes").foregroundColor(.white)) {
                        agentRow(
                            agent: .sarah,
                            subtitle: "Voix système principale (Rose néon)",
                            testPhrase: "Bonjour ! Je suis Sarah, votre agent pilote."
                        )
                        
                        agentRow(
                            agent: .nathan,
                            subtitle: "Expert Réseaux Sociaux & Automatisation (Violet Néon)",
                            testPhrase: "Salut ! C'est Nathan. Je suis prêt pour la gestion de tes réseaux sociaux et automatisations."
                        )
                        
                        agentRow(
                            agent: .esther,
                            subtitle: "Voix de synthèse build & code (Bleu ciel)",
                            testPhrase: "Bonjour ! C'est Esther. Prête pour le build et le voice coding !"
                        )
                        
                        agentRow(
                            agent: .tom,
                            subtitle: "Voix conversationnelle dédiée (Vert émeraude)",
                            testPhrase: "Salut ! C'est Tom. Je suis prêt pour analyser l'histoire et la géopolitique mondiale."
                        )
                        
                        agentRow(
                            agent: .yohan,
                            subtitle: "Voix masculine bilingue FR ⇄ HE (Siri Canadien)",
                            testPhrase: "Shalom ! C'est Yoann à votre service pour toutes vos traductions en hébreu."
                        )
                        
                        agentRow(
                            agent: .ethel,
                            subtitle: "Voix féminine dédiée (Thème Bleu & Rouge)",
                            testPhrase: "Bonjour ! Je suis Ethel. Mon espace est prêt et attend vos prochaines instructions !"
                        )
                    }
                    .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.16))
                    
                    // 4. Microphone & Détection Vocale Full-Duplex
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
                    
                    // 5. Historique & Réinitialisation
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

                    Section(header: Text("À propos").foregroundColor(Color(red: 0.0, green: 0.78, blue: 1.0))) {
                        NavigationLink(destination: LegalNoticesView()) {
                            HStack(spacing: 12) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .foregroundColor(Color(red: 0.0, green: 0.78, blue: 1.0))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Licences et notices")
                                        .foregroundColor(.white)
                                    Text("Sarah Engine, modèle IA et composants système")
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
                                }
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

// MARK: - Accueil et destinations des réglages

/// Une ligne compacte, inspirée des listes de réglages iOS, réutilisée par
/// l'accueil pour garder la hiérarchie lisible sans masquer les informations.
@available(iOS 15.0, *)
private struct SettingsHomeRow: View {
    let icon: String
    let tint: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundColor(.primary)
                Text(detail)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

@available(iOS 15.0, *)
private struct AgentsSettingsView: View {
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        List {
            Section("Agent actif") {
                HStack(spacing: 12) {
                    Image(systemName: viewModel.activeAgent.iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(viewModel.activeAgent.themeColor)
                        .frame(width: 38, height: 38)
                        .background(viewModel.activeAgent.themeColor.opacity(0.14))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(settingsDisplayName(for: viewModel.activeAgent))
                            .font(.headline)
                        Text(viewModel.activeAgent.specialtySubtitle)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }

            Section("Tous les agents") {
                ForEach(AgentType.allCases) { agent in
                    HStack(spacing: 8) {
                        Button {
                            HapticService.shared.buttonTap()
                            viewModel.activeAgent = agent
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: agent.iconName)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(agent.themeColor)
                                    .frame(width: 34, height: 34)
                                    .background(agent.themeColor.opacity(0.12))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(settingsDisplayName(for: agent))
                                        .font(.body.weight(.semibold))
                                        .foregroundColor(.primary)
                                    Text(agent.specialtySubtitle)
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }

                                Spacer(minLength: 8)

                                if viewModel.activeAgent == agent {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(agent.themeColor)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button {
                            HapticService.shared.buttonTap()
                            MultiAgentVoiceManager.shared.speak(
                                text: settingsTestPhrase(for: agent),
                                for: agent
                            )
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(agent.themeColor)
                                .frame(width: 34, height: 34)
                                .background(agent.themeColor.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .accessibilityLabel("Écouter la voix de \(settingsDisplayName(for: agent))")
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Agents")
        .navigationBarTitleDisplayMode(.inline)
    }
}

@available(iOS 15.0, *)
private struct ConnectionsSettingsView: View {
    private struct Connection: Identifiable {
        let id: String
        let icon: String
        let tint: Color
        let title: String
        let detail: String
        let signInURL: URL
    }

    private let connections: [Connection] = [
        Connection(
            id: "instagram",
            icon: "camera.fill",
            tint: Color(red: 0.85, green: 0.15, blue: 0.55),
            title: "Instagram",
            detail: "Photos et publications",
            signInURL: URL(string: "https://www.instagram.com/accounts/login/")!
        ),
        Connection(
            id: "tiktok",
            icon: "music.note",
            tint: Color(red: 0.95, green: 0.15, blue: 0.35),
            title: "TikTok",
            detail: "Vidéos et publications",
            signInURL: URL(string: "https://www.tiktok.com/login")!
        ),
        Connection(
            id: "youtube",
            icon: "play.rectangle.fill",
            tint: .red,
            title: "YouTube",
            detail: "Chaîne et vidéos",
            signInURL: URL(string: "https://youtube.com")!
        ),
        Connection(
            id: "x",
            icon: "xmark.circle.fill",
            tint: .secondary,
            title: "Twitter / X",
            detail: "Publications et interactions",
            signInURL: URL(string: "https://twitter.com/login")!
        ),
        Connection(
            id: "github",
            icon: "chevron.left.forwardslash.chevron.right",
            tint: .secondary,
            title: "GitHub",
            detail: "Dépôts et code",
            signInURL: URL(string: "https://github.com/login")!
        ),
        Connection(
            id: "google",
            icon: "g.circle.fill",
            tint: Color(red: 0.98, green: 0.45, blue: 0.15),
            title: "Google / Firebase",
            detail: "Services et synchronisation",
            signInURL: URL(string: "https://accounts.google.com")!
        )
    ]

    var body: some View {
        List {
            Section {
                Text("Aucun service n’est actuellement authentifié dans Sarah IA. Ouvrir un service affiche sa page de connexion sans le marquer comme connecté dans l’application.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section("Services") {
                ForEach(connections) { connection in
                    Button {
                        HapticService.shared.buttonTap()
                        UIApplication.shared.open(connection.signInURL)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: connection.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(connection.tint)
                                .frame(width: 34, height: 34)
                                .background(connection.tint.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(connection.title)
                                    .foregroundColor(.primary)
                                Text(connection.detail)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Non configuré")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Image(systemName: "arrow.up.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.sarahCyan)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityHint("Ouvre la page de connexion de \(connection.title)")
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Connexions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

@available(iOS 15.0, *)
private struct VoiceAndSpeechSettingsView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var speechRate: Double
    @Binding var speechPitch: Double
    @Binding var vadSensitivity: Double

    var body: some View {
        List {
            Section("Voix active") {
                HStack(spacing: 12) {
                    Image(systemName: viewModel.activeAgent.iconName)
                        .foregroundColor(viewModel.activeAgent.themeColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(settingsDisplayName(for: viewModel.activeAgent))
                        Text("\(settingsDisplayName(for: viewModel.activeAgent)) · Voix système Apple")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.72))
                    }
                }
            }

            Section("Parole") {
                settingSlider(
                    title: "Vitesse de parole",
                    value: String(format: "%.2fx", speechRate * 2.0),
                    binding: $speechRate,
                    range: 0.35...0.65,
                    step: 0.01
                )

                settingSlider(
                    title: "Hauteur de la voix",
                    value: String(format: "%.2f", speechPitch),
                    binding: $speechPitch,
                    range: 0.80...1.20,
                    step: 0.01
                )
            }

            Section("Microphone") {
                settingSlider(
                    title: "Sensibilité de détection vocale",
                    value: "\(Int(vadSensitivity * 100)) %",
                    binding: $vadSensitivity,
                    range: 0.30...0.90,
                    step: 0.05
                )
            }

            Section {
                Text("Les modifications sont enregistrées lorsque vous touchez Terminé dans les réglages.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Voix et parole")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func settingSlider(
        title: String,
        value: String,
        binding: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(value)
                    .foregroundColor(.secondary)
            }
            Slider(value: binding, in: range, step: step)
                .tint(.sarahCyan)
        }
        .padding(.vertical, 2)
    }
}

@available(iOS 15.0, *)
private struct LocalGenerationSettingsView: View {
    @AppStorage("sarahAllowCloudGeneration") private var allowCloudGeneration: Bool = false
    @StateObject private var downloader = GenerativeModelDownloader.shared
    @State private var musicDownloadProgress: Double = 0
    @State private var musicStatus: String = ""
    @State private var isPreparingMusic: Bool = false

    private let imageProfile = SarahGenerativeModelCatalog.imageProfile()
    private let videoProfile = SarahGenerativeModelCatalog.videoProfile()
    private let musicProfile = SarahGenerativeModelCatalog.musicProfile()
    private let vocalSongProfile = SarahGenerativeModelCatalog.vocalSongProfile()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    capabilityCard(
                        icon: "photo.fill",
                        tint: .purple,
                        title: "Images",
                        profile: imageProfile,
                        kind: .image
                    )

                    capabilityCard(
                        icon: "video.fill",
                        tint: .orange,
                        title: "Vidéo",
                        profile: videoProfile,
                        kind: .video
                    )

                    musicCapabilityCard

                    vocalSongCapabilityCard

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Sélection automatique", systemImage: "cpu")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text("Sarah choisit le profil selon la RAM et la version d’iOS. Un futur iPhone plus puissant basculera automatiquement vers un profil plus lourd sans modifier l’interface.")
                            .font(.footnote)
                            .foregroundColor(Color.white.opacity(0.54))

                        Text(String(format: "RAM détectée : %.1f Go • iOS %d", SarahGenerativeModelCatalog.physicalRAMGB, SarahGenerativeModelCatalog.iosMajor))
                            .font(.caption.monospaced())
                            .foregroundColor(Color.white.opacity(0.38))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.075))
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $allowCloudGeneration) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Fallback réseau")
                                    .font(.headline)
                                    .foregroundColor(.white)

                                Text("Utiliser un service distant seulement si le modèle local est indisponible.")
                                    .font(.footnote)
                                    .foregroundColor(Color.white.opacity(0.54))
                            }
                        }
                        .tint(.purple)

                        if allowCloudGeneration {
                            Text("Les prompts de génération peuvent alors quitter l’iPhone. Sarah l’indiquera dans la réponse.")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.075))
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Règle de confidentialité", systemImage: "checkmark.shield.fill")
                            .font(.headline)
                            .foregroundColor(.green)

                        Text("Sarah n’affiche « local » que si les poids et l’inférence s’exécutent réellement sur l’iPhone. Un service distant doit être annoncé comme tel et reste désactivé par défaut pour les fonctions génératives.")
                            .font(.footnote)
                            .foregroundColor(Color.white.opacity(0.54))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.075))
                    )
                }
                .padding(18)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Création locale")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
    }

    private var musicCapabilityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.pink)
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.pink.opacity(0.14))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("Musique / instrumental")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color.white.opacity(0.46))

                    Text(musicProfile.displayName)
                        .font(.headline)
                        .foregroundColor(.white)
                }

                Spacer(minLength: 8)
                statusBadge(musicProfile.runtimeState)
            }

            HStack(spacing: 8) {
                capsule(musicProfile.resolution)
                capsule(musicProfile.licenseName)
            }

            Text(musicProfile.note)
                .font(.footnote)
                .foregroundColor(Color.white.opacity(0.54))
                .fixedSize(horizontal: false, vertical: true)

            if isPreparingMusic {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: musicDownloadProgress)
                        .tint(.pink)

                    HStack {
                        Text(musicStatus.isEmpty ? "Préparation du modèle…" : musicStatus)
                            .font(.caption)
                            .foregroundColor(Color.white.opacity(0.58))
                        Spacer()
                        Text("\(Int(musicDownloadProgress * 100)) %")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(Color.white.opacity(0.58))
                    }
                }
            } else if musicProfile.runtimeState != .unsupported {
                Button {
                    HapticService.shared.buttonTap()
                    prepareMusicModel()
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Préparer le modèle musical local")
                        Spacer()
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.pink)
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
            }

            if !musicStatus.isEmpty && !isPreparingMusic {
                Text(musicStatus)
                    .font(.caption)
                    .foregroundColor(
                        musicStatus.contains("prêt") ? .green : Color.white.opacity(0.48)
                    )
            }

            if let source = URL(string: musicProfile.sourceURL), !musicProfile.sourceURL.isEmpty {
                Link(destination: source) {
                    Label("Source du modèle", systemImage: "arrow.up.right.square")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.pink)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.085))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var vocalSongCapabilityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "music.mic")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.cyan)
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.cyan.opacity(0.14))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("Chanson avec paroles")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color.white.opacity(0.46))

                    Text(vocalSongProfile.displayName)
                        .font(.headline)
                        .foregroundColor(.white)
                }

                Spacer(minLength: 8)
                statusBadge(vocalSongProfile.runtimeState)
            }

            HStack(spacing: 8) {
                capsule(vocalSongProfile.resolution)
                capsule(vocalSongProfile.licenseName)
            }

            Text(vocalSongProfile.note)
                .font(.footnote)
                .foregroundColor(Color.white.opacity(0.54))
                .fixedSize(horizontal: false, vertical: true)

            Text("Français et anglais prévus. L'option reste verrouillée tant qu'un runtime iPhone réellement local n'a pas été validé.")
                .font(.caption)
                .foregroundColor(.orange)

            if let source = URL(string: vocalSongProfile.sourceURL), !vocalSongProfile.sourceURL.isEmpty {
                Link(destination: source) {
                    Label("Projet ACE-Step", systemImage: "arrow.up.right.square")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.cyan)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.085))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func prepareMusicModel() {
        guard #available(iOS 27.0, *) else {
            musicStatus = "La génération musicale locale nécessite iOS 27."
            return
        }

        isPreparingMusic = true
        musicDownloadProgress = 0
        musicStatus = "Téléchargement du modèle musical…"

        SarahLocalMusicGenEngine.shared.prepareInstrumentalModel(
            progress: { value, file in
                musicDownloadProgress = value
                musicStatus = file.isEmpty ? "Téléchargement du modèle musical…" : file
            },
            completion: { result in
                isPreparingMusic = false
                switch result {
                case .success:
                    musicDownloadProgress = 1
                    musicStatus = "Modèle musical local prêt"
                case .failure(let error):
                    musicStatus = error.localizedDescription
                }
            }
        )
    }

    private func capabilityCard(
        icon: String,
        tint: Color,
        title: String,
        profile: SarahGenerativeModelProfile,
        kind: GenerativeModelDownloader.DownloadKind
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(tint)
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(tint.opacity(0.14))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color.white.opacity(0.46))

                    Text(profile.displayName)
                        .font(.headline)
                        .foregroundColor(.white)
                }

                Spacer(minLength: 8)

                statusBadge(profile.runtimeState)
            }

            HStack(spacing: 8) {
                if profile.resolution != "—" {
                    capsule(profile.resolution)
                }
                if profile.licenseName != "—" {
                    capsule(profile.licenseName)
                }
            }

            Text(profile.note)
                .font(.footnote)
                .foregroundColor(Color.white.opacity(0.54))
                .fixedSize(horizontal: false, vertical: true)

            modelInstallControls(profile: profile, kind: kind, tint: tint)

            if let source = URL(string: profile.sourceURL), !profile.sourceURL.isEmpty {
                Link(destination: source) {
                    HStack(spacing: 7) {
                        Image(systemName: "arrow.up.right.square")
                        Text("Source du modèle")
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(tint)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.085))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func modelInstallControls(
        profile: SarahGenerativeModelProfile,
        kind: GenerativeModelDownloader.DownloadKind,
        tint: Color
    ) -> some View {
        let installed = downloader.isInstalled(kind: kind)
        let isActive = downloader.isDownloading && downloader.activeKind == kind

        if profile.runtimeState == .unsupported {
            EmptyView()
        } else if isActive {
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: downloader.progress)
                    .tint(tint)

                HStack {
                    Text(downloader.statusText)
                        .font(.caption)
                        .foregroundColor(Color.white.opacity(0.58))

                    Spacer()

                    Text("\(Int(downloader.progress * 100)) %")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(Color.white.opacity(0.58))
                }

                Button("Annuler") {
                    downloader.cancel()
                }
                .font(.footnote.weight(.semibold))
                .foregroundColor(.orange)
            }
        } else if installed {
            HStack(spacing: 8) {
                Image(systemName: kind == .image ? "checkmark.circle.fill" : "tray.and.arrow.down.fill")
                Text(kind == .image ? "Modèle local installé" : "Checkpoint local téléchargé")
            }
            .font(.footnote.weight(.semibold))
            .foregroundColor(.green)
        } else {
            Button {
                HapticService.shared.buttonTap()
                if kind == .image {
                    downloader.startImageModelDownload()
                } else {
                    downloader.startVideoModelDownload()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                    Text(
                        kind == .image
                            ? "Télécharger le modèle local"
                            : (profile.identifier == "mobilei2v-027b"
                                ? "Télécharger MobileI2V"
                                : "Paquet vidéo non automatisé")
                    )
                    Spacer()
                }
                .font(.footnote.weight(.semibold))
                .foregroundColor(tint)
                .padding(.vertical, 4)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(kind == .video && profile.identifier != "mobilei2v-027b")
        }

        if !downloader.statusText.isEmpty,
           !downloader.isDownloading,
           downloader.activeKind == nil {
            Text(downloader.statusText)
                .font(.caption)
                .foregroundColor(Color.white.opacity(0.48))
        }
    }

    private func capsule(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundColor(Color.white.opacity(0.72))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.white.opacity(0.08)))
    }

    private func statusBadge(_ state: SarahGenerativeRuntimeState) -> some View {
        let text: String
        let color: Color

        switch state {
        case .ready:
            text = "Prêt"
            color = .green
        case .requiresDownload:
            text = "À télécharger"
            color = .blue
        case .experimental:
            text = "Expérimental"
            color = .orange
        case .unsupported:
            text = "Indisponible"
            color = .gray
        }

        return Text(text)
            .font(.caption2.weight(.bold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Capsule().fill(color.opacity(0.12)))
    }
}

@available(iOS 15.0, *)
private struct SarahEngineSettingsView: View {
    @ObservedObject var viewModel: ChatViewModel

    private let imageProfile = SarahGenerativeModelCatalog.imageProfile()
    private let videoProfile = SarahGenerativeModelCatalog.videoProfile()
    private let musicProfile = SarahGenerativeModelCatalog.musicProfile()
    private let vocalSongProfile = SarahGenerativeModelCatalog.vocalSongProfile()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    engineCard(
                        icon: "cpu.fill",
                        tint: .cyan,
                        title: "Moteur texte",
                        value: HardwareDetector.recommendModel(),
                        detail: String(
                            format: "%.1f Go de RAM détectés",
                            SarahGenerativeModelCatalog.physicalRAMGB
                        )
                    )

                    engineCard(
                        icon: "photo.fill",
                        tint: .purple,
                        title: "Génération d’images",
                        value: imageProfile.displayName,
                        detail: imageProfile.note
                    )

                    engineCard(
                        icon: "video.fill",
                        tint: .orange,
                        title: "Génération vidéo",
                        value: videoProfile.displayName,
                        detail: videoProfile.note
                    )

                    engineCard(
                        icon: "music.note.list",
                        tint: .pink,
                        title: "Musique locale",
                        value: musicProfile.displayName,
                        detail: musicProfile.note
                    )

                    engineCard(
                        icon: "music.mic",
                        tint: .cyan,
                        title: "Chanson avec paroles",
                        value: vocalSongProfile.displayName,
                        detail: vocalSongProfile.note
                    )

                    Button {
                        HapticService.shared.buttonTap()
                        viewModel.isShowingVoiceOrbModal = true
                    } label: {
                        HStack {
                            Image(systemName: "waveform.circle.fill")
                            Text("Tester le mode vocal")
                                .fontWeight(.semibold)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundColor(Color.white.opacity(0.36))
                        }
                        .foregroundColor(.white)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(0.085))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(18)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Sarah Engine")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
    }

    private func engineCard(
        icon: String,
        tint: Color,
        title: String,
        value: String,
        detail: String
    ) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(tint.opacity(0.14))
                )

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Color.white.opacity(0.48))

                Text(value)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(detail)
                    .font(.footnote)
                    .foregroundColor(Color.white.opacity(0.52))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.075))
        )
    }
}

@available(iOS 15.0, *)
private struct DataAndConversationsSettingsView: View {
    @ObservedObject var viewModel: ChatViewModel
    let onStartNewChat: () -> Void

    var body: some View {
        List {
            Section("Discussion actuelle") {
                Button(role: .destructive, action: onStartNewChat) {
                    Label("Réinitialiser la conversation", systemImage: "arrow.counterclockwise")
                }

                Text("Ouvre une nouvelle discussion vide. Les autres discussions restent accessibles depuis le menu principal.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section("Historique") {
                HStack {
                    Text("Discussions enregistrées")
                    Spacer()
                    Text("\(viewModel.conversations.count)")
                        .foregroundColor(.secondary)
                }
                Text("Vous pouvez sélectionner, archiver ou supprimer une discussion depuis le menu du chat.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section("Comportement de test") {
                Text("Après l’installation d’une nouvelle version, Sarah IA repart avec des données locales vierges. Après une fermeture complète, l’application ouvre aussi une nouvelle discussion vide. Une reprise après moins d’une heure conserve la discussion en cours.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Données et discussions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

@available(iOS 15.0, *)
private struct AboutSettingsView: View {
    private var appVersion: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(shortVersion) (\(build))"
    }

    var body: some View {
        List {
            Section("Sarah IA") {
                HStack {
                    Text("Moteur")
                    Spacer()
                    Text("Sarah Engine")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Version")
                    Spacer()
                    Text(appVersion)
                        .foregroundColor(.secondary)
                }
            }

            Section("Informations légales") {
                NavigationLink(destination: LegalNoticesView()) {
                    SettingsHomeRow(
                        icon: "doc.text.magnifyingglass",
                        tint: .sarahCyan,
                        title: "Licences et notices",
                        detail: "Composants et attributions distribués"
                    )
                }
            }

            Section("Voix") {
                Text("Sarah IA utilise les voix Apple disponibles sur cet iPhone. Pour bénéficier de la voix choisie, ouvrez Réglages iPhone > Siri > Voix, choisissez la variation voulue, puis laissez le téléchargement se terminer avant de revenir dans Sarah IA.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("À propos")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private func settingsDisplayName(for agent: AgentType) -> String {
    agent.displayName
}

private func settingsTestPhrase(for agent: AgentType) -> String {
    switch agent {
    case .sarah:
        return "Bonjour, je suis Sarah, votre agent pilote."
    case .nathan:
        return "Bonjour, je suis Nathan, spécialiste des réseaux et des automatisations."
    case .esther:
        return "Bonjour, je suis Raphaël, votre agent développeur."
    case .tom:
        return "Bonjour, je suis Tom, votre agent histoire et géopolitique."
    case .yohan:
        return "Shalom, je suis Yohan, votre agent de traduction."
    case .ethel:
        return "Bonjour, je suis Ethel, votre agent créatif."
    }
}

/// Notices affichées dans l'app pour les éléments effectivement distribués avec Sarah IA.
@available(iOS 15.0, *)
private struct LegalNoticesView: View {
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.07).ignoresSafeArea()

            List {
                Section("Sarah IA") {
                    Text("© 2026 Sarah IA. Tous droits réservés pour le code et l'identité visuelle de l'application, sauf indication contraire dans les notices ci-dessous.")
                        .font(.footnote)
                }

                Section("Assistances de développement") {
                    Text("Sarah IA a été conçue et développée avec l'assistance des outils suivants :")
                    VStack(alignment: .leading, spacing: 6) {
                        Text("• ChatGPT Web")
                        Text("• ChatGPT Cowork")
                        Text("• ChatGPT Business")
                        Text("• Google Gemini")
                        Text("• Google Antigravity")
                    }
                    .font(.footnote)
                    Text("Ces services ont assisté le processus de conception et de développement. Cette mention ne signifie ni partenariat, ni approbation, ni sponsoring de Sarah IA par leurs éditeurs.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Section("Sarah Engine — modèles locaux Qwen3") {
                    Text("Les variantes locales Qwen3 0.6B, 1.7B et 4B utilisées par Sarah Engine sont distribuées sous licence Apache License 2.0.")
                    Text("La licence Apache-2.0 autorise l'utilisation, la modification et la distribution commerciale, sous réserve de conserver la licence et les notices applicables.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Link("Lire la licence Apache-2.0", destination: URL(string: "https://www.apache.org/licenses/LICENSE-2.0")!)
                    Link("Notice officielle Qwen3", destination: URL(string: "https://huggingface.co/Qwen/Qwen3-4B-GGUF")!)
                }

                Section("Apple Shortcuts & App Intents") {
                    Text("Sarah IA expose ses propres actions directement dans l’app Raccourcis avec le framework public Apple App Intents. Ces actions sont enregistrées par iOS avec l’application ; elles ne nécessitent pas de fichier .shortcut externe à signer.")
                    Text("Actions Sarah publiées : Demander à Sarah, Nouveau chat Sarah et Créer un brouillon de raccourci.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Text("Référence technique consultée pendant le développement : generate-shortcuts-skill, qui documente 427 actions WF* et 728 App Intents (1 155 entrées annoncées). Son README indique MIT, mais le dépôt ne contient pas de fichier LICENSE séparé au moment de l’intégration. Sarah ne redistribue donc pas ces fichiers de référence verbatim et conserve une implémentation indépendante.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Text("Pour les raccourcis autonomes générés en plist, Apple ne fournit pas d’API publique iPhone permettant à une app tierce de signer silencieusement un .shortcut arbitraire. Sarah prépare le workflow et ouvre Raccourcis pour la finalisation. Les App Intents Sarah, eux, sont utilisables directement.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Link("Documentation Apple App Intents", destination: URL(string: "https://developer.apple.com/documentation/appintents")!)
                    Link("Référence generate-shortcuts-skill", destination: URL(string: "https://github.com/drewocarr/generate-shortcuts-skill")!)
                }

                Section("Génération d’images — cible locale") {
                    Text("Sarah prévoit d’utiliser Stable Diffusion 2.1 converti en Core ML, notamment les poids 6-bit palettisés publiés pour les appareils Apple.")
                    Text("Le code de conversion et d’inférence Apple ml-stable-diffusion est distribué sous licence MIT. Les poids Stable Diffusion restent soumis à leur licence OpenRAIL++ et à ses restrictions d’usage.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Link("Apple ml-stable-diffusion", destination: URL(string: "https://github.com/apple/ml-stable-diffusion")!)
                    Link("Poids Core ML Stable Diffusion 2.1", destination: URL(string: "https://huggingface.co/apple/coreml-stable-diffusion-2-1-base-palettized")!)
                }

                Section("Génération vidéo — profils locaux") {
                    Text("Sur les appareils de classe iPhone 14, Sarah étudie MobileI2V 0.27B comme moteur image-vers-vidéo. Le code du projet est publié sous Apache-2.0 ; le checkpoint est traité séparément dans les notices du modèle.")
                    Text("Sous iOS 27, Sarah sélectionne le profil vidéo selon la mémoire disponible. Sur les appareils plus puissants, MOVD reste une cible Core ML ; le dépôt MOVD est publié sous licence MIT et fournit une application iOS de référence.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Text("À ce stade, Sarah ne distribue pas encore les poids vidéo dans l’IPA. Avant une vente publique, les poids convertis, jeux de données, modèles amont et notices tierces devront être audités séparément de la licence du code.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Link("Projet MobileI2V", destination: URL(string: "https://github.com/hustvl/MobileI2V")!)
                    Link("Projet MOVD", destination: URL(string: "https://github.com/eai-lab/MOVD")!)
                    Link("Licence Apache-2.0", destination: URL(string: "https://www.apache.org/licenses/LICENSE-2.0")!)
                }

                Section("Génération musicale locale") {
                    Text("Sarah exécute Stable Audio Open Small avec Core ML directement sur l’iPhone. Les quatre modèles convertis (T5, durée, DiT INT8 et VAE) sont téléchargés à la demande afin de garder l’IPA légère.")
                    Text("Les poids Stable Audio Open Small restent soumis à la Stability AI Community License. Pour une distribution commerciale, Sarah doit continuer à respecter cette licence et toute condition applicable au modèle.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Link("Référence Core ML Stable Audio", destination: URL(string: "https://github.com/john-rocky/CoreML-Models/tree/main/sample_apps/StableAudioDemo")!)
                    Link("Licence Stability AI", destination: URL(string: "https://stability.ai/license")!)
                }

                Section("Chansons avec paroles — expérimental") {
                    Text("ACE-Step 1.5 est la cible retenue pour les chansons complètes avec paroles en français ou en anglais. Son dépôt est publié sous licence MIT.")
                    Text("Sarah IA ne distribue ni n’annonce actuellement ce moteur comme fonctionnel sur iPhone : l’intégration restera expérimentale jusqu’à validation d’un runtime iOS/Core AI réellement local.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Link("Projet ACE-Step 1.5", destination: URL(string: "https://github.com/ace-step/ACE-Step-1.5")!)
                }

                Section("Composants Apple") {
                    Text("Sarah IA utilise les frameworks système Apple, notamment SwiftUI, UIKit, Foundation, AVFoundation, Speech, Vision, WebKit et Core ML. Ces composants sont fournis avec iOS et soumis aux conditions Apple applicables.")
                        .font(.footnote)
                }

                Section("Information importante") {
                    Text("Cette page recense les composants distribués avec la version actuelle de Sarah IA. Toute bibliothèque, police, image, musique ou modèle ajouté avant publication doit être ajouté ici avec sa licence et ses notices.")
                        .font(.footnote)
                }
            }
            .hideScrollContentBackground()
        }
        .navigationTitle("Licences")
        .navigationBarTitleDisplayMode(.inline)
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
