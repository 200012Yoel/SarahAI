import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

/// Écran principal SarahIA.
///
/// La géométrie est volontairement simple : SwiftUI gère le clavier et les
/// safe areas. Aucun calcul manuel de hauteur de clavier n'est utilisé pour
/// déplacer la barre de saisie. Le mode vocal est présenté par ContentView au
/// niveau racine afin de rester indépendant de cette vue.
@available(iOS 15.0, *)
public struct ChatScreenView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject private var keyboard = KeyboardObserver.shared
    @Binding var isShowingSettings: Bool

    @State private var isShowingActionSheet = false
    @State private var isShowingVoiceCallScreen = false
    @State private var isShowingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isShowingCamera = false
    @State private var isShowingFileImporter = false

    public init(viewModel: ChatViewModel, isShowingSettings: Binding<Bool>) {
        self.viewModel = viewModel
        self._isShowingSettings = isShowingSettings
    }

    private func analyzeSelectedPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    await MainActor.run { viewModel.inputText = "Impossible de lire cette image." }
                    return
                }
                LocalVisionEngine.shared.recognizeObject(in: image) { result in
                    DispatchQueue.main.async {
                        viewModel.appendVisionAnalysis(image: image, result: result)
                    }
                }
            } catch {
                await MainActor.run {
                    viewModel.inputText = "Impossible d'ouvrir la photo : \(error.localizedDescription)"
                }
            }
        }
    }

    private func handleCameraImage(_ image: UIImage) {
        LocalVisionEngine.shared.recognizeObject(in: image) { result in
            DispatchQueue.main.async {
                viewModel.appendVisionAnalysis(image: image, result: result)
            }
        }
    }

    public var body: some View {
        ZStack {
            modernBackground

            VStack(spacing: 0) {
                topBar
                    .padding(.top, 6)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)

                MessageList(
                    messages: viewModel.messages,
                    isTyping: viewModel.isTyping,
                    isKeyboardVisible: keyboard.isVisible,
                    onToggleSpeech: { message in
                        viewModel.toggleSpeechForMessage(message.content)
                    },
                    onSelectSuggestion: { suggestion in
                        viewModel.sendMessage(suggestion)
                    },
                    onIntroduceSarah: {
                        viewModel.introduceSarah()
                    },
                    onDismissKeyboard: {
                        keyboard.dismiss()
                    },
                    onOpenStudio: {
                        viewModel.isShowingVAICodingStudio = true
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { keyboard.dismiss() }
            }
        }
        // SwiftUI remonte automatiquement cet inset au-dessus du clavier.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composerDock
        }
        .photosPicker(
            isPresented: $isShowingPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .onChange(of: selectedPhotoItem) { item in
            analyzeSelectedPhoto(item)
        }
        .sheet(isPresented: $isShowingCamera) {
            SarahCameraPicker { image in
                isShowingCamera = false
                if let image { handleCameraImage(image) }
            }
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { viewModel.appendImportedFile(url: url) }
            case .failure(let error):
                viewModel.inputText = "Impossible d'ouvrir le fichier : \(error.localizedDescription)"
            }
        }
        .fullScreenCover(isPresented: $viewModel.isShowingVAICodingStudio) {
            VAICodingStudioView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isShowingWebsiteBuilder) {
            WebsiteBuilderFlowView(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $isShowingVoiceCallScreen) {
            VoiceCallScreenView()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SarahPresentVoiceCallModal"))) { _ in
            isShowingVoiceCallScreen = true
        }
        .actionSheet(isPresented: $isShowingActionSheet) {
            ActionSheet(
                title: Text("SarahIA"),
                message: Text("Outils et agents"),
                buttons: [
                    .default(Text("📞 Appel vocal")) {
                        if WebRTCVoiceCallManager.shared.callState == .idle,
                           let contact = VoiceCallContactManager.shared.contacts.first {
                            WebRTCVoiceCallManager.shared.startOutboundCall(to: contact)
                        }
                        isShowingVoiceCallScreen = true
                    },
                    .default(Text("💻 Studio Raphaël")) {
                        viewModel.activeAgent = .esther
                        viewModel.isShowingVAICodingStudio = true
                    },
                    .default(Text("👁️ Vision & OCR")) {
                        viewModel.inputText = "Analyse cette photo : "
                    },
                    .default(Text("🎨 Image")) {
                        viewModel.inputText = "Génère une image de "
                    },
                    .default(Text("🎵 Musique")) {
                        viewModel.inputText = "Compose une musique "
                    },
                    .default(Text("🇮🇱 Yohan · Traduction")) {
                        viewModel.activeAgent = .yohan
                        viewModel.inputText = "Traduis en hébreu : "
                    },
                    .default(Text("🌍 Tom · Histoire")) {
                        viewModel.activeAgent = .tom
                        viewModel.inputText = "Explique-moi "
                    },
                    .default(Text("🎙️ Mode vocal Sarah")) {
                        keyboard.dismiss()
                        viewModel.isShowingVoiceOrbModal = true
                    },
                    .cancel(Text("Fermer"))
                ]
            )
        }
    }

    private var modernBackground: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [viewModel.activeAgent.themeColor.opacity(0.16), Color.clear],
                center: .top,
                startRadius: 8,
                endRadius: 440
            )
            LinearGradient(
                colors: [Color.white.opacity(0.035), Color.clear, Color.black.opacity(0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }

    private var composerDock: some View {
        MessageBar(
            text: $viewModel.inputText,
            activeAgent: $viewModel.activeAgent,
            isRecording: viewModel.isMicRunning,
            isProcessing: viewModel.isGeneratingResponse,
            onOpenPhotoLibrary: {
                keyboard.dismiss()
                selectedPhotoItem = nil
                isShowingPhotoPicker = true
            },
            onOpenCamera: {
                keyboard.dismiss()
                isShowingCamera = true
            },
            onOpenFile: {
                keyboard.dismiss()
                isShowingFileImporter = true
            },
            onSend: { text in viewModel.sendMessage(text) },
            onCancel: { viewModel.cancelCurrentGeneration() },
            onToggleMic: { viewModel.toggleMicrophone() },
            onOpenVoiceOrb: {
                keyboard.dismiss()
                viewModel.isShowingVoiceOrbModal = true
            },
            onOpenVAICoding: {
                viewModel.isShowingVAICodingStudio = true
            }
        )
        .padding(.top, 3)
        .padding(.bottom, 6)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [Color.white.opacity(0.16), Color.white.opacity(0.025), Color.clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 0.7)
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            glassCircleButton(systemName: "line.3.horizontal") {
                HapticService.shared.buttonTap()
                keyboard.dismiss()
                viewModel.openDrawer()
            }

            Spacer(minLength: 4)

            Menu {
                Button("Sarah") { viewModel.activeAgent = .sarah }
                Button("Raphaël") { viewModel.activeAgent = .esther }
                Button("Yohan") { viewModel.activeAgent = .yohan }
                Button("Tom") { viewModel.activeAgent = .tom }
                Divider()
                Button("Outils") { isShowingActionSheet = true }
            } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(viewModel.activeAgent.themeColor)
                        .frame(width: 8, height: 8)
                        .shadow(color: viewModel.activeAgent.themeColor.opacity(0.8), radius: 5)
                    Text(viewModel.activeAgent.displayName)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.55))
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
                .sarahLiquidGlass(
                    cornerRadius: 22,
                    tint: viewModel.activeAgent.themeColor,
                    intensity: 0.12
                )
            }
            .buttonStyle(PlainButtonStyle())

            Spacer(minLength: 4)

            glassCircleButton(systemName: "gearshape.fill") {
                HapticService.shared.buttonTap()
                keyboard.dismiss()
                isShowingSettings = true
            }
        }
    }

    private func glassCircleButton(
        systemName: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .sarahLiquidGlass(
                    cornerRadius: 22,
                    tint: viewModel.activeAgent.themeColor,
                    intensity: 0.10
                )
        }
        .buttonStyle(ScaleBounceButtonStyle())
    }
}

