import SwiftUI

/// Vue racine stable : le chat reste plein écran et le menu glisse par-dessus.
/// Pas de scaling 3D ni de coins géants, afin d'éviter les bugs de toucher.
@available(iOS 16.0, *)
public struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var isShowingSettings = false

    public init() {}

    public var body: some View {
        GeometryReader { geo in
            let sidebarWidth = min(
                CGFloat(360),
                max(CGFloat(286), geo.size.width * 0.84)
            )

            ZStack(alignment: .leading) {
                ChatScreenView(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .disabled(viewModel.isDrawerOpen)

                if viewModel.isDrawerOpen || viewModel.drawerProgress > 0.001 {
                    Color.black
                        .opacity(0.40 * Double(max(viewModel.drawerProgress, 0.01)))
                        .ignoresSafeArea()
                        .onTapGesture {
                            viewModel.closeDrawer()
                        }

                    SidebarView(
                        viewModel: viewModel,
                        isShowingSettings: $isShowingSettings
                    )
                    .frame(width: sidebarWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.black)
                    .offset(
                        x: (
                            viewModel.drawerProgress > 0.001
                            ? viewModel.drawerProgress - 1.0
                            : 0
                        ) * sidebarWidth
                    )
                    .zIndex(2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        let horizontal = value.translation.width
                        let vertical = value.translation.height

                        if !viewModel.isDrawerOpen {
                            if value.startLocation.x <= 30,
                               horizontal > 0,
                               abs(horizontal) > abs(vertical) * 0.6 {
                                viewModel.drawerProgress = min(horizontal / sidebarWidth, 1)
                            }
                        } else if horizontal < 0 {
                            viewModel.drawerProgress = max(0, 1 + horizontal / sidebarWidth)
                        }
                    }
                    .onEnded { value in
                        let horizontal = value.translation.width

                        if !viewModel.isDrawerOpen {
                            if value.startLocation.x <= 30 && horizontal > 42 {
                                viewModel.openDrawer()
                            } else {
                                viewModel.closeDrawer()
                            }
                        } else {
                            if horizontal < -42 || viewModel.drawerProgress < 0.45 {
                                viewModel.closeDrawer()
                            } else {
                                viewModel.openDrawer()
                            }
                        }
                    }
            )
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(viewModel: viewModel)
        }
        .preferredColorScheme(.dark)
    }
}
