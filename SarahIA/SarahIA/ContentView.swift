import SwiftUI

/// Vue racine de SarahIA orientée stabilité.
///
/// Aucune couche décorative ne doit pouvoir intercepter les touches du chat.
/// Le tiroir et le mode vocal existent uniquement lorsqu'ils sont réellement
/// visibles. L'animation de lancement est purement visuelle et non interactive.
@available(iOS 15.0, *)
public struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var isShowingSettings = false
    @State private var isShowingStartupAnimation = true
    @State private var didScheduleStartupDismissal = false

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
                .zIndex(0)

                // Seuls les 18 points du bord gauche servent au geste du tiroir.
                // Le reste de l'écran reste entièrement libre pour les contrôles.
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

                if isShowingStartupAnimation {
                    SarahStartupAnimationView()
                        .allowsHitTesting(false)
                        .zIndex(100)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.black.ignoresSafeArea())
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(viewModel: viewModel)
        }
        .onAppear {
            // Toujours repartir d'un état visuel interactif et déterministe.
            viewModel.isDrawerOpen = false
            viewModel.drawerProgress = 0
            viewModel.isShowingVoiceOrbModal = false
            isShowingSettings = false

            guard !didScheduleStartupDismissal else { return }
            didScheduleStartupDismissal = true

            // L'intro reprend l'ancien écran Sarah, mais elle n'a jamais le droit
            // de participer au hit testing. Elle disparaît rapidement après le rendu.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
                withAnimation(.easeOut(duration: 0.32)) {
                    isShowingStartupAnimation = false
                }
            }
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

/// Animation d'ouverture légère inspirée de l'ancien écran "Sarah".
/// Important : cette vue est décorative uniquement et ne peut jamais bloquer
/// un Button, Menu ou TextField placé derrière elle.
@available(iOS 15.0, *)
private struct SarahStartupAnimationView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black

            RadialGradient(
                colors: [
                    Color.cyan.opacity(appeared ? 0.20 : 0.04),
                    Color.blue.opacity(appeared ? 0.08 : 0.02),
                    Color.clear
                ],
                center: .center,
                startRadius: 4,
                endRadius: 280
            )

            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Color.cyan.opacity(appeared ? 0.32 : 0.06), lineWidth: 1)
                        .frame(width: 78, height: 78)
                        .scaleEffect(appeared ? 1.0 : 0.72)

                    Circle()
                        .fill(Color.cyan.opacity(appeared ? 0.09 : 0.02))
                        .frame(width: 58, height: 58)

                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }

                Text("Sarah")
                    .font(.system(size: 39, weight: .semibold, design: .rounded))
                    .tracking(1.2)
                    .foregroundColor(.white)
                    .shadow(color: Color.cyan.opacity(appeared ? 0.46 : 0), radius: 18)
            }
            .scaleEffect(appeared ? 1.0 : 0.92)
            .opacity(appeared ? 1.0 : 0.08)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 0.52)) {
                appeared = true
            }
        }
    }
}
