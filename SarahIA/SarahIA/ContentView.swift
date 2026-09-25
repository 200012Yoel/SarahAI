import SwiftUI

/// Vue racine stable de SarahIA.
///
/// Le mode vocal vit maintenant dans la vue racine : il peut passer du plein
/// écran au petit orbe sans fermer la session audio ni arrêter le micro.
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
                .disabled(viewModel.isDrawerOpen)

                if viewModel.isDrawerOpen || viewModel.drawerProgress > 0.001 {
                    drawerOverlay

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
                    .zIndex(2)
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .simultaneousGesture(drawerGesture(width: sidebarWidth))
        }
        .background(Color.black.ignoresSafeArea())
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(viewModel: viewModel)
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
                viewModel.endVoiceConversation()
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
            .zIndex(1)
            .onTapGesture {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    viewModel.closeDrawer()
                }
            }
    }

    private func drawerOffset(width: CGFloat) -> CGFloat {
        let progress = viewModel.drawerProgress > 0.001
            ? viewModel.drawerProgress
            : (viewModel.isDrawerOpen ? 1.0 : 0.0)
        return (progress - 1.0) * width
    }

    private func drawerGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height

                guard abs(horizontal) > abs(vertical) * 0.6 else { return }

                if !viewModel.isDrawerOpen {
                    guard value.startLocation.x <= 28, horizontal > 0 else { return }
                    viewModel.drawerProgress = min(max(horizontal / width, 0), 1)
                } else if horizontal < 0 {
                    viewModel.drawerProgress = min(max(1.0 + horizontal / width, 0), 1)
                }
            }
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height

                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    if !viewModel.isDrawerOpen,
                       value.startLocation.x <= 28,
                       horizontal > 40,
                       abs(horizontal) > abs(vertical) * 0.6 {
                        viewModel.openDrawer()
                    } else if viewModel.isDrawerOpen,
                              horizontal < -40,
                              abs(horizontal) > abs(vertical) * 0.6 {
                        viewModel.closeDrawer()
                    } else if viewModel.isDrawerOpen && viewModel.drawerProgress > 0.4 {
                        viewModel.openDrawer()
                    } else {
                        viewModel.closeDrawer()
                    }
                }
            }
    }
}
