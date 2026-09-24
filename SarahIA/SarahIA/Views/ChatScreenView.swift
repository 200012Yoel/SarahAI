import SwiftUI
import PhotosUI
import AVKit
import AVFoundation
import CoreTransferable
import UniformTypeIdentifiers
import QuartzCore

/// Écran principal de discussion 100% natif SwiftUI avec interface multi-agents,
/// disposition fixe Header / Messages / Barre basse au-dessus du clavier,
/// Voice Orb plein écran et Studio VAI Coding.
@available(iOS 15.0, *)
public struct ChatScreenView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject private var keyboard = KeyboardObserver.shared
    @Binding var isShowingSettings: Bool
    
    @State private var isShowingCamera = false
    @State private var isShowingFilePicker = false
    @State private var attachmentError: String?
    @State private var isShowingVoiceCallScreen: Bool = false
    @State private var isShowingAgentPicker: Bool = false
    @State private var isShowingVisionPicker: Bool = false
    @State private var selectedVisionItem: PhotosPickerItem? = nil
    @State private var isShowingNathanVideoPicker: Bool = false
    @State private var selectedNathanVideoItem: PhotosPickerItem? = nil
    @State private var nathanEditorVideoURL: URL? = nil
    @State private var isShowingNathanVideoEditor: Bool = false
    
    public init(viewModel: ChatViewModel, isShowingSettings: Binding<Bool>) {
        self.viewModel = viewModel
        self._isShowingSettings = isShowingSettings
    }
    
    private func analyzeSelectedVisionItem(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    await MainActor.run {
                        viewModel.inputText = "Impossible de lire cette image."
                    }
                    return
                }

                LocalVisionEngine.shared.recognizeObject(in: image) { result in
                    viewModel.appendVisionAnalysis(image: image, result: result)
                }
            } catch {
                await MainActor.run {
                    viewModel.inputText = "Impossible d'ouvrir la photo : \(error.localizedDescription)"
                }
            }
        }
    }

    private func loadSelectedNathanVideo(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            do {
                guard let movie = try await item.loadTransferable(type: SarahPickedMovie.self) else {
                    return
                }
                await MainActor.run {
                    viewModel.activeAgent = .nathan
                    nathanEditorVideoURL = movie.url
                    isShowingNathanVideoEditor = true
                }
            } catch {
                await MainActor.run {
                    viewModel.inputText = "Impossible d'ouvrir cette vidéo : \(error.localizedDescription)"
                }
            }
        }
    }

    private var topSafeArea: CGFloat {
        if #available(iOS 13.0, *) {
            let window = UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow }) ?? ($0 as? UIWindowScene)?.windows.first }
                .first
            if let top = window?.safeAreaInsets.top, top > 0 {
                return top
            }
        }
        return 20
    }
    
    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.top, 6)
                    .padding(.bottom, 6)

                if let transition = viewModel.agentTransitionBanner {
                    HStack(spacing: 7) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .semibold))
                        Text(transition)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .sarahLiquidGlass(
                        cornerRadius: 17,
                        tint: viewModel.activeAgent.themeColor,
                        intensity: 0.12
                    )
                    .padding(.bottom, 5)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                MessageList(
                    messages: viewModel.messages,
                    isTyping: viewModel.isTyping,
                    isKeyboardVisible: keyboard.isVisible,
                    onToggleSpeech: { message in
                        viewModel.toggleSpeechForMessage(message.content)
                    },
                    onSelectSuggestion: { suggestionText in
                        viewModel.sendMessage(suggestionText)
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
                .onTapGesture {
                    keyboard.dismiss()
                }
            }
        }
        // Laisser SwiftUI gérer le clavier évite le double décalage observé sur iOS 27.
        // Le dock reste toujours juste au-dessus du clavier, quel que soit l'iPhone.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                if viewModel.isContinuousConversationActive && !viewModel.isShowingVoiceOrbModal {
                    HStack {
                        Spacer(minLength: 18)
                        CollapsedVoiceSessionBar(viewModel: viewModel)
                            .frame(maxWidth: 286)
                        Spacer(minLength: 18)
                    }
                    .padding(.bottom, 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                MessageBar(
                    text: $viewModel.inputText,
                    activeAgent: $viewModel.activeAgent,
                    isRecording: viewModel.isMicRunning,
                    isProcessing: viewModel.isGeneratingResponse,
                    onOpenActions: {
                        keyboard.dismiss()
                        isShowingVisionPicker = true
                    },
                    onOpenCamera: {
                        keyboard.dismiss()
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            isShowingCamera = true
                        } else {
                            attachmentError = "L’appareil photo n’est pas disponible sur cet appareil."
                        }
                    },
                    onOpenFile: {
                        keyboard.dismiss()
                        isShowingFilePicker = true
                    },
                    onSend: { text in
                        viewModel.sendMessage(text)
                    },
                    onCancel: {
                        viewModel.cancelCurrentGeneration()
                    },
                    onToggleMic: {
                        viewModel.toggleMicrophone()
                    },
                    onOpenVoiceOrb: {
                        viewModel.finishDictation()
                        keyboard.dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            viewModel.isShowingVoiceOrbModal = true
                        }
                    },
                    onOpenVAICoding: {
                        viewModel.isShowingVAICodingStudio = true
                    }
                )
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.02),
                        Color.black.opacity(0.68)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            )
        }
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("--sarah-ui-smoke-voice") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    viewModel.isShowingVoiceOrbModal = true
                }
            }

            if ProcessInfo.processInfo.arguments.contains("--sarah-ui-smoke-developer") {
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8 + Double(index) * 0.45) {
                        viewModel.sendMessage(answer)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            SarahCameraPicker { image in
                isShowingCamera = false
                if let image {
                    LocalVisionEngine.shared.recognizeObject(in: image) { result in
                        viewModel.appendVisionAnalysis(image: image, result: result)
                    }
                }
            }.ignoresSafeArea()
        }
        .fileImporter(isPresented: $isShowingFilePicker, allowedContentTypes: [.text, .image], allowsMultipleSelection: false) { result in
            do {
                guard let url = try result.get().first else { return }
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                let values = try url.resourceValues(forKeys: [.fileSizeKey])
                guard (values.fileSize ?? 0) <= 10_000_000 else {
                    attachmentError = "Choisis un fichier de moins de 10 Mo."
                    return
                }
                let data = try Data(contentsOf: url)
                if let image = UIImage(data: data) {
                    LocalVisionEngine.shared.recognizeObject(in: image) { result in
                        viewModel.appendVisionAnalysis(image: image, result: result)
                    }
                } else if let text = String(data: data, encoding: .utf8) {
                    viewModel.inputText += "\n\nFichier : \(url.lastPathComponent)\n" + text
                } else {
                    attachmentError = "Ce fichier texte doit être encodé en UTF-8."
                }
            } catch { attachmentError = error.localizedDescription }
        }
        .alert("Pièce jointe", isPresented: Binding(get: { attachmentError != nil }, set: { if !$0 { attachmentError = nil } })) {
            Button("OK") { attachmentError = nil }
        } message: { Text(attachmentError ?? "") }
        .fullScreenCover(isPresented: $viewModel.isShowingVoiceOrbModal) {
            voiceSheetContent
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
        .photosPicker(
            isPresented: $isShowingVisionPicker,
            selection: $selectedVisionItem,
            matching: .images
        )
        .onChange(of: selectedVisionItem) { item in
            analyzeSelectedVisionItem(item)
        }
        .photosPicker(
            isPresented: $isShowingNathanVideoPicker,
            selection: $selectedNathanVideoItem,
            matching: .videos
        )
        .onChange(of: selectedNathanVideoItem) { item in
            loadSelectedNathanVideo(item)
        }
        .fullScreenCover(isPresented: $isShowingNathanVideoEditor) {
            if let sourceURL = nathanEditorVideoURL {
                NathanVideoEditorView(sourceURL: sourceURL, viewModel: viewModel)
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SarahPresentVoiceCallModal"))) { _ in
            isShowingVoiceCallScreen = true
        }
        .confirmationDialog(
            "Choisir un agent",
            isPresented: $isShowingAgentPicker,
            titleVisibility: .visible
        ) {
            ForEach(AgentType.allCases) { agent in
                Button("\(agent.displayName) · \(agent.specialtySubtitle)") {
                    viewModel.selectAgent(agent)
                }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Le changement est instantané et la conversation reste la même.")
        }
    }

    @ViewBuilder
    private var voiceSheetContent: some View {
        if #available(iOS 16.0, *) {
            VoiceOrbModalView(
                viewModel: viewModel,
                onOpenMenu: {
                    viewModel.openDrawer()
                },
                onOpenSettings: {
                    isShowingSettings = true
                }
            )

        } else {
            VoiceOrbModalView(
                viewModel: viewModel,
                onOpenMenu: {
                    viewModel.openDrawer()
                },
                onOpenSettings: {
                    isShowingSettings = true
                }
            )
        }
    }

    // MARK: - Topbar
    
    private var topBar: some View {
        HStack(alignment: .center) {
            // Bouton Menu Tiroir (Sidebar)
            Button(action: {
                HapticService.shared.buttonTap()
                keyboard.dismiss()
                viewModel.openDrawer()
            }) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        ZStack {
                            Circle().fill(.ultraThinMaterial)
                            Circle().fill(viewModel.activeAgent.themeColor.opacity(0.08))
                            Circle().stroke(Color.white.opacity(0.16), lineWidth: 0.8)
                        }
                    )
            }
            .buttonStyle(ScaleBounceButtonStyle())
            .accessibilityLabel("Ouvrir le menu")
            .accessibilityIdentifier("chat.menu")
            
            Spacer()
            
            // Titre de l'agent actif (centre)
            Button(action: {
                HapticService.shared.buttonTap()
                keyboard.dismiss()
                isShowingAgentPicker = true
            }) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(viewModel.activeAgent.themeColor)
                        .frame(width: 8, height: 8)

                    Text(viewModel.activeAgent.displayName)
                        .font(.headline)
                        .foregroundColor(.white)

                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.55))
                }
                .padding(.horizontal, 13)
                .frame(height: 40)
                .sarahLiquidGlass(
                    cornerRadius: 20,
                    tint: viewModel.activeAgent.themeColor,
                    intensity: 0.08
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Bouton Chat : crée immédiatement une nouvelle discussion.
            Button(action: {
                HapticService.shared.buttonTap()
                keyboard.dismiss()
                viewModel.startNewChat(silently: true)
            }) {
                HStack(spacing: 7) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 16, weight: .semibold))

                    Text("Chat")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 13)
                .frame(height: 42)
                .sarahLiquidGlass(
                    cornerRadius: 21,
                    tint: viewModel.activeAgent.themeColor,
                    intensity: 0.08
                )
            }
            .buttonStyle(ScaleBounceButtonStyle())
            .accessibilityLabel("Nouveau chat")
        }
        .padding(.horizontal, 16)
    }
}

