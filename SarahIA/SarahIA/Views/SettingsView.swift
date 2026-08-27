import SwiftUI

/// Vue Réglages épurée et optimisée de Sarah AI Multi-Agents :
/// - Liste sobre et statut des 4 agents autonomes :
///   1. Sarah (Agent Pilote & Patronne) - Voix système principale
///   2. Tom (Conversation, Histoire & Débats) - Voix conversationnelle
///   3. Raphaël (Code & Shortcuts) - Voix de notification/build
///   4. Yohan (Traducteur FR ⇄ HE) - Voix de restitution polyglotte
/// - Contrôles de vitesse, tonalité et détection vocale VAD
/// - Actions de test direct des voix Siri locales
/// - Réinitialisation de la conversation
@available(iOS 15.0, *)
public struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: ChatViewModel
    
    @State private var speechRate: Double = 0.52
    @State private var speechPitch: Double = 1.05
    @State private var vadSensitivity: Double = 0.65
    
    public init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.07)
                    .ignoresSafeArea()
                
                Form {
                    // 1. Les 4 Agents Autonomes & Voix Siri Locales
                    Section(header: Text("Écosystème des 4 Agents Autonomes").foregroundColor(.white)) {
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
                    }
                    .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.16))
                    
                    // 2. Microphone & Détection Vocale Full-Duplex
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
                    
                    // 3. Moteur IA Adaptatif Embarqué & Ressources
                    Section(header: Text("Moteur d'Intelligence Artificielle Locale").foregroundColor(Color(red: 0.15, green: 0.72, blue: 1.0))) {
                        let profile = AIResourceManager.shared.activeProfile
                        let capability = DeviceCapabilityDetector.shared.detectProfile()
                        
                        HStack {
                            Text("Statut du Moteur")
                            Spacer()
                            Text("Actif & Intégré (100% Local)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.green)
                        }
                        
                        HStack {
                            Text("Profil Matériel Détecté")
                            Spacer()
                            Text("\(capability.hardwareTier.tierName)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(red: 0.15, green: 0.72, blue: 1.0))
                        }
                        
                        HStack {
                            Text("Modèle Embarqué")
                            Spacer()
                            Text(profile?.internalEngineId ?? "Sarah Adaptive Core")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }
                        
                        HStack {
                            Text("Mémoire Allouée Sécurisée")
                            Spacer()
                            Text("\(capability.safeMemoryBudgetBytes / (1024 * 1024)) Mo")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
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
            .navigationTitle("⚙️ Réglages Multi-Agents")
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
