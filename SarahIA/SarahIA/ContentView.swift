import SwiftUI

/// Vue Racine 100% Native SwiftUI avec interface de chat principale et tiroir latéral fluide.
/// - L'écran de chat reste plein écran sous le tiroir sans être déformé ni découpé.
/// - Le menu latéral (Sidebar) glisse en superposition fluide depuis la gauche avec un voile sombre.
/// - Geste de glissement haute priorité (gauche -> droite) pour ouvrir le menu des discussions.
@available(iOS 15.0, *)
public struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var isShowingSettings: Bool = false
    
    public init() {}
    
    public var body: some View {
        GeometryReader { geo in
            let sidebarWidth = min(geo.size.width * 0.82, 330)
            
            ZStack(alignment: .leading) {
                // 1. ÉCRAN PRINCIPAL : Chat Screen (Plein écran stable)
                ChatScreenView(viewModel: viewModel, isShowingSettings: $isShowingSettings)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .disabled(viewModel.isDrawerOpen)
                
                // 2. VOILE D'OBSCURCISSEMENT au-dessus du chat lors de l'ouverture du tiroir
                if viewModel.drawerProgress > 0.001 {
                    Color.black
                        .opacity(Double(viewModel.drawerProgress) * 0.60)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                                viewModel.closeDrawer()
                            }
                        }
                }
                
                // 3. MENU LATÉRAL (Sidebar) : Glisse en superposition depuis la gauche
                SidebarView(
                    viewModel: viewModel,
                    isShowingSettings: $isShowingSettings
                )
                .frame(width: sidebarWidth, height: geo.size.height)
                .offset(x: (viewModel.drawerProgress - 1.0) * sidebarWidth)
                .shadow(
                    color: Color.black.opacity(viewModel.drawerProgress > 0.01 ? 0.65 : 0.0),
                    radius: 20,
                    x: 6,
                    y: 0
                )
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .ignoresSafeArea()
            // Geste universel de glissement pour ouvrir (gauche -> droite) et fermer (droite -> gauche)
            .highPriorityGesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        let horizontal = value.translation.width
                        let vertical = value.translation.height
                        
                        if !viewModel.isDrawerOpen {
                            // Glissement de la gauche vers la droite pour ouvrir
                            if horizontal > 0 && abs(horizontal) > abs(vertical) * 0.6 {
                                let progress = min(horizontal / sidebarWidth, 1.0)
                                viewModel.drawerProgress = CGFloat(progress)
                            }
                        } else {
                            // Glissement vers la gauche pour refermer
                            if horizontal < 0 {
                                let progress = max(0.0, 1.0 + (horizontal / sidebarWidth))
                                viewModel.drawerProgress = CGFloat(progress)
                            }
                        }
                    }
                    .onEnded { value in
                        let horizontal = value.translation.width
                        let vertical = value.translation.height
                        
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                            if !viewModel.isDrawerOpen && horizontal > 40 && abs(horizontal) > abs(vertical) * 0.6 {
                                viewModel.openDrawer()
                            } else if viewModel.isDrawerOpen && horizontal < -40 {
                                viewModel.closeDrawer()
                            } else if viewModel.isDrawerOpen && viewModel.drawerProgress > 0.4 {
                                viewModel.openDrawer()
                            } else {
                                viewModel.closeDrawer()
                            }
                        }
                    }
            )
        }
        // Feuille de Paramètres Native (#sheet)
        .sheet(isPresented: $isShowingSettings) {
            if #available(iOS 15.0, *) {
                SettingsView(viewModel: viewModel)
            }
        }
    }
}
