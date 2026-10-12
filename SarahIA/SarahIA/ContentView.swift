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
    @State private var drawerDragOffset: CGFloat = 0
    @State private var drawerIsDragging = false

    public init() {}

    public var body: some View {
        GeometryReader { geo in
            let sidebarWidth = min(
                CGFloat(360),
                max(CGFloat(278), geo.size.width * 0.84)
            )

            let progress = min(CGFloat(1), max(CGFloat(0),
                (viewModel.isDrawerOpen ? sidebarWidth : 0) + drawerDragOffset
            ) / sidebarWidth)

            ZStack(alignment: .leading) {
                ChatScreenView(
                    viewModel: viewModel,
                    isShowingSettings: $isShowingSettings
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(0)

                // The edge tracks the user's finger continuously, instead
                // of waiting for a completed drag before opening the drawer.
                if !viewModel.isDrawerOpen && !viewModel.isShowingVoiceOrbModal && !viewModel.isShowingTranslateLive {
                    Color.clear
                        .frame(width: 24)
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .gesture(drawerGesture(width: sidebarWidth, opening: true))
                        .zIndex(3)
                }

                if viewModel.isDrawerOpen || drawerIsDragging {
                    drawerOverlay
                        .opacity(Double(progress))
                        .allowsHitTesting(viewModel.isDrawerOpen && !drawerIsDragging)
                        .zIndex(30)

                    SidebarView(
                        viewModel: viewModel,
                        isShowingSettings: $isShowingSettings
                    )
                    .frame(width: sidebarWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.black)
                    .ignoresSafeArea(.container, edges: [.top, .bottom])
                    .offset(x: -sidebarWidth * (1 - progress))
                    .simultaneousGesture(drawerGesture(width: sidebarWidth, opening: false))
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
        .sheet(isPresented: $viewModel.isShowingVoiceOrbModal) {
            voiceSheetContent
        }
        .fullScreenCover(isPresented: $viewModel.isShowingTranslateLive) {
            YoannTranslateLiveView(
                initialSource: viewModel.translateLiveSource,
                initialTarget: viewModel.translateLiveTarget
            )
        }
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

            // Prépare le modèle Whisper après le premier rendu. Le chargement reste
            // entièrement hors du thread principal afin que le premier appui sur le
            // mode vocal ouvre l'interface immédiatement.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
                WhisperService.shared.prepareModel()
            }
        }
        // The compact voice surface can remain active after the sheet is dismissed.
        // Always stop microphone capture when the whole app enters the background.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            if viewModel.isContinuousConversationActive {
                viewModel.stopVoiceConversation()
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

    @ViewBuilder
    private var voiceSheetContent: some View {
        if #available(iOS 16.0, *) {
            VoiceSheetDetentHost(
                viewModel: viewModel,
                onOpenMenu: {
                    viewModel.isShowingVoiceOrbModal = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        viewModel.openDrawer()
                    }
                },
                onOpenSettings: {
                    viewModel.isShowingVoiceOrbModal = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        isShowingSettings = true
                    }
                }
            )
        } else {
            VoiceOrbModalView(
                viewModel: viewModel,
                onOpenMenu: {
                    viewModel.isShowingVoiceOrbModal = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        viewModel.openDrawer()
                    }
                },
                onOpenSettings: {
                    viewModel.isShowingVoiceOrbModal = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        isShowingSettings = true
                    }
                }
            )
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

    /// A partial pull follows the finger. Releasing before the halfway
    /// threshold closes it; a decisive flick opens it directly to all chats.
    /// The reverse drag closes it. Vertical chat scrolling is not hijacked.
    private func drawerGesture(width: CGFloat, opening: Bool) -> some Gesture {
        DragGesture(minimumDistance: 9)
            .onChanged { value in
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > abs(dy) * 1.2,
                      (opening ? dx > 0 : dx < 0) else { return }
                drawerIsDragging = true
                drawerDragOffset = opening
                    ? min(width, max(0, dx))
                    : max(-width, min(0, dx))
            }
            .onEnded { value in
                guard drawerIsDragging else { return }
                let currentWidth = (opening ? 0 : width) + drawerDragOffset
                let flick = value.predictedEndTranslation.width - value.translation.width
                let open: Bool
                if opening {
                    // Halfway pulls close unless the user flicked decisively.
                    open = currentWidth >= width * 0.62 || flick > width * 0.26
                } else {
                    open = currentWidth >= width * 0.38 && flick > -width * 0.22
                }
                withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.87)) {
                    drawerDragOffset = 0
                    drawerIsDragging = false
                    if open { viewModel.openDrawer() }
                    else { viewModel.closeDrawer() }
                }
            }
    }
}

/// Hôte du mode vocal moderne. La feuille reste grande ; un glissement vers le bas
/// la ferme visuellement sans couper la conversation. Le petit orbe apparaît alors
/// au-dessus du véritable composer du chat.
@available(iOS 16.0, *)
private struct VoiceSheetDetentHost: View {
    @ObservedObject var viewModel: ChatViewModel
    let onOpenMenu: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VoiceOrbModalView(
            viewModel: viewModel,
            onOpenMenu: onOpenMenu,
            onOpenSettings: onOpenSettings
        )
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
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
