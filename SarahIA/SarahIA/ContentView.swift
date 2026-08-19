import SwiftUI

/// Vue racine de l'application Sarah AI reproduisant l'architecture native avec tiroir latéral 3D (Sidebar Drawer).
public struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var isShowingSettings: Bool = false
    @State private var isShowingMemoryVault: Bool = false
    @GestureState private var dragOffset: CGFloat = 0.0
    
    public init() {}
    
    public var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let drawerWidth = screenWidth * 0.78
            
            ZStack(alignment: .leading) {
                // Fond noir absolu
                Color.black.ignoresSafeArea()
                
                // 1. TIROIR LATÉRAL (SIDEBAR)
                SidebarView(viewModel: viewModel, isShowingSettings: $isShowingSettings)
                    .frame(width: drawerWidth)
                    .offset(x: 0)
                    .opacity(0.35 + Double(viewModel.drawerProgress) * 0.65)
                
                // 2. CONTENEUR PRINCIPAL DE L'APPLICATION (APP)
                ZStack {
                    // Contenu selon le mode actif (Avatar 3D ou Chat)
                    if viewModel.appMode == .avatar {
                        avatarScreen
                            .transition(.opacity)
                    } else {
                        ChatScreenView(viewModel: viewModel)
                            .transition(.opacity)
                    }
                    
                    // Scrim assombrissant quand le tiroir est ouvert
                    if viewModel.drawerProgress > 0.01 {
                        Color.black
                            .opacity(Double(viewModel.drawerProgress) * 0.35)
                            .ignoresSafeArea()
                            .onTapGesture {
                                viewModel.closeDrawer()
                            }
                    }
                }
                .frame(width: screenWidth, height: geometry.size.height)
                .background(Color.black)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: viewModel.drawerProgress > 0.01 ? 44 : 0,
                        style: .continuous
                    )
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: viewModel.drawerProgress > 0.01 ? 44 : 0,
                        style: .continuous
                    )
                    .stroke(Color.white.opacity(Double(viewModel.drawerProgress) * 0.14), lineWidth: 0.5)
                )
                .shadow(
                    color: Color.black.opacity(Double(viewModel.drawerProgress) * 0.6),
                    radius: 30,
                    x: -20,
                    y: 0
                )
                .scaleEffect(1.0 - (viewModel.drawerProgress * 0.08), anchor: .leading)
                .offset(x: viewModel.drawerProgress * drawerWidth)
                // Geste de glissement pour ouvrir/fermer le tiroir
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let translation = value.translation.width
                            if viewModel.isDrawerOpen {
                                let newProgress = max(0.0, min(1.0, 1.0 + (translation / drawerWidth)))
                                viewModel.drawerProgress = newProgress
                            } else if value.startLocation.x < 45 {
                                let newProgress = max(0.0, min(1.0, translation / drawerWidth))
                                viewModel.drawerProgress = newProgress
                            }
                        }
                        .onEnded { value in
                            let translation = value.translation.width
                            let velocity = value.predictedEndTranslation.width
                            if viewModel.isDrawerOpen {
                                if translation < -drawerWidth * 0.3 || velocity < -200 {
                                    viewModel.closeDrawer()
                                } else {
                                    viewModel.openDrawer()
                                }
                            } else {
                                if translation > drawerWidth * 0.3 || velocity > 200 {
                                    viewModel.openDrawer()
                                } else {
                                    viewModel.closeDrawer()
                                }
                            }
                        }
                )
            }
        }
        .statusBarHidden(viewModel.appMode == .avatar && !viewModel.isDrawerOpen)
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(viewModel: viewModel)
        }
        .sheet(isPresented: $isShowingMemoryVault) {
            MemoryVaultView(viewModel: viewModel)
        }
    }
    
    // MARK: - Écran Avatar Plein Écran
    
    private var avatarScreen: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Rendu 3D VRM
            Avatar3DView(isSpeaking: viewModel.voiceStatus == .speaking || SpeechManager.shared.isSpeaking)
                .ignoresSafeArea()
            
            VStack {
                // Top bar de l'écran Avatar
                HStack {
                    // Bouton Menu latéral (Tiroir)
                    Button(action: {
                        viewModel.openDrawer()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.11, green: 0.11, blue: 0.12))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    
                    Spacer()
                    
                    // Bouton Présentation
                    Button(action: {
                        viewModel.introduceSarah()
                    }) {
                        HStack(spacing: 4) {
                            Text("✨")
                            Text("Présentation")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.cyan)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .overlay(Capsule().stroke(Color.cyan.opacity(0.35), lineWidth: 1))
                        )
                    }
                    
                    // Bouton Bascule vers le mode Chat Texte
                    Button(action: {
                        viewModel.switchToChat()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.11, green: 0.11, blue: 0.12))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 17))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                
                Spacer()
                
                // Contrôles vocaux et ondelettes
                liveVoiceAvatarControls
                    .padding(.bottom, 36)
            }
        }
    }
    
    /// Contrôles vocaux interactifs de l'Avatar
    private var liveVoiceAvatarControls: some View {
        VStack(spacing: 12) {
            // Bouton Micro Tactile
            Button(action: {
                viewModel.toggleMicrophone()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isMicRunning ? "mic.fill" : "mic.slash")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(viewModel.isMicRunning ? .cyan : .white.opacity(0.6))
                    
                    Text(viewModel.isMicRunning ? "Écoute Active • Touchez pour couper" : "Micro en veille • Touchez pour parler")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(viewModel.isMicRunning ? Color.cyan.opacity(0.22) : Color.white.opacity(0.12))
                        .overlay(
                            Capsule().stroke(viewModel.isMicRunning ? Color.cyan.opacity(0.6) : Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .shadow(color: viewModel.isMicRunning ? Color.cyan.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 0)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Ondelettes audio harmoniques
            HStack(spacing: 4) {
                ForEach(0..<16) { index in
                    let height = voiceWaveHeight(for: index)
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.20, green: 0.65, blue: 1.0),
                                    Color(red: 0.75, green: 0.35, blue: 0.95)
                                ]),
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 3.5, height: height)
                }
            }
            .frame(height: 36)
            .animation(.spring(response: 0.15, dampingFraction: 0.5), value: viewModel.micInputLevel)
            
            // Transcription en direct
            if !viewModel.liveTranscriptionText.isEmpty {
                Text(viewModel.liveTranscriptionText)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.7))
                            .overlay(Capsule().stroke(Color.cyan.opacity(0.3), lineWidth: 1))
                    )
            }
        }
    }
    
    private func voiceWaveHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 5.0
        let multiplier = CGFloat(viewModel.micInputLevel) * 40.0
        let harmonic = sin(Double(index) * 0.5 + Double(viewModel.micInputLevel * 5.0)) * Double(multiplier)
        return max(baseHeight, min(36.0, baseHeight + CGFloat(abs(harmonic))))
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .preferredColorScheme(.dark)
    }
}
