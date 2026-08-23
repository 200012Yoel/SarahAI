import SwiftUI

/// Vue feuille des paramètres vocaux et personnalisation de Sarah AI
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
                    Section(header: Text("Voix Locale de Sarah").foregroundColor(.sarahCyan)) {
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
                            viewModel.testVoiceSettings(rate: Float(speechRate), pitch: Float(speechPitch))
                        }) {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                Text("Tester la voix")
                            }
                            .foregroundColor(.sarahCyan)
                        }
                    }
                    .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.16))
                    
                    Section(header: Text("Microphone & VAD Full-Duplex").foregroundColor(.sarahCyan)) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Sensibilité de détection vocale")
                                Spacer()
                                Text("\(Int(vadSensitivity * 100))%")
                                    .foregroundColor(.gray)
                            }
                            Slider(value: $vadSensitivity, in: 0.3...0.9, step: 0.05)
                                .tint(.sarahCyan)
                        }
                    }
                    .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.16))
                    
                    Section(header: Text("Widgets Sarah IA (iPhone 5S à 16)").foregroundColor(.sarahCyan)) {
                        VStack(alignment: .leading, spacing: 12) {
                            NavigationLink(destination: WidgetsGalleryView(viewModel: viewModel)) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.sarahCyan.opacity(0.2))
                                            .frame(width: 32, height: 32)
                                        Image(systemName: "square.grid.2x2.fill")
                                            .foregroundColor(.sarahCyan)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Galerie des 8 Widgets")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(.white)
                                        Text("Voir et tester tous les 8 widgets actifs")
                                            .font(.system(size: 11))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Divider().background(Color.white.opacity(0.1))
                            
                            // Prévisualisation du Widget Largeur Moyenne
                            SarahUsageStatsWidgetView(
                                entry: SarahWidgetEntry(
                                    date: Date(),
                                    stats: SarahWidgetBridge.shared.getStats()
                                )
                            )
                            .frame(height: 120)
                            .padding(12)
                            .background(Color(red: 0.08, green: 0.08, blue: 0.10))
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            
                            Text("💡 Les 8 widgets sont actifs en temps réel. Maintenez l'écran d'accueil appuyé et appuyez sur « + » pour les ajouter.")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                                .lineSpacing(3)
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.16))
                    
                    Section(header: Text("Transfert & Synchronisation (P2P Local)").foregroundColor(.sarahCyan)) {
                        NavigationLink(destination: LocalSyncQRView(viewModel: viewModel)) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(red: 0.04, green: 0.52, blue: 1.0).opacity(0.2))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "qrcode.viewfinder")
                                        .foregroundColor(Color(red: 0.04, green: 0.52, blue: 1.0))
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Synchronisation QR Code")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("Transférer toutes les discussions vers un autre iPhone")
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .listRowBackground(Color(red: 0.12, green: 0.12, blue: 0.16))
                    
                    Section(header: Text("Historique & Réinitialisation").foregroundColor(.sarahCyan)) {
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
