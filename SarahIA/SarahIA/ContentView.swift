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
            let sidebarWidth: CGFloat = 280
            
            ZStack(alignment: .leading) {
                // Vue Principale (Chat)
                ChatScreenView(viewModel: viewModel, isShowingSettings: $isShowingSettings)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .disabled(viewModel.isDrawerOpen)
                
                // Overlay sombre + Menu latéral
                if viewModel.isDrawerOpen || viewModel.drawerProgress > 0.001 {
                    Color.black
                        .opacity(Double(viewModel.drawerProgress > 0.001 ? viewModel.drawerProgress : (viewModel.isDrawerOpen ? 1.0 : 0.0)) * 0.40)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                                viewModel.closeDrawer()
                            }
                        }
                    
                    SidebarView(
                        viewModel: viewModel,
                        isShowingSettings: $isShowingSettings
                    )
                    .frame(maxWidth: sidebarWidth, maxHeight: .infinity)
                    .background(Color(white: 0.12))
                    .ignoresSafeArea(.all, edges: [.top, .bottom])
                    .offset(x: (viewModel.drawerProgress > 0.001 ? viewModel.drawerProgress - 1.0 : (viewModel.isDrawerOpen ? 0.0 : -1.0)) * sidebarWidth)
                    .transition(.move(edge: .leading))
                    .zIndex(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        }
        // Feuille de Paramètres Native (#sheet)
        .sheet(isPresented: $isShowingSettings) {
            if #available(iOS 15.0, *) {
                SettingsView(viewModel: viewModel)
            }
        }
    }
}
