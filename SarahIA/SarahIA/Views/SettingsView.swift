import SwiftUI

/// Vue Réglages épurée et optimisée de Sarah AI :
/// - Synthèse vocale et réglages des voix Sarah (Siri féminine) et Tom (Siri masculine)
/// - Contrôles de vitesse, tonalité et détection vocale VAD
/// - Actions de test direct des voix Sarah et Tom
/// - Réinitialisation de la conversation
@available(iOS 15.0, *)
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
                    // 1. Profil Vocal de Sarah (Assistant Principal)
                    Section(header: Text("Voix de Sarah (Féminine)").foregroundColor(.sarahCyan)) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Vitesse d'élocution")
                                Spacer()
                                Text(String(format: "%.2fx", speechRate * 2.0))
                                    .foregroundColor(.gray)
                            }
                            Slider(value: $speechRate, in: 0.35...0.65, step: 0.01)
                                .tint(.sarahCyan)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Tonalité de la voix")
                                Spacer()
                                Text(String(format: "%.2f", speechPitch))
                                    .foregroundColor(.gray)
                            }
                            Slider(value: $speechPitch, in: 0.8...1.3, step: 0.02)
                                .tint(.sarahCyan)
                        }
                        
                        Button(action: {
                            HapticService.shared.buttonTap()
                            TTSManager.shared.speakAsSarah("Bonjour ! Je suis Sarah, votre assistante vocale.")
                        }) {
                            HStack {
                                Image(systemName: "speaker.wave.2.fill")
                                Text("Tester la voix de Sarah")
                            }
                            .foregroundColor(.sarahCyan)
                        }
                    }
                    .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.16))
                    
                    // 2. Profil Vocal de Tom (Assistant Vision & Caméra)
                    Section(header: Text("Voix de Tom (Masculine / Vision)").foregroundColor(Color(red: 0.0, green: 0.78, blue: 1.0))) {
                        Text("Tom prend le relais dès que vous activez la caméra ou le partage d'écran pour analyser les objets en direct.")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        
                        Button(action: {
                            HapticService.shared.buttonTap()
                            TTSManager.shared.speakAsTom("Salut ! C'est Tom. Je suis prêt pour l'analyse visuelle et la caméra.")
                        }) {
                            HStack {
                                Image(systemName: "eye.circle.fill")
                                Text("Tester la voix de Tom")
                            }
                            .foregroundColor(Color(red: 0.0, green: 0.78, blue: 1.0))
                        }
                    }
                    .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.16))
                    
                    // 3. Microphone & Détection Vocale Full-Duplex
                    Section(header: Text("Microphone & Détection Vocale").foregroundColor(.sarahCyan)) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Sensibilité VAD Full-Duplex")
                                Spacer()
                                Text("\(Int(vadSensitivity * 100))%")
                                    .foregroundColor(.gray)
                            }
                            Slider(value: $vadSensitivity, in: 0.3...0.9, step: 0.05)
                                .tint(.sarahCyan)
                        }
                    }
                    .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.16))
                    
                    // 4. Historique & Réinitialisation
                    Section(header: Text("Historique de Discussion").foregroundColor(.sarahCyan)) {
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
                    .foregroundColor(.sarahCyan)
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
