import SwiftUI

/// Vue Racine 100% Native SwiftUI avec interface de chat principale et tiroir latéral fluide (#app scale 0.92, corner radius 44pt).
@available(iOS 15.0, *)
public struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var isShowingSettings: Bool = false
    
    public init() {}
    
    public var body: some View {
        GeometryReader { geo in
            // Menu calibré à 78% de la largeur de l'écran style ChatGPT / Gemini
            let sidebarWidth = geo.size.width * 0.78
            
            ZStack(alignment: .leading) {
                // 1. CALQUE DU FOND : Menu Latéral (Sidebar)
                SidebarView(
                    viewModel: viewModel,
                    isShowingSettings: $isShowingSettings
                )
                .frame(width: sidebarWidth)
                .opacity(Double(viewModel.drawerProgress))
                .allowsHitTesting(viewModel.drawerProgress > 0.05)
                
                // 2. CALQUE DU PREMIER PLAN : Interface de Chat Principale (ChatScreenView)
                ZStack {
                    ChatScreenView(viewModel: viewModel)
                        .disabled(viewModel.isDrawerOpen) // Empêche de taper dans le tchat si le menu est ouvert
                    
                    // Voile d'obscurcissement (#scrim) au-dessus de l'application
                    if viewModel.drawerProgress > 0 {
                        Color.black
                            .opacity(Double(viewModel.drawerProgress) * 0.45)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    viewModel.closeDrawer()
                                }
                            }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .background(Color.black)
                .scaleEffect(1.0 - (viewModel.drawerProgress * 0.08), anchor: .leading)
                .offset(x: viewModel.drawerProgress * sidebarWidth)
                .shadow(
                    color: Color.black.opacity(Double(viewModel.drawerProgress) * 0.6),
                    radius: 30,
                    x: -12,
                    y: 0
                )
                // Geste de glissement haute priorité pour ouvrir (gauche -> droite) et fermer
                .highPriorityGesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            if !viewModel.isDrawerOpen && value.startLocation.x < 50 {
                                if value.translation.width > 0 {
                                    let progress = min(value.translation.width / sidebarWidth, 1.0)
                                    viewModel.drawerProgress = CGFloat(progress)
                                }
                            } else if viewModel.isDrawerOpen {
                                if value.translation.width < 0 {
                                    let progress = max(0.0, 1.0 + (value.translation.width / sidebarWidth))
                                    viewModel.drawerProgress = CGFloat(progress)
                                }
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                if !viewModel.isDrawerOpen && value.startLocation.x < 50 && value.translation.width > 60 {
                                    viewModel.openDrawer()
                                } else if viewModel.isDrawerOpen && value.translation.width < -60 {
                                    viewModel.closeDrawer()
                                } else if viewModel.isDrawerOpen {
                                    viewModel.openDrawer()
                                } else {
                                    viewModel.closeDrawer()
                                }
                            }
                        }
                )
            }
            .ignoresSafeArea()
        }
        // Feuille de Paramètres Native (#sheet)
        .sheet(isPresented: $isShowingSettings) {
            if #available(iOS 15.0, *) {
                SettingsView(viewModel: viewModel)
            } else {
                settingsSheetView
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