/// Brief utilisé par la détection de demandes de création de site.
public struct WebsiteBrief {
    public var category: String
    public var name: String
    public var purpose: String
    public var audience: String
    public var visualStyle: String
    public var accent: String
    public var sections: [String]

    public init(
        category: String,
        name: String,
        purpose: String,
        audience: String,
        visualStyle: String,
        accent: String,
        sections: [String]
    ) {
        self.category = category
        self.name = name
        self.purpose = purpose
        self.audience = audience
        self.visualStyle = visualStyle
        self.accent = accent
        self.sections = sections
    }

    public static func shouldOpenBuilder(for text: String) -> Bool {
        let normalized = text.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: .current
        )
        let creationWords = [
            "site internet", "site web", "site e-commerce", "site ecommerce",
            "genere un site", "creer un site", "creation de site",
            "fabrique un site", "faire un site", "lance un site"
        ]
        return creationWords.contains { normalized.contains($0) } || isRefinementRequest(text)
    }

    public static func isRefinementRequest(_ text: String) -> Bool {
        let normalized = text.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: .current
        )
        let words = [
            "ameliore le site", "ameliorer le site", "modifie le site",
            "modifier le site", "refais le site", "maquette"
        ]
        return words.contains { normalized.contains($0) }
    }
}

/// Parcours volontairement léger : il prépare un brief puis ouvre Raphaël.
@available(iOS 15.0, *)
private struct WebsiteBuilderFlowView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var category = "Entreprise"
    @State private var name = ""
    @State private var purpose = ""
    @State private var visualStyle = "Apple épuré"

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Créer un site")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)

                        Text("Raphaël prépare une maquette locale. Rien n'est publié automatiquement.")
                            .foregroundColor(.white.opacity(0.58))

                        builderField("Type de site", text: $category)
                        builderField("Nom du site", text: $name)
                        builderField("Objectif", text: $purpose)
                        builderField("Style visuel", text: $visualStyle)

                        Button {
                            generate()
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Créer avec Raphaël")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .sarahLiquidGlass(cornerRadius: 18, tint: .sarahCyan, intensity: 0.16)
                        }
                        .buttonStyle(ScaleBounceButtonStyle())
                    }
                    .padding(24)
                }
            }
            .navigationBarHidden(true)
        }
    }

    private func builderField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .foregroundColor(.white)
            .padding(.horizontal, 15)
            .frame(height: 50)
            .sarahLiquidGlass(cornerRadius: 16, tint: .white, intensity: 0.06)
    }

    private func generate() {
        let finalName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalPurpose = purpose.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = "Raphaël, crée une première maquette locale pour un site \(category), nom \(finalName.isEmpty ? "à proposer" : finalName), objectif \(finalPurpose.isEmpty ? "à préciser" : finalPurpose), style \(visualStyle). Ne publie rien sans mon accord."

        viewModel.activeAgent = .esther
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            viewModel.isShowingVAICodingStudio = true
            viewModel.sendMessage(prompt)
        }
    }
}

/// Sélecteur UIKit minimal utilisé par le bouton appareil photo.
@available(iOS 15.0, *)
private struct SarahCameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onImage: (UIImage?) -> Void

        init(onImage: @escaping (UIImage?) -> Void) {
            self.onImage = onImage
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            onImage(info[.originalImage] as? UIImage)
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImage(nil)
            picker.dismiss(animated: true)
        }
    }
}