@available(iOS 15.0, *)
private struct CollapsedVoiceSessionBar: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var pulse = false

    private var accent: Color {
        viewModel.activeAgent.themeColor
    }

    private var status: String {
        switch viewModel.voiceStatus {
        case .starting:
            return "Activation du micro…"
        case .processing:
            return "Réflexion…"
        case .speaking:
            return "Sarah parle"
        case .error:
            return "Micro indisponible"
        default:
            return viewModel.isVoiceMicrophoneMuted ? "Micro coupé" : "À l’écoute"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                HapticService.shared.buttonTap()
                viewModel.isShowingVoiceOrbModal = true
            } label: {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.22))
                        .frame(width: 34, height: 34)

                    Circle()
                        .stroke(accent.opacity(0.62), lineWidth: 1)
                        .frame(width: 34, height: 34)
                        .scaleEffect(pulse ? 1.08 : 0.94)
                        .opacity(pulse ? 0.28 : 0.82)

                    Image(systemName: "waveform")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Rouvrir le mode vocal")

            Text(status)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 2)

            Button {
                HapticService.shared.buttonTap()
                viewModel.toggleMicrophone()
            } label: {
                Image(systemName: viewModel.isVoiceMicrophoneMuted ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(viewModel.isVoiceMicrophoneMuted ? .white.opacity(0.62) : .white)
                    .frame(width: 34, height: 34)
                    .background(
                        ZStack {
                            Circle().fill(.ultraThinMaterial)
                            Circle().fill(accent.opacity(viewModel.isVoiceMicrophoneMuted ? 0.06 : 0.14))
                            Circle().stroke(Color.white.opacity(0.16), lineWidth: 0.7)
                        }
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(viewModel.isVoiceMicrophoneMuted ? "Réactiver le micro" : "Couper le micro")

            Button {
                HapticService.shared.buttonTap()
                viewModel.endVoiceConversation()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(
                        ZStack {
                            Circle().fill(.ultraThinMaterial)
                            Circle().fill(accent.opacity(0.22))
                            Circle().stroke(accent.opacity(0.38), lineWidth: 0.8)
                        }
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Arrêter le mode vocal")
        }
        .padding(.leading, 10)
        .padding(.trailing, 8)
        .frame(height: 50)
        .sarahLiquidGlass(
            cornerRadius: 25,
            tint: accent,
            intensity: 0.15
        )
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: 1.05)
                    .repeatForever(autoreverses: true)
            ) {
                pulse = true
            }
        }
    }
}

