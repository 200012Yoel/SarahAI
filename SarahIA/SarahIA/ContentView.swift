import SwiftUI
import UIKit

/// Vue Racine 100% Native SwiftUI avec interface de chat principale et tiroir latéral fluide.
/// - L'écran de chat reste plein écran sous le tiroir sans être déformé ni découpé.
/// - Le menu latéral (Sidebar) glisse en superposition fluide depuis la gauche avec un voile sombre.
/// - Geste de glissement haute priorité (gauche -> droite) pour ouvrir le menu des discussions.
@available(iOS 15.0, *)
public struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var isShowingSettings: Bool = false
    @State private var isSarahCamouflageActive: Bool = false
    @AppStorage("sarahEngineHaloEnabled") private var sarahEngineHaloEnabled: Bool = true
    @AppStorage("sarahEngineCamouflageEnabled") private var sarahEngineCamouflageEnabled: Bool = true
    
    public init() {}
    
    public var body: some View {
        GeometryReader { geo in
            let sidebarWidth = min(CGFloat(344), geo.size.width * 0.88)
            
            ZStack(alignment: .leading) {
                // Vue Principale (Chat)
                ChatScreenView(viewModel: viewModel, isShowingSettings: $isShowingSettings)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .disabled(viewModel.isDrawerOpen || isSarahCamouflageActive)
                
                // Overlay sombre + Menu latéral
                if !isSarahCamouflageActive && (viewModel.isDrawerOpen || viewModel.drawerProgress > 0.001) {
                    Color.black
                        .opacity(Double(viewModel.drawerProgress > 0.001 ? viewModel.drawerProgress : (viewModel.isDrawerOpen ? 1.0 : 0.0)) * 0.40)
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
                    .frame(maxWidth: sidebarWidth, maxHeight: .infinity)
                    .background(Color(white: 0.12))
                    .ignoresSafeArea(.all, edges: [.top, .bottom])
                    .offset(x: (viewModel.drawerProgress > 0.001 ? viewModel.drawerProgress - 1.0 : (viewModel.isDrawerOpen ? 0.0 : -1.0)) * sidebarWidth)
                    .transition(.move(edge: .leading))
                    .zIndex(1)
                }

                if isSarahCamouflageActive {
                    SarahCamouflageOverlayView()
                        .transition(.opacity)
                        .zIndex(50)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            // Le geste d'ouverture commence seulement près du bord gauche : il ne doit pas
            // voler le défilement normal des messages ou les gestes de saisie.
            .highPriorityGesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        let horizontal = value.translation.width
                        let vertical = value.translation.height
                        
                        if !viewModel.isDrawerOpen {
                            // Glissement de la gauche vers la droite pour ouvrir
                            if value.startLocation.x <= 28 && horizontal > 0 && abs(horizontal) > abs(vertical) * 0.6 {
                                let progress = min(horizontal / sidebarWidth, 1.0)
                                viewModel.drawerProgress = CGFloat(progress)
                            }
                        } else {
                            // Glissement vers la gauche pour refermer
                            if horizontal < 0 {
                                let progress = max(0.0, 1.0 + (horizontal / sidebarWidth))
                                viewModel.drawerProgress = CGFloat(progress)
                            }
                        }
                    }
                    .onEnded { value in
                        let horizontal = value.translation.width
                        let vertical = value.translation.height
                        
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                            if !viewModel.isDrawerOpen && value.startLocation.x <= 28 && horizontal > 40 && abs(horizontal) > abs(vertical) * 0.6 {
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
        // Feuille de Paramètres Native (#sheet)
        .sheet(isPresented: $isShowingSettings) {
            if #available(iOS 15.0, *) {
                SettingsView(viewModel: viewModel)
            }
        }
        .onChange(of: viewModel.isShowingVoiceOrbModal) { isVisible in
            updateSarahEngineHalo(isVoiceVisible: isVisible)
        }
        .onChange(of: sarahEngineHaloEnabled) { _ in
            updateSarahEngineHalo(isVoiceVisible: viewModel.isShowingVoiceOrbModal)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SarahOpenDeepLink"))) { notification in
            guard let host = notification.object as? String else { return }
            if host == "voice" {
                if sarahEngineCamouflageEnabled && SarahHomeScreenSnapshotStore.hasSnapshot {
                    activateSarahCamouflage()
                } else {
                    viewModel.isShowingVoiceOrbModal = true
                }
            } else if host == "chat" {
                viewModel.isShowingVoiceOrbModal = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            consumePendingSarahVoiceLaunch()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            deactivateSarahCamouflage()
        }
        .onAppear {
            consumePendingSarahVoiceLaunch()
        }
        .onDisappear {
            deactivateSarahCamouflage()
            SarahEngineHaloController.shared.hide()
        }
    }

    private func consumePendingSarahVoiceLaunch() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "sarahOpenVoiceOnNextActivation") else { return }
        defaults.set(false, forKey: "sarahOpenVoiceOnNextActivation")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            if sarahEngineCamouflageEnabled && SarahHomeScreenSnapshotStore.hasSnapshot {
                activateSarahCamouflage()
            } else {
                viewModel.isShowingVoiceOrbModal = true
            }
        }
    }

    private func activateSarahCamouflage() {
        viewModel.isShowingVoiceOrbModal = false
        viewModel.closeDrawer()
        isSarahCamouflageActive = true
        viewModel.startVoiceConversation()

        if sarahEngineHaloEnabled {
            SarahEngineHaloController.shared.show()
        }
    }

    private func deactivateSarahCamouflage() {
        guard isSarahCamouflageActive else { return }
        isSarahCamouflageActive = false
        viewModel.stopVoiceConversation()
        SarahEngineHaloController.shared.hide()
    }

    private func updateSarahEngineHalo(isVoiceVisible: Bool) {
        if (isVoiceVisible || isSarahCamouflageActive) && sarahEngineHaloEnabled {
            SarahEngineHaloController.shared.show()
        } else {
            SarahEngineHaloController.shared.hide()
        }
    }
}

