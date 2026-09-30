import SwiftUI

/// Vue racine de SarahIA orientée stabilité.
///
/// Règle importante : aucune couche invisible ne doit pouvoir rester au-dessus
/// du chat. Le tiroir est désormais binaire (ouvert / fermé) et son geste de
/// bord ne modifie plus un état de progression intermédiaire.
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
                // Le chat reste toujours interactif. Les vrais overlays ci-dessous
                // interceptent eux-mêmes les touches uniquement lorsqu'ils existent.
                // Cela évite qu'un état vocal/tiroir désynchronisé rende toute
                // l'application non cliquable derrière une couche invisible.
                ChatScreenView(
                    viewModel: viewModel,
                    isShowingSettings: $isShowingSettings
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(0)

                // Zone de swipe réellement limitée aux 18 points du bord gauche.
                // Elle ne contient aucun Spacer plein écran et ne peut donc pas
                // devenir une surface invisible qui absorbe les boutons du chat.
                if !viewModel.isDrawerOpen && !viewModel.isShowingVoiceOrbModal {
                    Color.clear
                        .frame(width: 18)
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .gesture(edgeOpenGesture)
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

                if viewModel.isDrawerOpen {
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
            // Tous les états purement visuels repartent d'une base connue.
            viewModel.isDrawerOpen = false
            viewModel.drawerProgress = 0
            viewModel.isShowingVoiceOrbModal = false
            isShowingSettings = false
        }
        .onChange(of: isShowingSettings) { isPresented in
            if isPresented {
                viewModel.closeDrawer()
            }
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
                viewModel.closeDrawer()
                viewModel.isShowingVoiceOrbModal = true
            case "chat":
                viewModel.stopVoiceConversation()
                viewModel.isShowingVoiceOrbModal = false
                viewModel.closeDrawer()
            default:
                break
            }
        }
    }

    private var drawerOverlay: some View {
        Color.black
            .opacity(0.40)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.closeDrawer()
            }
    }

    private var edgeOpenGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height

                guard horizontal > 52,
                      abs(horizontal) > abs(vertical) * 0.85 else {
                    return
                }

                viewModel.openDrawer()
            }
    }
}