/// Brief conservé entre une première maquette et ses améliorations.
/// Il ne représente jamais un site déjà publié : le rendu est d'abord local dans le Studio VAI.
public struct WebsiteBrief: Codable, Equatable {
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

    public static func inferred(from prompt: String) -> WebsiteBrief {
        let normalized = prompt.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: .current
        )

        let category: String
        if normalized.contains("boutique") || normalized.contains("e-commerce") || normalized.contains("ecommerce") {
            category = "E-commerce"
        } else if normalized.contains("restaurant") {
            category = "Restaurant"
        } else if normalized.contains("portfolio") {
            category = "Portfolio"
        } else {
            category = "Site web"
        }

        let style = normalized.contains("apple") || normalized.contains("liquid glass")
            ? "Apple / Liquid Glass"
            : "Moderne"

        return WebsiteBrief(
            category: category,
            name: "Projet de cette discussion",
            purpose: prompt,
            audience: "Grand public",
            visualStyle: style,
            accent: "Bleu",
            sections: ["Accueil", "Produits / services", "À propos", "Contact"]
        )
    }

    public static func looksLikeWebsiteFollowUp(_ text: String) -> Bool {
        let normalized = text.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: .current
        )

        let referencesWebsite = [
            "le site", "ce site", "mon site", "ton site", "le site que tu as cree",
            "la page", "cette page", "la maquette", "le projet web", "landing page"
        ].contains { normalized.contains($0) }

        let continuationWords = [
            "ameliore", "modifie", "change", "ajoute", "rajoute", "retire",
            "enleve", "supprime", "remplace", "rends", "refais", "continue",
            "mets", "augmente", "reduis", "anime", "corrige"
        ].contains { normalized.contains($0) }

        return isRefinementRequest(text)
            || referencesWebsite
            || (continuationWords && normalized.count < 180)
    }

    public static func isAppleInspiredCreationRequest(_ text: String) -> Bool {
        let normalized = text.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: .current
        )

        let wantsSite = [
            "site", "page web", "landing page", "site internet", "site web"
        ].contains { normalized.contains($0) }

        let wantsAppleStyle = [
            "comme apple", "style apple", "inspire d apple", "inspire de apple",
            "a la apple", "apple-like", "apple like"
        ].contains { normalized.contains($0) }

        return wantsSite && wantsAppleStyle
    }

    public static func appleInspired(from prompt: String) -> WebsiteBrief {
        WebsiteBrief(
            category: "Site premium",
            name: "Nouveau projet",
            purpose: prompt,
            audience: "Grand public",
            visualStyle: "Apple / Liquid Glass",
            accent: "Bleu",
            sections: [
                "Accueil",
                "Produits / services",
                "À propos",
                "Galerie",
                "Contact"
            ]
        )
    }

    public static func shouldOpenBuilder(for text: String) -> Bool {
        let normalized = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let creationWords = [
            "site internet", "site web", "site e-commerce", "site ecommerce",
            "genere un site", "creer un site", "creation de site", "fabrique un site",
            "faire un site", "lance un site"
        ]
        return creationWords.contains { normalized.contains($0) } || isRefinementRequest(text)
    }

    public static func isContextualRefinementRequest(_ text: String) -> Bool {
        let normalized = text.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: .current
        )

        let actions = [
            "ameliore", "améliore", "modifie", "change", "ajoute", "rajoute",
            "retire", "enleve", "supprime", "remplace", "rends", "refais",
            "plus anime", "plus moderne", "plus beau", "plus premium",
            "mets le bouton", "mets la couleur", "change la couleur",
            "agrandis", "reduis", "corrige", "continue"
        ]

        return actions.contains { normalized.contains($0) }
    }

    public static func isRefinementRequest(_ text: String) -> Bool {
        let normalized = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return [
            "ameliore le site", "ameliorer le site", "ameliore ce site",
            "ameliore le site que tu as cree", "ameliore celui que tu as cree",
            "modifie le site", "modifier le site", "refais le site",
            "continue le site", "reprends le site", "maquette"
        ].contains {
            normalized.contains($0)
        }
    }
}

