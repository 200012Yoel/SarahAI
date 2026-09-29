import SwiftUI

/// Vue racine stable de SarahIA.
///
/// Priorité absolue : les contrôles SwiftUI doivent conserver la propriété des
/// touchers. Le geste d'ouverture du tiroir est donc limité à une fine zone au
/// bord gauche au lieu d'être installé sur toute la fenêtre.
@available(iOS 15.0, *)
public struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var isShowingSettings = false

    public init() {}

    public var body: some View {
        GeometryReader { geo in
            let sidebarWidth = min(
                CGFloat(360),
                max(CGFloat(278), geo.size.width * 0.84)
            )

            ZStack(alignment: .leading) {
                ChatScreenView(
                    viewModel: viewModel,
                    isShowingSettings: $isShowingSettings
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(
                    !viewModel.isDrawerOpen && viewModel.drawerProgress <= 0.001
                )

                // Le swipe d'ouverture ne vit plus sur toute l'application.
                // Cette bande très fine préserve le geste bord-gauche sans
                // concurrencer Button, Menu, TextField, ScrollView ou les cartes.
                if !viewModel.isDrawerOpen,
                   viewModel.drawerProgress <= 0.001,
                   !viewModel.isShowingVoiceOrbModal {
                    edgeSwipeHotZone(width: sidebarWidth)
                        .zIndex(3)
                }

                if viewModel.isShowingVoiceOrbModal {
                    VoiceOrbModalView(
                        viewModel: viewModel,
                        onOpenMenu: {
                            viewModel.openDrawer()
                        },
                        onOpenSettings: {
                            isShowingSettings = true
                        }
                    )
                    .zIndex(20)
                    .transition(.opacity)
                }

                if viewModel.isDrawerOpen || viewModel.drawerProgress > 0.001 {
                    drawerOverlay
                        .zIndex(30)

                    SidebarView(
                        viewModel: viewModel,
                        isShowingSettings: $isShowingSettings
                    )
                    .frame(width: sidebarWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.black)
                    .ignoresSafeArea(.container, edges: [.top, .bottom])
                    .offset(x: drawerOffset(width: sidebarWidth))
                    .transition(.move(edge: .leading))
                    .zIndex(31)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.black.ignoresSafeArea())
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(viewModel: viewModel)
        }
        .onAppear {
            // Les états de navigation sont transitoires. Un ancien état ou une
            // interaction interrompue ne doit jamais démarrer l'app avec une
            // couche invisible qui bloque les contrôles.
            viewModel.isDrawerOpen = false
            viewModel.drawerProgress = 0
            isShowingSettings = false
        }
        .onChange(of: viewModel.isShowingVoiceOrbModal) { isPresented in
            if isPresented {
                viewModel.activeAgent = .sarah
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSNotification.Name("SarahOpenDeepLink")
            )
        ) { notification in
            guard let host = notification.object as? String else { return }

            switch host {
            case "voice":
                viewModel.activeAgent = .sarah
                viewModel.isShowingVoiceOrbModal = true
            case "chat":
                viewModel.stopVoiceConversation()
                viewModel.isShowingVoiceOrbModal = false
            default:
                break
            }
        }
    }

    private var drawerOverlay: some View {
        Color.black
            .opacity(
                Double(
                    viewModel.drawerProgress > 0.001
                        ? viewModel.drawerProgress
                        : (viewModel.isDrawerOpen ? 1.0 : 0.0)
                ) * 0.40
            )
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    viewModel.closeDrawer()
                }
            }
    }

    private func edgeSwipeHotZone(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: 18)
                .contentShape(Rectangle())
                .gesture(edgeOpenGesture(width: width))

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(true)
    }

    private func drawerOffset(width: CGFloat) -> CGFloat {
        let progress = viewModel.drawerProgress > 0.001
            ? viewModel.drawerProgress
            : (viewModel.isDrawerOpen ? 1.0 : 0.0)
        return (progress - 1.0) * width
    }

    private func edgeOpenGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 16)
            .onChanged { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height

                guard horizontal > 0,
                      abs(horizontal) > abs(vertical) * 0.85 else {
                    return
                }

                viewModel.drawerProgress = min(max(horizontal / width, 0), 1)
            }
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height

                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    if horizontal > 52,
                       abs(horizontal) > abs(vertical) * 0.85 {
                        viewModel.openDrawer()
                    } else {
                        viewModel.closeDrawer()
                    }
                }
            }
    }
}
