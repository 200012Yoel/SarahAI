import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

/// Écran principal SarahIA. Le mode vocal plein écran reste volontairement isolé
/// de la couche visuelle afin que les évolutions Liquid Glass ne cassent pas sa logique.
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
                    DispatchQueue.main.async { viewModel.appendVisionAnalysis(image: image, result: result) }
                }
            } catch {
                await MainActor.run { viewModel.inputText = "Impossible d'ouvrir la photo : \(error.localizedDescription)" }
            }
        }
    }

    private func handleCameraImage(_ image: UIImage) {
        LocalVisionEngine.shared.recognizeObject(in: image) { result in
            DispatchQueue.main.async { viewModel.appendVisionAnalysis(image: image, result: result) }
        }
    }

    private var topSafeArea: CGFloat {
        let window = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow }) ?? ($0 as? UIWindowScene)?.windows.first }
            .first
        return max(window?.safeAreaInsets.top ?? 20, 20)
    }

    public var body: some View {
        ZStack {
            modernBackground

            VStack(spacing: 0) {
                topBar
                    .padding(.top, topSafeArea + 2)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)

                MessageList(
                    messages: viewModel.messages,
                    isTyping: viewModel.isTyping,
                    isKeyboardVisible: keyboard.isVisible,
                    onToggleSpeech: { viewModel.toggleSpeechForMessage($0.content) },
                    onSelectSuggestion: { viewModel.sendMessage($0) },
                    onIntroduceSarah: { viewModel.introduceSarah() },
                    onDismissKeyboard: { keyboard.dismiss() },
                    onOpenStudio: { viewModel.isShowingVAICodingStudio = true }
                )
                .contentShape(Rectangle())
                .onTapGesture { keyboard.dismiss() }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composerDock
        }
        // IMPORTANT : conserver le vrai mode vocal retrouvé en plein écran.
        .fullScreenCover(isPresented: $viewModel.isShowingVoiceOrbModal) {
            VoiceOrbModalView(
                viewModel: viewModel,
                onOpenMenu: { viewModel.openDrawer() },
                onOpenSettings: { isShowingSettings = true }
            )
        }
        .photosPicker(isPresented: $isShowingPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { analyzeSelectedPhoto($0) }
        .sheet(isPresented: $isShowingCamera) {
            SarahCameraPicker { image in
                isShowingCamera = false
                if let image { handleCameraImage(image) }
            }
        }
        .fileImporter(isPresented: $isShowingFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
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
                    .default(Text("👁️ Vision & OCR")) { viewModel.inputText = "Analyse cette photo : " },
                    .default(Text("🎨 Image")) { viewModel.inputText = "Génère une image de " },
                    .default(Text("🎵 Musique")) { viewModel.inputText = "Compose une musique " },
                    .default(Text("🇮🇱 Yohan · Traduction")) {
                        viewModel.activeAgent = .yohan
                        viewModel.inputText = "Traduis en hébreu : "
                    },
                    .default(Text("🌍 Tom · Histoire")) {
                        viewModel.activeAgent = .tom
                        viewModel.inputText = "Explique-moi "
                    },
                    .default(Text("🎙️ Mode vocal Sarah")) {
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
                startRadius: 10,
                endRadius: 430
            )
            LinearGradient(
                colors: [Color.white.opacity(0.035), Color.clear, Color.black.opacity(0.24)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }

    private var composerDock: some View {
        VStack(spacing: 0) {
            MessageBar(
                text: $viewModel.inputText,
                activeAgent: $viewModel.activeAgent,
                isRecording: viewModel.isMicRunning,
                isProcessing: viewModel.isGeneratingResponse,
                onOpenPhotoLibrary: {
                    keyboard.dismiss(); selectedPhotoItem = nil; isShowingPhotoPicker = true
                },
                onOpenCamera: {
                    keyboard.dismiss(); isShowingCamera = true
                },
                onOpenFile: {
                    keyboard.dismiss(); isShowingFileImporter = true
                },
                onSend: { viewModel.sendMessage($0) },
                onCancel: { viewModel.cancelCurrentGeneration() },
                onToggleMic: { viewModel.toggleMicrophone() },
                onOpenVoiceOrb: {
                    keyboard.dismiss()
                    viewModel.isShowingVoiceOrbModal = true
                },
                onOpenVAICoding: { viewModel.isShowingVAICodingStudio = true }
            )
        }
        .padding(.top, 3)
        .padding(.bottom, keyboard.isVisible ? 6 : 8)
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
                .sarahLiquidGlass(cornerRadius: 22, tint: viewModel.activeAgent.themeColor, intensity: 0.12)
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

    private func glassCircleButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .sarahLiquidGlass(cornerRadius: 22, tint: viewModel.activeAgent.themeColor, intensity: 0.10)
        }
        .buttonStyle(ScaleBounceButtonStyle())
    }
}

/// Brief conservé entre une première maquette et ses améliorations.
public struct WebsiteBrief {
    public var category: String
    public var name: String
    public var purpose: String
    public var audience: String
    public var visualStyle: String
    public var accent: String
    public var sections: [String]

    public init(category: String, name: String, purpose: String, audience: String, visualStyle: String, accent: String, sections: [String]) {
        self.category = category
        self.name = name
        self.purpose = purpose
        self.audience = audience
        self.visualStyle = visualStyle
        self.accent = accent
        self.sections = sections
    }

    public static func shouldOpenBuilder(for text: String) -> Bool {
        let normalized = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let creationWords = ["site internet", "site web", "site e-commerce", "site ecommerce", "genere un site", "creer un site", "creation de site", "fabrique un site", "faire un site", "lance un site"]
        return creationWords.contains { normalized.contains($0) } || isRefinementRequest(text)
    }

    public static func isRefinementRequest(_ text: String) -> Bool {
        let normalized = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return ["ameliore le site", "ameliorer le site", "modifie le site", "modifier le site", "refais le site", "maquette"].contains { normalized.contains($0) }
    }
}

@available(iOS 15.0, *)
private struct WebsiteBuilderFlowView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0
    @State private var category: String
    @State private var name: String
    @State private var purpose: String
    @State private var audience: String
    @State private var visualStyle: String
    @State private var accent: String
    @State private var sections: Set<String>

    private let categories = [
        WebsiteChoice(title: "E-commerce", icon: "bag.fill", detail: "Vendre des produits"),
        WebsiteChoice(title: "Voyage", icon: "airplane", detail: "Inspirer et réserver"),
        WebsiteChoice(title: "Restaurant", icon: "fork.knife", detail: "Menu et réservation"),
        WebsiteChoice(title: "Portfolio", icon: "person.crop.rectangle", detail: "Présenter son travail"),
        WebsiteChoice(title: "Entreprise", icon: "building.2.fill", detail: "Présenter une activité")
    ]
    private let styles = ["Apple épuré", "Éditorial", "Minimal sombre", "Coloré", "Premium"]
    private let accents = ["Bleu", "Violet", "Vert", "Orange", "Rose", "Monochrome"]
    private let availableSections = ["Accueil", "À propos", "Services", "Produits", "Galerie", "Témoignages", "FAQ", "Contact"]

    init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
        let brief = viewModel.websiteBrief ?? WebsiteBrief(category: "Entreprise", name: "", purpose: "", audience: "", visualStyle: "Apple épuré", accent: "Bleu", sections: ["Accueil", "À propos", "Services", "Contact"])
        _category = State(initialValue: brief.category)
        _name = State(initialValue: brief.name)
        _purpose = State(initialValue: brief.purpose)
        _audience = State(initialValue: brief.audience)
        _visualStyle = State(initialValue: brief.visualStyle)
        _accent = State(initialValue: brief.accent)
        _sections = State(initialValue: Set(brief.sections))
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text("Créer un site")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        Text("Raphaël prépare une maquette locale. Rien n'est publié sans ton accord.")
                            .foregroundColor(.gray)

                        Group {
                            if step == 0 { categoryStep }
                            else if step == 1 { identityStep }
                            else if step == 2 { styleStep }
                            else { summaryStep }
                        }

                        HStack {
                            if step > 0 {
                                Button("Retour") { withAnimation { step -= 1 } }
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            Button(step < 3 ? "Continuer" : "Générer la maquette") {
                                if step < 3 { withAnimation { step += 1 } } else { generate() }
                            }
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(24)
                }
            }
            .navigationBarHidden(true)
        }
    }

    private var categoryStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quel type de site ?").font(.title2.bold()).foregroundColor(.white)
            ForEach(categories) { choice in
                Button { category = choice.title } label: {
                    HStack(spacing: 14) {
                        Image(systemName: choice.icon).frame(width: 28)
                        VStack(alignment: .leading) {
                            Text(choice.title).font(.headline)
                            Text(choice.detail).font(.caption).foregroundColor(.gray)
                        }
                        Spacer()
                        if category == choice.title { Image(systemName: "checkmark.circle.fill") }
                    }
                    .foregroundColor(.white)
                    .padding(16)
                    .background(Color.white.opacity(category == choice.title ? 0.12 : 0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    private var identityStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Parle-moi du projet").font(.title2.bold()).foregroundColor(.white)
            builderField("Nom du site", text: $name)
            builderField("Objectif principal", text: $purpose)
            builderField("Public visé", text: $audience)
        }
    }

    private var styleStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Direction visuelle").font(.title2.bold()).foregroundColor(.white)
            Text("Style").font(.headline).foregroundColor(.white)
            choiceChips(styles, selection: $visualStyle)
            Text("Couleur d'accent").font(.headline).foregroundColor(.white)
            choiceChips(accents, selection: $accent)
            Text("Sections").font(.headline).foregroundColor(.white)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 10) {
                ForEach(availableSections, id: \.self) { section in
                    Button {
                        if sections.contains(section) { sections.remove(section) } else { sections.insert(section) }
                    } label: {
                        Text(section).font(.caption.bold()).frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(Color.white.opacity(sections.contains(section) ? 0.18 : 0.06))
                            .clipShape(Capsule()).foregroundColor(.white)
                    }
                }
            }
        }
    }

    private var summaryStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prêt pour la première maquette").font(.title2.bold()).foregroundColor(.white)
            summary("Type", category); summary("Nom", name.isEmpty ? "À proposer" : name)
            summary("Objectif", purpose.isEmpty ? "À préciser" : purpose)
            summary("Public", audience.isEmpty ? "Grand public" : audience)
            summary("Style", visualStyle); summary("Accent", accent)
            summary("Sections", sections.sorted().joined(separator: ", "))
        }
        .padding(18).background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func builderField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text).foregroundColor(.white).padding(14)
            .background(Color.white.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func choiceChips(_ values: [String], selection: Binding<String>) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 10) {
            ForEach(values, id: \.self) { value in
                Button { selection.wrappedValue = value } label: {
                    Text(value).font(.caption.bold()).frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Color.white.opacity(selection.wrappedValue == value ? 0.18 : 0.06))
                        .clipShape(Capsule()).foregroundColor(.white)
                }
            }
        }
    }

    private func summary(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundColor(.gray).frame(width: 82, alignment: .leading)
            Text(value).foregroundColor(.white)
            Spacer()
        }
    }

    private func generate() {
        let brief = WebsiteBrief(category: category, name: name, purpose: purpose, audience: audience, visualStyle: visualStyle, accent: accent, sections: sections.sorted())
        viewModel.websiteBrief = brief
        viewModel.activeAgent = .esther
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            viewModel.isShowingVAICodingStudio = true
            viewModel.sendMessage("Raphaël, crée une première maquette locale pour ce site : \(category), nom \(name.isEmpty ? "à proposer" : name), objectif \(purpose), public \(audience), style \(visualStyle), accent \(accent), sections \(sections.sorted().joined(separator: ", ")). Ne publie rien sans mon accord.")
        }
    }
}

private struct WebsiteChoice: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let detail: String
}