/// Parcours de création inspiré des assistants de conception : choix, questions courtes,
/// puis génération d'une première maquette HTML locale avec Raphaël.
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
        WebsiteChoice(title: "Entreprise", icon: "building.2.fill", detail: "Services et contact"),
        WebsiteChoice(title: "Événement", icon: "calendar", detail: "Informer et inscrire")
    ]

    private let audiences = ["Grand public", "Professionnels", "Familles", "Jeunes adultes", "Clients locaux", "International"]
    private let styles = ["Apple / Liquid Glass", "Minimaliste", "Élégant", "Énergique", "Luxe", "Naturel", "Tech"]
    private let accentOptions = ["Bleu", "Violet", "Rose", "Orange", "Vert", "Noir & blanc"]
    private let sectionOptions = ["Accueil", "À propos", "Produits / services", "Galerie", "Avis clients", "FAQ", "Contact"]

    init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
        let draft = viewModel.websiteDraft
        _category = State(initialValue: draft?.category ?? "")
        _name = State(initialValue: draft?.name ?? "")
        _purpose = State(initialValue: draft?.purpose ?? "")
        _audience = State(initialValue: draft?.audience ?? "")
        _visualStyle = State(initialValue: draft?.visualStyle ?? "")
        _accent = State(initialValue: draft?.accent ?? "Violet")
        _sections = State(initialValue: Set(draft?.sections ?? ["Accueil", "À propos", "Contact"]))
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        progress
                        questionContent
                        navigationButtons
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") { dismiss() }
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .principal) {
                    Text("Raphaël · Créateur de site")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(step == 3 ? "Prêt à créer" : "Construisons ton site")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(step == 3
                 ? "Raphaël va créer une première maquette locale. Tu pourras ensuite lui demander toutes les améliorations que tu veux."
                 : "Réponds à ces quatre questions courtes. Les choix servent à préparer une première version cohérente.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Question \(step + 1) sur 4")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.purple)
                Spacer()
                Text("\((step + 1) * 25) %")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            ProgressView(value: Double(step + 1), total: 4)
                .tint(.purple)
        }
    }

    @ViewBuilder
    private var questionContent: some View {
        switch step {
        case 0:
            questionTitle("Quel type de site veux-tu créer ?", subtitle: "Choisis la base la plus proche de ton idée.")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(categories) { choice in
                    choiceCard(
                        title: choice.title,
                        detail: choice.detail,
                        icon: choice.icon,
                        selected: category == choice.title
                    ) { category = choice.title }
                }
            }
        case 1:
            questionTitle("Quelle est l’idée du site ?", subtitle: "Donne un nom, son objectif et les personnes à qui il s’adresse.")
            VStack(spacing: 12) {
                textField("Nom du site ou de la marque", text: $name)
                textField("Objectif en une phrase (facultatif)", text: $purpose)
            }
            chipSection(title: "Public visé", options: audiences, selection: $audience)
        case 2:
            questionTitle("Quel affichage veux-tu ?", subtitle: "Choisis une direction visuelle ; elle restera modifiable après la maquette.")
            chipSection(title: "Style", options: styles, selection: $visualStyle)
            chipSection(title: "Couleur principale", options: accentOptions, selection: $accent)
        default:
            questionTitle("Quelles sections faut-il afficher ?", subtitle: "Sélectionne au moins trois éléments. Raphaël créera aussi une navigation adaptée.")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(sectionOptions, id: \.self) { section in
                    Button {
                        if sections.contains(section) { sections.remove(section) } else { sections.insert(section) }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: sections.contains(section) ? "checkmark.circle.fill" : "circle")
                            Text(section)
                                .font(.subheadline.weight(.medium))
                            Spacer(minLength: 0)
                        }
                        .foregroundColor(sections.contains(section) ? .white : .gray)
                        .padding(13)
                        .sarahLiquidGlass(
                            cornerRadius: 14,
                            tint: sections.contains(section) ? viewModel.activeAgent.themeColor : .white,
                            intensity: sections.contains(section) ? 0.22 : 0.05
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button("Retour") { step -= 1 }
                    .buttonStyle(WebsiteSecondaryButtonStyle())
            }
            Button(step == 3 ? "Générer la maquette" : "Continuer") {
                if step == 3 {
                    let finalSections = sections.count >= 3 ? Array(sections).sorted() : ["Accueil", "À propos", "Produits / services", "Contact"]
                    viewModel.completeWebsiteBrief(WebsiteBrief(
                        category: category,
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        purpose: purpose.trimmingCharacters(in: .whitespacesAndNewlines),
                        audience: audience,
                        visualStyle: visualStyle,
                        accent: accent,
                        sections: finalSections
                    ))
                    dismiss()
                } else {
                    step += 1
                }
            }
            .disabled(!canContinue)
            .buttonStyle(WebsitePrimaryButtonStyle())
        }
        .padding(.top, 4)
    }

    private var canContinue: Bool {
        switch step {
        case 0: return !category.isEmpty
        case 1: return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !audience.isEmpty
        case 2: return !visualStyle.isEmpty && !accent.isEmpty
        default: return true
        }
    }

    private func questionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.title3.weight(.bold)).foregroundColor(.white)
            Text(subtitle).font(.subheadline).foregroundColor(.gray)
        }
    }

    private func textField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textInputAutocapitalization(.sentences)
            .disableAutocorrection(false)
            .foregroundColor(.white)
            .padding(15)
            .sarahLiquidGlass(
                cornerRadius: 14,
                tint: viewModel.activeAgent.themeColor,
                intensity: 0.06
            )
    }

    private func chipSection(title: String, options: [String], selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundColor(.white)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 9)], alignment: .leading, spacing: 9) {
                ForEach(options, id: \.self) { option in
                    Button(option) { selection.wrappedValue = option }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(selection.wrappedValue == option ? .white : .gray)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(selection.wrappedValue == option ? Color.purple.opacity(0.78) : Color.white.opacity(0.08)))
                        .overlay(Capsule().stroke(selection.wrappedValue == option ? Color.purple : Color.white.opacity(0.12), lineWidth: 1))
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private func choiceCard(title: String, detail: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: icon).font(.title3).foregroundColor(selected ? .white : .purple)
                Text(title).font(.headline).foregroundColor(.white)
                Text(detail).font(.caption).foregroundColor(selected ? .white.opacity(0.85) : .gray)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .padding(14)
            .sarahLiquidGlass(
                cornerRadius: 18,
                tint: selected ? viewModel.activeAgent.themeColor : .white,
                intensity: selected ? 0.22 : 0.05
            )
        }
        .buttonStyle(.plain)
    }
}

