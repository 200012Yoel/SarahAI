import SwiftUI

/// Vue racine de Sarah IA avec tiroir latéral interactif.
/// Un glissement depuis le bord gauche suit le doigt en temps réel,
/// puis le panneau s'ouvre ou se referme avec une animation à ressort.
@available(iOS 15.0, *)
public struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var isShowingSettings = false
    @State private var drawerDragStartedOpen: Bool? = nil

    public init() {}

    public var body: some View {
        GeometryReader { geo in
            let drawerWidth = min(
                CGFloat(390),
                max(CGFloat(300), geo.size.width * 0.88)
            )

            let progress = min(
                max(viewModel.drawerProgress, CGFloat(0)),
                CGFloat(1)
            )

            ZStack(alignment: .leading) {
                Color.black
                    .ignoresSafeArea()

                // Le chat reste visible derrière le tiroir, avec un léger
                // déplacement et une réduction de profondeur pendant le geste.
                ChatScreenView(
                    viewModel: viewModel,
                    isShowingSettings: $isShowingSettings
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(
                    1.0 - (0.035 * progress),
                    anchor: .trailing
                )
                .offset(x: drawerWidth * 0.10 * progress)
                .disabled(progress > 0.001)
                .animation(nil, value: progress)

                // Voile progressif derrière le panneau.
                if progress > 0.001 || viewModel.isDrawerOpen {
                    Color.black
                        .opacity(Double(progress) * 0.46)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.closeDrawer()
                        }
                        .transition(.opacity)
                }

                // Tiroir moderne : arrondi, flottant et ombré.
                if progress > 0.001 || viewModel.isDrawerOpen {
                    SidebarView(
                        viewModel: viewModel,
                        isShowingSettings: $isShowingSettings
                    )
                    .frame(width: drawerWidth)
                    .frame(maxHeight: .infinity)
                    .background(
                        Color(red: 0.035, green: 0.040, blue: 0.052)
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 32,
                            style: .continuous
                        )
                    )
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: 32,
                            style: .continuous
                        )
                        .stroke(
                            Color.white.opacity(0.085),
                            lineWidth: 0.8
                        )
                    )
                    .shadow(
                        color: Color.black.opacity(0.55),
                        radius: 28,
                        x: 10,
                        y: 6
                    )
                    .padding(.top, max(6, geo.safeAreaInsets.top + 6))
                    .padding(.bottom, max(6, geo.safeAreaInsets.bottom + 6))
                    .offset(
                        x: -drawerWidth * (1.0 - progress)
                    )
                    .zIndex(3)
                    .animation(nil, value: progress)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .simultaneousGesture(
                drawerGesture(
                    drawerWidth: drawerWidth,
                    screenWidth: geo.size.width
                )
            )
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(viewModel: viewModel)
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSNotification.Name("SarahOpenDeepLink")
            )
        ) { notification in
            guard let host = notification.object as? String else { return }

            switch host {
            case "voice":
                viewModel.isShowingVoiceOrbModal = true
            case "chat":
                viewModel.isShowingVoiceOrbModal = false
            default:
                break
            }
        }
    }

    // MARK: - Geste interactif du tiroir

    private func drawerGesture(
        drawerWidth: CGFloat,
        screenWidth: CGFloat
    ) -> some Gesture {
        DragGesture(minimumDistance: 7, coordinateSpace: .local)
            .onChanged { value in
                let dx = value.translation.width
                let dy = value.translation.height

                // Laisser les scrolls verticaux du chat tranquilles.
                guard abs(dx) > abs(dy) * 0.85 else { return }

                if drawerDragStartedOpen == nil {
                    drawerDragStartedOpen = viewModel.isDrawerOpen
                }

                let startedOpen = drawerDragStartedOpen ?? viewModel.isDrawerOpen

                if startedOpen {
                    // Une fois ouvert, on peut le refermer depuis n'importe où
                    // par un glissement vers la gauche.
                    if dx < 0 {
                        viewModel.drawerProgress = clamp(
                            1.0 + (dx / drawerWidth)
                        )
                    } else {
                        viewModel.drawerProgress = 1.0
                    }
                } else {
                    // À l'état fermé, ouverture uniquement depuis le bord gauche
                    // pour ne pas voler les gestes du contenu.
                    let edgeActivationWidth = min(CGFloat(44), screenWidth * 0.12)

                    guard value.startLocation.x <= edgeActivationWidth,
                          dx > 0 else {
                        return
                    }

                    // Important : on reste dans le mode "départ fermé" pendant
                    // tout le geste, même lorsque progress devient > 0.
                    viewModel.drawerProgress = clamp(dx / drawerWidth)
                }
            }
            .onEnded { value in
                let startedOpen = drawerDragStartedOpen ?? viewModel.isDrawerOpen
                drawerDragStartedOpen = nil

                let dx = value.translation.width
                let dy = value.translation.height

                guard abs(dx) > abs(dy) * 0.70 else {
                    settleDrawer()
                    return
                }

                let projectedX = value.predictedEndTranslation.width
                let progress = clamp(viewModel.drawerProgress)

                if startedOpen {
                    // Si le doigt part franchement à gauche, on ferme même si
                    // le panneau n'a pas dépassé la moitié du trajet.
                    let shouldClose =
                        progress < 0.58 ||
                        projectedX < -(drawerWidth * 0.28)

                    if shouldClose {
                        viewModel.closeDrawer()
                    } else {
                        viewModel.openDrawer()
                    }
                } else {
                    let shouldOpen =
                        progress > 0.34 ||
                        projectedX > drawerWidth * 0.36

                    if shouldOpen {
                        viewModel.openDrawer()
                    } else {
                        viewModel.closeDrawer()
                    }
                }
            }
    }

    private func settleDrawer() {
        if viewModel.drawerProgress >= 0.5 {
            viewModel.openDrawer()
        } else {
            viewModel.closeDrawer()
        }
    }

    private func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, 0.0), 1.0)
    }
}
