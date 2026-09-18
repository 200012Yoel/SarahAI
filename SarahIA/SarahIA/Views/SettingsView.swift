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

    /// Accueil volontairement proche des réglages iOS : les réglages détaillés
    /// vivent dans des destinations séparées plutôt que dans une longue page.
    public var body: some View {
        NavigationView {
            List {
                Section {
                    engineHeader
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

                Section("Réglages") {
                    NavigationLink(destination: AgentsSettingsView(viewModel: viewModel)) {
                        SettingsHomeRow(
                            icon: "person.2.fill",
                            tint: .sarahIndigo,
                            title: "Agents",
                            detail: "Les assistants et leurs rôles"
                        )
                    }

                    NavigationLink(destination: ConnectionsSettingsView()) {
                        SettingsHomeRow(
                            icon: "link",
                            tint: .sarahCyan,
                            title: "Connexions",
                            detail: "Services disponibles et leur état"
                        )
                    }

                    NavigationLink(
                        destination: VoiceAndSpeechSettingsView(
                            viewModel: viewModel,
                            speechRate: $speechRate,
                            speechPitch: $speechPitch,
                            vadSensitivity: $vadSensitivity
                        )
                    ) {
                        SettingsHomeRow(
                            icon: "waveform",
                            tint: .purple,
                            title: "Voix et parole",
                            detail: "Voix, vitesse et microphone"
                        )
                    }

                    NavigationLink(destination: SarahEngineActivationSettingsView(viewModel: viewModel)) {
                        SettingsHomeRow(
                            icon: "sparkles",
                            tint: .pink,
                            title: "Sarah Engine",
                            detail: "Halo, activation et mode vocal"
                        )
                    }

                    NavigationLink(
                        destination: DataAndConversationsSettingsView(
                            viewModel: viewModel,
                            onStartNewChat: startNewChatAndDismiss
                        )
                    ) {
                        SettingsHomeRow(
                            icon: "bubble.left.and.bubble.right.fill",
                            tint: .orange,
                            title: "Données et discussions",
                            detail: "Historique et nouvelle conversation"
                        )
                    }

                    NavigationLink(destination: AboutSettingsView()) {
                        SettingsHomeRow(
                            icon: "info.circle.fill",
                            tint: .secondary,
                            title: "À propos",
                            detail: "Sarah Engine, version, licences et notices"
                        )
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Terminé") {
                        saveVoiceSettingsAndDismiss()
                    }
                }
            }
        }
        .onAppear(perform: loadVoiceSettings)
    }

    private var engineHeader: some View {
        HStack(spacing: 14) {
            Image(systemName: "cpu.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.sarahCyan)
                .frame(width: 42, height: 42)
                .background(Color.sarahCyan.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("Sarah IA tourne sur Sarah Engine.")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("Configurez les agents, les connexions et vos discussions.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
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
private struct SarahEngineActivationSettingsView: View {
    @ObservedObject var viewModel: ChatViewModel
    @AppStorage("sarahEngineHaloEnabled") private var haloEnabled: Bool = true
    @State private var copied: Bool = false

    var body: some View {
        List {
            Section("Apparence") {
                Toggle(isOn: $haloEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Halo Sarah Engine", systemImage: "sparkles")
                        Text("Affiche un contour multicolore autour de l'écran et de l'encoche pendant le mode vocal.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.pink)

                Button {
                    HapticService.shared.buttonTap()
                    viewModel.isShowingVoiceOrbModal = true
                } label: {
                    Label("Tester le mode vocal", systemImage: "waveform.circle.fill")
                }
            }

            Section("Activation rapide") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sarah Intelligence")
                        Text("Raccourci système intégré")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "waveform.circle.fill")
                        .foregroundColor(.pink)
                }

                Text("Sarah expose maintenant une action système appelée « Sarah Intelligence ». Elle ouvre directement le mode vocal et le halo multicolore.")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Lien de secours")
                        Text("sarahia://voice")
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(copied ? "Copié" : "Copier") {
                        UIPasteboard.general.string = "sarahia://voice"
                        copied = true
                        HapticService.shared.buttonTap()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            copied = false
                        }
                    }
                }
            }

            Section("Accessibilité") {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Triple toucher au dos")
                        .font(.headline)
                    Text("Dans l'app Raccourcis, crée si nécessaire un raccourci d'une seule action « Sarah Intelligence ». Puis va dans Réglages iPhone > Accessibilité > Toucher > Toucher le dos de l'appareil > Toucher 3 fois, et choisis ce raccourci.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)

                Text("Le triple-clic du bouton latéral reste réservé par iOS aux fonctions du Raccourci Accessibilité, comme VoiceOver ou Zoom. Une app tierce ne peut pas s'ajouter à cette liste. Le triple toucher au dos est donc l'équivalent le plus proche et peut lancer Sarah directement.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Sarah Engine")
        .navigationBarTitleDisplayMode(.inline)
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
