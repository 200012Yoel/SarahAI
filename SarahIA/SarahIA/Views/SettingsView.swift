import SwiftUI

/// Vue feuille des paramètres vocaux et personnalisation de Sarah AI
@available(iOS 14.0, *)
public struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: ChatViewModel
    
    @State private var speechRate: Double = 0.50
    @State private var speechPitch: Double = 1.02
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
                    Section(header: Text("Voix Locale de Sarah").foregroundColor(.cyan)) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Vitesse d'élocution")
                                Spacer()
                                Text(String(format: "%.2fx", speechRate * 2.0))
                                    .foregroundColor(.gray)
                            }
                            Slider(value: $speechRate, in: 0.35...0.65, step: 0.01)
                                .tint(.cyan)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Tonalité de la voix")
                                Spacer()
                                Text(String(format: "%.2f", speechPitch))
                                    .foregroundColor(.gray)
                            }
                            Slider(value: $speechPitch, in: 0.8...1.3, step: 0.02)
                                .tint(.cyan)
                        }
                        
                        Button(action: {
                            HapticService.shared.buttonTap()
                            viewModel.testVoiceSettings(rate: Float(speechRate), pitch: Float(speechPitch))
                        }) {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                Text("Tester la voix")
                            }
                            .foregroundColor(.cyan)
                        }
                    }
                    .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.16))
                    
                    Section(header: Text("Microphone & VAD Full-Duplex").foregroundColor(.cyan)) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Sensibilité de détection vocale")
                                Spacer()
                                Text("\(Int(vadSensitivity * 100))%")
                                    .foregroundColor(.gray)
                            }
                            Slider(value: $vadSensitivity, in: 0.3...0.9, step: 0.05)
                                .tint(.cyan)
                        }
                    }
                    .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.16))
                    
                    Section(header: Text("Widgets Sarah IA (iOS 15 & 16+)").foregroundColor(.cyan)) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Aperçu du Widget Statistiques & Graphique :")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                            
                            // Prévisualisation du Widget Largeur Moyenne
                            SarahUsageStatsWidgetView(
                                entry: SarahWidgetEntry(
                                    date: Date(),
                                    stats: WidgetStatsData(
                                        totalConversations: max(1, viewModel.conversations.count),
                                        totalMessages: max(4, viewModel.messages.count),
                                        activeMinutesToday: 32,
                                        usagePercentage: 84,
                                        weeklyActivity: [3, 7, 5, 12, 8, 15, 18],
                                        learnedMemoriesCount: viewModel.learnedMemories.count
                                    )
                                )
                            )
                            .frame(height: 120)
                            .padding(12)
                            .background(Color(red: 0.08, green: 0.08, blue: 0.10))
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            
                            Text("💡 Pour l'ajouter à votre écran d'accueil : maintenez votre doigt sur l'écran d'accueil de l'iPhone, appuyez sur « + » en haut à gauche et choisissez « Sarah IA ».")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                                .lineSpacing(3)
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.16))
                    
                    Section(header: Text("Historique & Réinitialisation").foregroundColor(.cyan)) {
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
                    .foregroundColor(.cyan)
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
}

// MARK: - Compatibility Extension
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