@available(iOS 15.0, *)
private struct WebsiteChoice: Identifiable {
    let title: String
    let icon: String
    let detail: String
    var id: String { title }
}

@available(iOS 15.0, *)
private struct WebsitePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(15)
            .font(.headline)
            .foregroundColor(.white)
            .background(RoundedRectangle(cornerRadius: 15).fill(Color.purple.opacity(configuration.isPressed ? 0.55 : 0.9)))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

@available(iOS 15.0, *)
private struct WebsiteSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(15)
            .font(.headline)
            .foregroundColor(.white)
            .background(RoundedRectangle(cornerRadius: 15).fill(Color.white.opacity(configuration.isPressed ? 0.05 : 0.11)))
    }
}

// MARK: - Import média local

@available(iOS 16.0, *)
public struct SarahPickedMovie: Transferable {
    public let url: URL

    public static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("sarah-import-\(UUID().uuidString).\(ext)")
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: received.file, to: destination)
            return SarahPickedMovie(url: destination)
        }
    }
}

public enum NathanVideoAspect: String, CaseIterable, Identifiable {
    case original = "Original"
    case vertical = "9:16"
    case landscape = "16:9"

    public var id: String { rawValue }
}

// MARK: - Éditeur vidéo Nathan

@available(iOS 16.0, *)
public struct NathanVideoEditorView: View {
    public let sourceURL: URL
    @ObservedObject public var viewModel: ChatViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer
    @State private var duration: Double = 1
    @State private var trimStart: Double = 0
    @State private var trimEnd: Double = 1
    @State private var targetAspect: NathanVideoAspect = .vertical
    @State private var overlayText: String = ""
    @State private var statusText: String = "Prêt"
    @State private var isExporting = false

