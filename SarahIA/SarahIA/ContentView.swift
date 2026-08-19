import SwiftUI

/// Vue Racine Pixel-Perfect 100% Native SwiftUI intégrant la physique du tiroir 3D (#app scale 0.92, corner radius 44pt).
public struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var isShowingSettings: Bool = false
    
    public init() {}
    
    public var body: some View {
        GeometryReader { geo in
            let sidebarWidth = geo.size.width * 0.78
            
            ZStack(alignment: .leading) {
                // 1. CALQUE DU FOND : Menu Latéral (Sidebar)
                SidebarView(
                    viewModel: viewModel,
                    isShowingSettings: $isShowingSettings
                )
                .frame(width: sidebarWidth)
                .opacity(0.35 + Double(viewModel.drawerProgress) * 0.65)
                
                // 2. CALQUE DU PREMIER PLAN : Application Principale (#app)
                ZStack {
                    // Contenu selon le mode : Avatar 3D ou Chat
                    if viewModel.appMode == .avatar {
                        avatarScreen
                    } else {
                        ChatScreenView(viewModel: viewModel)
                    }
                    
                    // Voile d'obscurcissement (#scrim) au-dessus de l'application
                    if viewModel.drawerProgress > 0 {
                        Color.black
                            .opacity(Double(viewModel.drawerProgress) * 0.35)
                            .ignoresSafeArea()
                            .onTapGesture {
                                viewModel.closeDrawer()
                            }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .background(Color.black)
                // Transformation 3D exacte de la maquette : translateX(78vw) scale(0.92) et border-radius 44pt
                .cornerRadius(viewModel.drawerProgress > 0.01 ? 44 : 0)
                .scaleEffect(1.0 - (viewModel.drawerProgress * 0.08), anchor: .leading)
                .offset(x: viewModel.drawerProgress * sidebarWidth)
                .shadow(
                    color: Color.black.opacity(Double(viewModel.drawerProgress) * 0.6),
                    radius: 30,
                    x: -12,
                    y: 0
                )
                .overlay(
                    RoundedRectangle(cornerRadius: viewModel.drawerProgress > 0.01 ? 44 : 0)
                        .stroke(Color.white.opacity(Double(viewModel.drawerProgress) * 0.14), lineWidth: 0.5)
                )
                // Geste de glissement pour ouvrir/fermer le tiroir
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let translation = value.translation.width
                            if viewModel.isDrawerOpen {
                                let newP = max(0.0, min(1.0, 1.0 + (translation / sidebarWidth)))
                                viewModel.drawerProgress = CGFloat(newP)
                            } else if value.startLocation.x < 44 {
                                let newP = max(0.0, min(1.0, translation / sidebarWidth))
                                viewModel.drawerProgress = CGFloat(newP)
                            }
                        }
                        .onEnded { value in
                            let translation = value.translation.width
                            let velocity = value.predictedEndTranslation.width - translation
                            
                            if velocity > 80 || viewModel.drawerProgress > 0.45 {
                                viewModel.openDrawer()
                            } else {
                                viewModel.closeDrawer()
                            }
                        }
                )
            }
            .ignoresSafeArea()
        }
        // Feuille de Paramètres Native (#sheet)
        .sheet(isPresented: $isShowingSettings) {
            settingsSheetView
        }
    }
    
    // MARK: - Écran Avatar 3D (#avatar)
    
    private var avatarScreen: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Rendu de l'Avatar 3D
            Avatar3DView(isSpeaking: viewModel.voiceStatus == .speaking || SpeechManager.shared.isSpeaking)
                .ignoresSafeArea()
            
            VStack {
                // Top bar de l'écran Avatar
                HStack {
                    // Bouton Menu latéral (#btnMenu2)
                    Button(action: {
                        HapticService.shared.buttonTap()
                        viewModel.openDrawer()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.11, green: 0.11, blue: 0.12)) // #1c1c1e
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(ScaleBounceButtonStyle())
                    
                    Spacer()
                    
                    // Bouton Bascule vers le Chat
                    Button(action: {
                        HapticService.shared.buttonTap()
                        viewModel.switchToChat()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.11, green: 0.11, blue: 0.12)) // #1c1c1e
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 18, weight: .regular))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(ScaleBounceButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.top, 50)
                
                Spacer()
                
                // Dock vocal / Contrôle Micro
                HStack(spacing: 16) {
                    Button(action: {
                        viewModel.toggleMicrophone()
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: viewModel.isMicRunning ? "waveform.circle.fill" : "mic.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(viewModel.isMicRunning ? .cyan : .white)
                            
                            Text(viewModel.isMicRunning ? "Sarah vous écoute..." : "Appuyer pour parler")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.11, green: 0.11, blue: 0.12).opacity(0.85))
                        .cornerRadius(28)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(viewModel.isMicRunning ? Color.cyan.opacity(0.6) : Color.white.opacity(0.15), lineWidth: 1)
                        )
                    }
                    .buttonStyle(ScaleBounceButtonStyle())
                }
                .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Feuille de Paramètres Native (#sheet)
    
    private var settingsSheetView: some View {
        ZStack {
            Color(red: 0.11, green: 0.11, blue: 0.12).ignoresSafeArea() // #1c1c1e
            
            VStack(spacing: 0) {
                // Poignée de glissement (.grab)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(red: 0.28, green: 0.28, blue: 0.29)) // #48484a
                    .frame(width: 38, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                
                Text("Paramètres")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.bottom, 16)
                
                ScrollView {
                    VStack(spacing: 0) {
                        sheetRow(title: "Compte", icon: "person.crop.circle")
                        sheetRow(title: "Personnalisation", icon: "slider.horizontal.3")
                        sheetRow(title: "Notifications", icon: "bell")
                        sheetRow(title: "Discussions archivées", icon: "archivebox")
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.vertical, 10)
                        
                        // Cerveau & Souvenirs
                        NavigationLink(destination: MemoryVaultView(viewModel: viewModel)) {
                            HStack(spacing: 16) {
                                Image(systemName: "brain.head.profile")
                                    .font(.system(size: 20))
                                    .foregroundColor(.purple)
                                    .frame(width: 22, height: 22)
                                
                                Text("Mémoire & Souvenirs de Sarah")
                                    .font(.system(size: 17))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Text("\(viewModel.learnedMemories.count)")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.gray)
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 15)
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    @ViewBuilder
    private func sheetRow(title: String, icon: String) -> some View {
        Button(action: {
            HapticService.shared.buttonTap()
        }) {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.58))
                        .frame(width: 22, height: 22)
                    
                    Text(title)
                        .font(.system(size: 17))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(Color(red: 0.35, green: 0.35, blue: 0.38))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
                
                Divider()
                    .background(Color.white.opacity(0.10))
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
