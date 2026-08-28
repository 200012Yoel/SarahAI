import SwiftUI

/// Vue Racine 100% Native SwiftUI avec interface de chat principale et tiroir latéral fluide.
/// Fix : suppression du scaleEffect qui causait l'effet de déformation bizarre au scroll du menu.
/// Le drawer fonctionne maintenant comme ChatGPT / Gemini : slide propre sans zoom.
@available(iOS 15.0, *)
public struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var isShowingSettings: Bool = false
    
    public init() {}
    
    public var body: some View {
        GeometryReader { geo in
            // Menu calibré à 78% de la largeur de l'écran
            let sidebarWidth = geo.size.width * 0.78
            
            ZStack(alignment: .leading) {
                // 1. CALQUE DU FOND : Menu Latéral (Sidebar) — fixe à gauche
                SidebarView(
                    viewModel: viewModel,
                    isShowingSettings: $isShowingSettings
                )
                .frame(width: sidebarWidth)
                .offset(x: viewModel.drawerProgress < 0.01 ? -sidebarWidth : 0)
                .animation(.spring(response: 0.32, dampingFraction: 0.85), value: viewModel.drawerProgress)
                
                // 2. CALQUE DU PREMIER PLAN : Interface de Chat Principale
                ZStack {
                    ChatScreenView(viewModel: viewModel, isShowingSettings: $isShowingSettings)
                        .disabled(viewModel.isDrawerOpen)
                    
                    // Voile d'obscurcissement au-dessus de l'application
                    if viewModel.drawerProgress > 0 {
                        Color.black
                            .opacity(Double(viewModel.drawerProgress) * 0.50)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                                    viewModel.closeDrawer()
                                }
                            }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .background(Color.black)
                .offset(x: viewModel.drawerProgress * sidebarWidth)
                .shadow(
                    color: Color.black.opacity(Double(viewModel.drawerProgress) * 0.55),
                    radius: 24,
                    x: -10,
                    y: 0
                )
                // Geste de glissement haute priorité pour ouvrir (gauche -> droite) et fermer
                .highPriorityGesture(
                    DragGesture(minimumDistance: 15)
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
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                                if !viewModel.isDrawerOpen && value.startLocation.x < 50 && value.translation.width > 50 {
                                    viewModel.openDrawer()
                                } else if viewModel.isDrawerOpen && value.translation.width < -50 {
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
            }
        }
    }
}