    public init(sourceURL: URL, viewModel: ChatViewModel) {
        self.sourceURL = sourceURL
        self.viewModel = viewModel
        _player = State(initialValue: AVPlayer(url: sourceURL))
    }

    public var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        VideoPlayer(player: player)
                            .frame(height: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .sarahLiquidGlass(cornerRadius: 22, tint: .purple, intensity: 0.06)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Découpage")
                                .font(.headline)
                                .foregroundColor(.white)

                            HStack {
                                Text("Début")
                                Spacer()
                                Text(formatTime(trimStart))
                            }
                            .foregroundColor(.secondary)
                            Slider(value: $trimStart, in: 0...max(0.1, min(trimEnd - 0.1, duration)), step: 0.05)
                                .tint(.purple)

                            HStack {
                                Text("Fin")
                                Spacer()
                                Text(formatTime(trimEnd))
                            }
                            .foregroundColor(.secondary)
                            Slider(value: $trimEnd, in: min(duration, trimStart + 0.1)...max(duration, trimStart + 0.1), step: 0.05)
                                .tint(.purple)
                        }
                        .padding(14)
                        .sarahLiquidGlass(cornerRadius: 18, tint: .purple, intensity: 0.06)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Format social")
                                .font(.headline)
                                .foregroundColor(.white)
                            Picker("Format", selection: $targetAspect) {
                                ForEach(NathanVideoAspect.allCases) { aspect in
                                    Text(aspect.rawValue).tag(aspect)
                                }
                            }
                            .pickerStyle(.segmented)

