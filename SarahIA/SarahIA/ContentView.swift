import SwiftUI

/// Vue racine de Sarah IA avec tiroir latéral interactif.
/// Un glissement depuis le bord gauche suit le doigt en temps réel,
/// puis le panneau s'ouvre ou se referme avec une animation à ressort.
@available(iOS 15.0, *)
public struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var isShowingSettings = false
    @State private var drawerDragStartedOpen: Bool? = nil
    @State private var isShowingLaunchAnimation = true
    @State private var isShowingModelInstaller = false
    @AppStorage("sarahModelInstallerPromptV1") private var modelInstallerPromptHandled = false
    @StateObject private var modelInstaller = SarahModelInstallCoordinator.shared

    public init() {}

    public var body: some View {
        ZStack {
            GeometryReader { geo in
            let drawerWidth = min(
                CGFloat(326),
                max(CGFloat(276), geo.size.width - 68)
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
                    1.0 - (0.018 * progress),
                    anchor: .trailing
                )
                .offset(x: 18 * progress)
                .disabled(progress > 0.001)
                .animation(nil, value: progress)

                // Voile progressif derrière le panneau.
                if progress > 0.001 || viewModel.isDrawerOpen {
                    Color.black
                        .opacity(Double(progress) * 0.62)
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
                            cornerRadius: 20,
                            style: .continuous
                        )
                    )
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: 20,
                            style: .continuous
                        )
                        .stroke(
                            Color.white.opacity(0.085),
                            lineWidth: 0.8
                        )
                    )
                    .shadow(
                        color: Color.black.opacity(0.55),
                        radius: 20,
                        x: 8,
                        y: 2
                    )
                    .padding(.vertical, 4)
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

            if viewModel.isVoiceBubbleVisible && !viewModel.isShowingVoiceOrbModal {
                SarahFloatingVoiceBubble(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .transition(.scale(scale: 0.84).combined(with: .opacity))
                    .zIndex(40)
            }

            if isShowingLaunchAnimation {
                SarahLaunchAnimationView()
                    .transition(.opacity)
                    .zIndex(100)
            }

            if isShowingModelInstaller {
                SarahModelInstallerOverlay(
                    installer: modelInstaller,
                    onInstall: {
                        modelInstallerPromptHandled = true
                        modelInstaller.installAllCompatible()
                    },
                    onContinue: {
                        modelInstallerPromptHandled = true
                        withAnimation(.easeOut(duration: 0.25)) {
                            isShowingModelInstaller = false
                        }
                    },
                    onLater: {
                        modelInstallerPromptHandled = true
                        withAnimation(.easeOut(duration: 0.25)) {
                            isShowingModelInstaller = false
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(90)
            }
        }
        .onAppear {
            modelInstaller.resumeIfRequested()

            guard isShowingLaunchAnimation else {
                if !modelInstallerPromptHandled {
                    isShowingModelInstaller = true
                }
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.65) {
                withAnimation(.easeOut(duration: 0.35)) {
                    isShowingLaunchAnimation = false
                }

                if !modelInstallerPromptHandled {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isShowingModelInstaller = true
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(viewModel: viewModel)
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.willResignActiveNotification
            )
        ) { _ in
            if viewModel.isContinuousConversationActive {
                viewModel.stopVoiceConversation()
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


@available(iOS 15.0, *)
private struct SarahFloatingVoiceBubble: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var pulse = false

    private var accent: Color { viewModel.activeAgent.themeColor }

    var body: some View {
        Button {
            HapticService.shared.buttonTap()
            viewModel.restoreVoiceConversation()
        } label: {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.12))
                    .frame(width: 68, height: 68)
                    .scaleEffect(pulse ? 1.10 : 0.92)
                    .opacity(pulse ? 0.22 : 0.62)

                Circle()
                    .fill(Color(red: 0.075, green: 0.078, blue: 0.095))
                    .frame(width: 54, height: 54)
                    .shadow(color: accent.opacity(0.34), radius: 14)

                Circle()
                    .stroke(accent.opacity(0.64), lineWidth: 1.2)
                    .frame(width: 54, height: 54)

                Image(systemName: viewModel.isSpeaking ? "waveform" : "mic.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(accent)
                    .scaleEffect(
                        1.0 + CGFloat(min(max(viewModel.micInputLevel, 0), 1)) * 0.10
                    )
                    .animation(.easeOut(duration: 0.10), value: viewModel.micInputLevel)

                Circle()
                    .fill(viewModel.isMicRunning ? Color.green : accent)
                    .frame(width: 7, height: 7)
                    .offset(x: 18, y: -18)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Rouvrir le mode vocal")
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.15)
                    .repeatForever(autoreverses: true)
            ) {
                pulse = true
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                viewModel.stopVoiceConversation()
            } label: {
                Label("Arrêter le mode vocal", systemImage: "stop.circle")
            }
        }
    }
}

@available(iOS 15.0, *)
private struct SarahModelInstallerOverlay: View {
    @ObservedObject var installer: SarahModelInstallCoordinator
    let onInstall: () -> Void
    let onContinue: () -> Void
    let onLater: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.96).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    Spacer(minLength: 42)

                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.14))
                            .frame(width: 94, height: 94)

                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 46, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    VStack(spacing: 8) {
                        Text("Préparer Sarah sur cet iPhone")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        Text(installer.hardwareSummary)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.48))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(installer.installableNames, id: \.self) { name in
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)

                                Text(name)
                                    .font(.system(size: 14.5, weight: .medium))
                                    .foregroundColor(Color.white.opacity(0.88))

                                Spacer()
                            }
                        }

                        Text("Les moteurs expérimentaux sans runtime iPhone validé ne sont pas téléchargés inutilement.")
                            .font(.caption)
                            .foregroundColor(Color.white.opacity(0.42))
                            .padding(.top, 4)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.065))
                    )

                    if installer.isInstalling {
                        VStack(alignment: .leading, spacing: 9) {
                            ProgressView(value: installer.progress)
                                .tint(.blue)

                            HStack {
                                Text(installer.statusText)
                                    .font(.caption)
                                    .foregroundColor(Color.white.opacity(0.62))
                                Spacer()
                                Text("\(Int(installer.progress * 100)) %")
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(Color.white.opacity(0.62))
                            }

                            Text("Tu peux quitter Sarah : les transferts utilisent les téléchargements de fond d’iOS et reprendront automatiquement selon le réseau et l’énergie.")
                                .font(.caption2)
                                .foregroundColor(Color.white.opacity(0.40))
                        }
                    }

                    if installer.isInstalling {
                        Button(action: onContinue) {
                            Text("Continuer dans Sarah")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.blue)
                                )
                        }
                    } else if installer.totalCount > 0 && installer.installedCount == installer.totalCount {
                        Button(action: onContinue) {
                            Text("Ouvrir Sarah")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.green.opacity(0.86))
                                )
                        }
                    } else {
                        Button(action: onInstall) {
                            HStack(spacing: 9) {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("Installer tout")
                            }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        Button("Plus tard", action: onLater)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.48))
                    }

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 22)
            }
        }
        .preferredColorScheme(.dark)
    }
}

