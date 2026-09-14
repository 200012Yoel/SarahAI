import SwiftUI

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
    
    public var body: some View {
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
