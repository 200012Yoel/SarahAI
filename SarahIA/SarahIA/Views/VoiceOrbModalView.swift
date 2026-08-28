import SwiftUI

/// Modale Vocale Plein Écran de l'Orbe Multi-Agents (Voice Orb Modal)
/// Offre une expérience immersive style Siri / ChatGPT Advanced Voice avec :
/// - Sélecteur visuel rapide des 4 agents (Sarah, Tom, Raphaël, Yohan)
/// - Visualisation instantanée de la transcription en direct
/// - Animation fluide au volume du microphone
@available(iOS 14.0, *)
public struct VoiceOrbModalView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.presentationMode) var presentationMode
    
    public init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ZStack {
            // Fond Noir Profond
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // 1. Barre Supérieure : Bouton Fermer épuré
                HStack {
                    Button(action: {
                        HapticService.shared.buttonTap()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color.white.opacity(0.6))
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // 2. Nom et Rôle de l'Agent Actif
                VStack(spacing: 4) {
                    Text(viewModel.activeAgent.rawValue.uppercased())
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundColor(viewModel.activeAgent.themeColor)
                    
                    Text(viewModel.activeAgent.roleDescription)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.7))
                }
                .padding(.top, 10)
                
                Spacer()
                
                // 3. Orbe Central Réactif MultiAgentOrbView
                MultiAgentOrbView(
                    currentAgent: $viewModel.activeAgent,
                    audioLevel: CGFloat(viewModel.micInputLevel)
                )
                .frame(width: 280, height: 280)
                .onTapGesture {
                    viewModel.toggleMicrophone()
                }
                
                Spacer()
                
                // 4. Transcription en Direct / État Vocal
                VStack(spacing: 12) {
                    if !viewModel.liveTranscriptionText.isEmpty {
                        Text("« \(viewModel.liveTranscriptionText) »")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .transition(.opacity)
                    } else {
                        Text(viewModel.isMicRunning ? "Écoute en direct..." : "Touchez l'orbe ou parlez pour dialoguer")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.6))
                    }
                    
                    // Bouton Microphone de Commande
                    Button(action: {
                        viewModel.toggleMicrophone()
                    }) {
                        ZStack {
                            Circle()
                                .fill(viewModel.isMicRunning ? Color.red : viewModel.activeAgent.themeColor)
                                .frame(width: 64, height: 64)
                                .shadow(color: (viewModel.isMicRunning ? Color.red : viewModel.activeAgent.themeColor).opacity(0.5), radius: 12)
                            
                            Image(systemName: viewModel.isMicRunning ? "mic.fill" : "mic.slash.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            if !viewModel.isMicRunning {
                viewModel.toggleMicrophone()
            }
        }
    }
}