                            TextField("Texte à afficher sur la vidéo", text: $overlayText)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding(14)
                        .sarahLiquidGlass(cornerRadius: 18, tint: .purple, intensity: 0.06)

                        Button(action: applyNathanSocialPreset) {
                            Label("Nathan · Préparer pour Reels / Shorts", systemImage: "wand.and.stars")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(14)
                        }
                        .buttonStyle(.bordered)
                        .tint(.purple)

                        Button(action: exportVideo) {
                            HStack {
                                if isExporting { ProgressView().tint(.white) }
                                Image(systemName: "square.and.arrow.up")
                                Text(isExporting ? "Export en cours…" : "Exporter le montage")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .foregroundColor(.white)
                            .background(Color.purple)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .disabled(isExporting || trimEnd <= trimStart)

                        Text(statusText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Nathan · Montage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .task { await loadDuration() }
        .onDisappear { player.pause() }
    }

    private func loadDuration() async {
        do {
            let asset = AVURLAsset(url: sourceURL)
            let loaded = try await asset.load(.duration)
            let seconds = max(0.1, loaded.seconds)
            await MainActor.run {
                duration = seconds
                trimStart = 0
                trimEnd = seconds
            }
        } catch {
            await MainActor.run {
                statusText = "Impossible de lire la durée : \(error.localizedDescription)"
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let safe = max(0, seconds)
        let minutes = Int(safe) / 60
        let secs = Int(safe) % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func applyNathanSocialPreset() {
        HapticService.shared.buttonTap()
        targetAspect = .vertical
        if duration > 1 {
            trimStart = min(0.15, duration * 0.02)
            trimEnd = max(trimStart + 0.2, duration - min(0.15, duration * 0.02))
        }
        statusText = "Preset Nathan : vertical 9:16, export social et coupe des marges de début/fin."
        viewModel.activeAgent = .nathan
    }

    private func exportVideo() {
        guard !isExporting else { return }
        isExporting = true
        statusText = "Nathan prépare le montage…"

        NathanVideoEditorEngine.export(
            sourceURL: sourceURL,
            trimStart: trimStart,
            trimEnd: trimEnd,
            aspect: targetAspect,
            overlayText: overlayText
        ) { result in
            DispatchQueue.main.async {
                isExporting = false
                switch result {
                case .success(let url):
                    statusText = "Montage exporté."
                    viewModel.appendEditedVideo(
                        url: url,
                        title: overlayText.isEmpty ? "Montage Nathan" : overlayText,
                        vertical: targetAspect == .vertical
                    )
                case .failure(let error):
                    statusText = "Échec de l'export : \(error.localizedDescription)"
                }
            }
        }
    }
}

@available(iOS 16.0, *)
public enum NathanVideoEditorEngine {
    public static func export(
        sourceURL: URL,
        trimStart: Double,
        trimEnd: Double,
        aspect: NathanVideoAspect,
        overlayText: String,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let asset = AVURLAsset(url: sourceURL)
        guard let sourceVideo = asset.tracks(withMediaType: .video).first else {
            completion(.failure(NSError(
                domain: "NathanVideoEditor",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Aucune piste vidéo trouvée."]
            )))
            return
        }

        let assetDuration = max(0.1, asset.duration.seconds)
        let safeStart = min(max(0, trimStart), max(0, assetDuration - 0.1))
        let safeEnd = min(max(safeStart + 0.1, trimEnd), assetDuration)
        let range = CMTimeRange(
            start: CMTime(seconds: safeStart, preferredTimescale: 600),
            duration: CMTime(seconds: safeEnd - safeStart, preferredTimescale: 600)
        )

        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            completion(.failure(NSError(
                domain: "NathanVideoEditor",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Impossible de créer la piste vidéo."]
            )))
            return
        }

        do {
            try videoTrack.insertTimeRange(range, of: sourceVideo, at: .zero)
            if let sourceAudio = asset.tracks(withMediaType: .audio).first,
               let audioTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid
               ) {
                try? audioTrack.insertTimeRange(range, of: sourceAudio, at: .zero)
            }
        } catch {
            completion(.failure(error))
            return
        }

        let sourceRect = CGRect(origin: .zero, size: sourceVideo.naturalSize)
            .applying(sourceVideo.preferredTransform)
        let orientedSize = CGSize(
            width: max(1, abs(sourceRect.width)),
            height: max(1, abs(sourceRect.height))
        )

        let renderSize: CGSize
        switch aspect {
        case .vertical:
            renderSize = CGSize(width: 720, height: 1280)
        case .landscape:
            renderSize = CGSize(width: 1280, height: 720)
        case .original:
            renderSize = CGSize(
                width: max(2, floor(orientedSize.width / 2) * 2),
                height: max(2, floor(orientedSize.height / 2) * 2)
            )
        }

        let scale = min(
            renderSize.width / orientedSize.width,
            renderSize.height / orientedSize.height
        )
        let fitted = CGSize(width: orientedSize.width * scale, height: orientedSize.height * scale)
        let tx = (renderSize.width - fitted.width) / 2
        let ty = (renderSize.height - fitted.height) / 2

        var transform = sourceVideo.preferredTransform
        transform = transform.concatenating(
            CGAffineTransform(translationX: -sourceRect.minX, y: -sourceRect.minY)
        )
        transform = transform.concatenating(CGAffineTransform(scaleX: scale, y: scale))
        transform = transform.concatenating(CGAffineTransform(translationX: tx, y: ty))

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        layerInstruction.setTransform(transform, at: .zero)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: range.duration)
        instruction.layerInstructions = [layerInstruction]

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.instructions = [instruction]

        let cleanOverlay = overlayText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanOverlay.isEmpty {
            let parentLayer = CALayer()
            parentLayer.frame = CGRect(origin: .zero, size: renderSize)

            let videoLayer = CALayer()
            videoLayer.frame = parentLayer.bounds
            parentLayer.addSublayer(videoLayer)

            let textLayer = CATextLayer()
            textLayer.string = cleanOverlay
            textLayer.alignmentMode = .center
            textLayer.foregroundColor = UIColor.white.cgColor
            textLayer.backgroundColor = UIColor.black.withAlphaComponent(0.30).cgColor
            textLayer.cornerRadius = 12
            textLayer.fontSize = max(28, renderSize.width * 0.045)
            textLayer.contentsScale = UIScreen.main.scale
            textLayer.isWrapped = true
            textLayer.frame = CGRect(
                x: renderSize.width * 0.08,
                y: renderSize.height * 0.08,
                width: renderSize.width * 0.84,
                height: renderSize.height * 0.12
            )
            parentLayer.addSublayer(textLayer)

            videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
                postProcessingAsVideoLayer: videoLayer,
                in: parentLayer
            )
        }

        guard let exporter = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            completion(.failure(NSError(
                domain: "NathanVideoEditor",
                code: 501,
                userInfo: [NSLocalizedDescriptionKey: "Impossible de créer l'exporteur vidéo."]
            )))
            return
        }

        let canMP4 = exporter.supportedFileTypes.contains(.mp4)
        let outputType: AVFileType = canMP4 ? .mp4 : .mov
        let ext = canMP4 ? "mp4" : "mov"
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("NathanEdit-\(UUID().uuidString).\(ext)")
        try? FileManager.default.removeItem(at: outputURL)

        exporter.outputURL = outputURL
        exporter.outputFileType = outputType
        exporter.shouldOptimizeForNetworkUse = true
        exporter.videoComposition = videoComposition
        exporter.exportAsynchronously {
            switch exporter.status {
            case .completed:
                completion(.success(outputURL))
            case .cancelled:
                completion(.failure(NSError(
                    domain: "NathanVideoEditor",
                    code: 499,
                    userInfo: [NSLocalizedDescriptionKey: "Export annulé."]
                )))
            default:
                completion(.failure(exporter.error ?? NSError(
                    domain: "NathanVideoEditor",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: "L'export vidéo a échoué."]
                )))
            }
        }
    }
}

@available(iOS 15.0, *)
private struct SarahCameraPicker: UIViewControllerRepresentable {
    var completion: (UIImage?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let completion: (UIImage?) -> Void
        init(completion: @escaping (UIImage?) -> Void) { self.completion = completion }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { completion(nil) }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            completion(info[.originalImage] as? UIImage)
        }
    }
}