// MARK: - Sarah Engine Halo

/// Fenêtre purement visuelle au-dessus de l'app. Elle ne capture aucun toucher.
/// Elle permet au halo de rester visible autour de l'écran et de l'encoche
/// même lorsque le mode vocal est présenté dans une sheet.
@available(iOS 15.0, *)
private final class SarahEngineHaloController {
    static let shared = SarahEngineHaloController()

    private var haloWindow: SarahPassthroughWindow?

    private init() {}

    func show() {
        guard UserDefaults.standard.object(forKey: "sarahEngineHaloEnabled") as? Bool ?? true else {
            hide()
            return
        }

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive })
        else { return }

        if haloWindow != nil {
            return
        }

        let window = SarahPassthroughWindow(windowScene: windowScene)
        window.frame = windowScene.screen.bounds
        window.backgroundColor = .clear
        window.windowLevel = UIWindow.Level.alert + 1

        let host = UIHostingController(rootView: SarahEngineHaloOverlay())
        host.view.backgroundColor = .clear
        window.rootViewController = host
        window.isHidden = false

        haloWindow = window
    }

    func hide() {
        haloWindow?.isHidden = true
        haloWindow?.rootViewController = nil
        haloWindow = nil
    }
}

@available(iOS 15.0, *)
private final class SarahPassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        nil
    }
}

@available(iOS 15.0, *)
private struct SarahEngineHaloOverlay: View {
    @State private var rotate = false
    @State private var breathe = false

    private var haloGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [
                Color(red: 1.0, green: 0.18, blue: 0.65),
                Color(red: 0.65, green: 0.20, blue: 1.0),
                Color(red: 0.05, green: 0.80, blue: 1.0),
                Color(red: 0.25, green: 0.45, blue: 1.0),
                Color(red: 1.0, green: 0.18, blue: 0.65)
            ]),
            center: .center,
            angle: .degrees(rotate ? 360 : 0)
        )
    }

    var body: some View {
        GeometryReader { geo in
            let topInset = max(geo.safeAreaInsets.top, 44)
            let hasNotch = topInset > 28

            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(haloGradient, lineWidth: 4.5)
                    .padding(2)
                    .shadow(
                        color: Color(red: 1.0, green: 0.18, blue: 0.65).opacity(breathe ? 0.82 : 0.40),
                        radius: breathe ? 14 : 7
                    )

                if hasNotch {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(haloGradient, lineWidth: 3.5)
                        .frame(width: 188, height: 42)
                        .position(x: geo.size.width / 2, y: topInset * 0.54)
                        .shadow(
                            color: Color(red: 0.05, green: 0.80, blue: 1.0).opacity(breathe ? 0.72 : 0.34),
                            radius: breathe ? 12 : 6
                        )
                }
            }
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.linear(duration: 4.8).repeatForever(autoreverses: false)) {
                rotate = true
            }
            withAnimation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }
}


// MARK: - Sarah Engine Camouflage

/// Stocke une capture choisie volontairement par l'utilisateur.
/// iOS ne donne pas accès au vrai SpringBoard en direct ; cette image sert
/// uniquement à créer l'illusion visuelle pendant que Sarah est au premier plan.
enum SarahHomeScreenSnapshotStore {
    private static var directoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("SarahEngine", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var fileURL: URL {
        directoryURL.appendingPathComponent("home-screen-snapshot.jpg")
    }

    static var hasSnapshot: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    static func save(_ image: UIImage) -> Bool {
        guard let data = image.jpegData(compressionQuality: 0.96) else { return false }
        do {
            try data.write(to: fileURL, options: .atomic)
            return true
        } catch {
            print("⚠️ [SarahEngine] Impossible d'enregistrer la capture écran d'accueil: \(error.localizedDescription)")
            return false
        }
    }

    static func load() -> UIImage? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    static func remove() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}

@available(iOS 15.0, *)
private struct SarahCamouflageOverlayView: View {
    @State private var snapshot: UIImage? = SarahHomeScreenSnapshotStore.load()

    var body: some View {
        ZStack {
            if let snapshot = snapshot {
                Image(uiImage: snapshot)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .statusBar(hidden: true)
        .allowsHitTesting(false)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SarahHomeScreenSnapshotChanged"))) { _ in
            snapshot = SarahHomeScreenSnapshotStore.load()
        }
    }
}
