import SwiftUI

/// Vue racine moderne de Sarah IA.
/// Le chat reste plein écran et le menu latéral glisse par-dessus sans
/// modifier la géométrie du contenu. La largeur du tiroir s'adapte aux
/// différents formats d'iPhone.
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
                    Color.black
                        .opacity(
                            Double(
                                viewModel.drawerProgress > 0.001
                                    ? viewModel.drawerProgress
                                    : (viewModel.isDrawerOpen ? 1.0 : 0.0)
                            ) * 0.40
                        )
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
                    .frame(width: sidebarWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.black)
                    .ignoresSafeArea(.all, edges: [.top, .bottom])
                    .offset(
                        x: (
                            viewModel.drawerProgress > 0.001
                                ? viewModel.drawerProgress - 1.0
                                : (viewModel.isDrawerOpen ? 0.0 : -1.0)
                        ) * sidebarWidth
                    )
                    .transition(.move(edge: .leading))
                    .zIndex(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .highPriorityGesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        let horizontal = value.translation.width
                        let vertical = value.translation.height

                        if !viewModel.isDrawerOpen {
                            if value.startLocation.x <= 28,
                               horizontal > 0,
                               abs(horizontal) > abs(vertical) * 0.6 {
                                viewModel.drawerProgress = min(horizontal / sidebarWidth, 1.0)
                            }
                        } else if horizontal < 0 {
                            viewModel.drawerProgress = max(
                                0.0,
                                1.0 + horizontal / sidebarWidth
                            )
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
}