@available(iOS 15.0, *)
private struct SarahLaunchAnimationView: View {
    @State private var logoScale: CGFloat = 0.72
    @State private var logoOpacity: Double = 0.0
    @State private var glowScale: CGFloat = 0.65
    @State private var glowOpacity: Double = 0.0
    @State private var subtitleOpacity: Double = 0.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(red: 0.18, green: 0.35, blue: 0.95).opacity(0.20),
                    Color.clear
                ],
                center: .center,
                startRadius: 10,
                endRadius: 260
            )
            .scaleEffect(glowScale)
            .opacity(glowOpacity)

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Text("Sarah")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Image(systemName: "sparkles")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.34, green: 0.52, blue: 1.0),
                                    Color(red: 0.55, green: 0.34, blue: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                Text("Intelligence locale · Raccourcis · Création")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.48))
                    .opacity(subtitleOpacity)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.spring(response: 0.62, dampingFraction: 0.74)) {
                logoScale = 1.0
                logoOpacity = 1.0
                glowScale = 1.0
                glowOpacity = 1.0
            }

            withAnimation(.easeOut(duration: 0.45).delay(0.36)) {
                subtitleOpacity = 1.0
            }

            withAnimation(.easeInOut(duration: 0.70).repeatForever(autoreverses: true).delay(0.55)) {
                glowScale = 1.10
                glowOpacity = 0.66
            }
        }
    }
}
