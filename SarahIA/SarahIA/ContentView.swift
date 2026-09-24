import SwiftUI

/// Vue racine moderne de Sarah IA.
/// Le chat reste plein écran et le menu latéral glisse par-dessus sans
/// modifier la géométrie du contenu. La largeur du tiroir s'adapte aux
/// différents formats d'iPhone.
@available(iOS 15.0, *)
public struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var isShowingSettings = false
    @GestureState private var drawerTranslation: CGFloat = 0
    @Environment(\.scenePhase) private var scenePhase

    public init() {}

    public var body: some View {
        GeometryReader { geo in
            let sidebarWidth = min(
                CGFloat(360),
                max(CGFloat(278), geo.size.width * 0.84)
            )

            let restingOffset: CGFloat = viewModel.isDrawerOpen ? 0 : -sidebarWidth
            let offset = min(0, max(-sidebarWidth, restingOffset + drawerTranslation))
            let progress = 1 + offset / sidebarWidth

            ZStack(alignment: .leading) {
                KeyboardDockedChat(viewModel: viewModel, isShowingSettings: $isShowingSettings)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .allowsHitTesting(progress < 0.001)
                    .accessibilityHidden(viewModel.isDrawerOpen)

                Color.black.opacity(Double(progress) * 0.4)
                    .contentShape(Rectangle())
                    .allowsHitTesting(progress > 0.001)
                    .accessibilityHidden(true)
                    .onTapGesture { viewModel.closeDrawer() }

                // Keep one drawer mounted. Only its offset animates; no insertion transition.
                SidebarView(viewModel: viewModel, isShowingSettings: $isShowingSettings)
                    .frame(width: sidebarWidth, height: geo.size.height)
                    .background(Color.black)
                    .offset(x: offset)
                    .allowsHitTesting(viewModel.isDrawerOpen)
                    .accessibilityHidden(!viewModel.isDrawerOpen)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
            .clipped()
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .updating($drawerTranslation) { value, translation, _ in
                        guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                        if viewModel.isDrawerOpen {
                            translation = min(0, value.translation.width)
                        } else if value.startLocation.x <= 24 {
                            translation = max(0, value.translation.width)
                        }
                    }
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                        if viewModel.isDrawerOpen {
                            if value.translation.width < -sidebarWidth * 0.3 || value.predictedEndTranslation.width < -sidebarWidth * 0.5 {
                                viewModel.closeDrawer()
                            }
                        } else if value.startLocation.x <= 24,
                                  value.translation.width > sidebarWidth * 0.3 || (value.startLocation.x <= 24 && value.predictedEndTranslation.width > sidebarWidth * 0.5) {
                            KeyboardObserver.shared.dismiss()
                            viewModel.openDrawer()
                        }
                    }
            )
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .background(Color.black.ignoresSafeArea())
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                viewModel.closeDrawer()
            }
            if phase == .background {
                viewModel.finishDictation()
                viewModel.stopVoiceConversation()
            }
        }
        .preferredColorScheme(.dark)
        .tint(viewModel.activeAgent.themeColor)
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(viewModel: viewModel)
                .preferredColorScheme(.dark)
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSNotification.Name("SarahOpenDeepLink")
            )
        ) { notification in
            guard let host = notification.object as? String else { return }

            switch host {
            case "voice":
                // Démarrer la session avant d'afficher la feuille évite une interface
                // vocale visuellement ouverte mais sans micro actif.
                viewModel.startVoiceConversation()
                viewModel.isShowingVoiceOrbModal = true
            case "chat":
                viewModel.isShowingVoiceOrbModal = false
            case "developer":
                viewModel.sendMessage("Donne-moi l'agent développeur")
#if DEBUG
            case "developer-demo":
                runDeveloperSmokeDemo()
#endif
            default:
                break
            }
        }
    }

#if DEBUG
    private func runDeveloperSmokeDemo() {
        let answers = [
            "Donne-moi l'agent développeur",
            "site internet",
            "e-commerce",
            "Atelier Nova",
            "Vendre des accessoires",
            "Grand public",
            "Apple / Liquid Glass",
            "Bleu",
            "Accueil, Produits, À propos, FAQ, Contact"
        ]

        for (index, answer) in answers.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35 + Double(index) * 0.45) {
                viewModel.sendMessage(answer)
            }
        }
    }
#endif
}

/// UIKit owns the keyboard constraint, so SwiftUI cannot add a second keyboard inset.
@available(iOS 15.0, *)
private struct KeyboardDockedChat: UIViewControllerRepresentable {
    var viewModel: ChatViewModel
    @Binding var isShowingSettings: Bool

    func makeUIViewController(context: Context) -> UIViewController {
        let parent = UIViewController()
        parent.view.backgroundColor = .black
        let host = UIHostingController(rootView:
            ChatScreenView(viewModel: viewModel, isShowingSettings: $isShowingSettings)
                .ignoresSafeArea(.all)
        )
        if #available(iOS 16.4, *) { host.safeAreaRegions = [] }
        host.view.backgroundColor = .black
        parent.addChild(host)
        parent.view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: parent.view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: parent.view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: parent.view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: parent.view.keyboardLayoutGuide.topAnchor)
        ])
        host.didMove(toParent: parent)
        return parent
    }
    func updateUIViewController(_ controller: UIViewController, context: Context) {}
}
