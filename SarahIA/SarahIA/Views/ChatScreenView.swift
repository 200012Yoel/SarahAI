import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

/// Écran principal SarahIA.
///
/// La géométrie est volontairement simple : SwiftUI gère le clavier et les
/// safe areas. Aucun calcul manuel de hauteur de clavier n'est utilisé pour
/// déplacer la barre de saisie. Le mode vocal reste indépendant de cette vue.
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

/// Parcours de création en cartes : type de site, idée, direction graphique et sections.
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
        WebsiteChoice(title: "E-commerce", icon: "bag.fill", detail: "Boutique, produits et achat"),
        WebsiteChoice(title: "Entreprise", icon: "building.2.fill", detail: "Services, équipe et contact"),
        WebsiteChoice(title: "Voyage", icon: "airplane", detail: "Destinations et réservation"),
        WebsiteChoice(title: "Portfolio", icon: "person.crop.rectangle", detail: "Projets et réalisations"),
        WebsiteChoice(title: "Personnel", icon: "person.crop.circle", detail: "Présentation et univers personnel"),
        WebsiteChoice(title: "Blog / Magazine", icon: "newspaper.fill", detail: "Articles et actualités"),
        WebsiteChoice(title: "Restaurant", icon: "fork.knife", detail: "Menu et réservation"),
        WebsiteChoice(title: "Événement", icon: "calendar", detail: "Programme et inscription")
    ]

    private let audiences = [
        "Grand public", "Professionnels", "Familles", "Jeunes adultes",
        "Clients locaux", "International"
    ]

    private let styleChoices = [
        WebsiteStyleChoice(
            title: "Apple",
            icon: "apple.logo",
            detail: "Minimal, grands espaces, verre discret, typographie nette"
        ),
        WebsiteStyleChoice(
            title: "Google",
            icon: "circle.grid.2x2.fill",
            detail: "Material, cartes douces, couleurs franches et hiérarchie claire"
        ),
        WebsiteStyleChoice(
            title: "Microsoft",
            icon: "square.grid.2x2.fill",
            detail: "Fluent, surfaces translucides, Segoe et accents bleus"
        )
    ]

    private let accentOptions = ["Bleu", "Violet", "Rose", "Orange", "Vert", "Noir & blanc"]
    private let sectionOptions = [
        "Accueil", "À propos", "Produits / services", "Galerie",
        "Avis clients", "FAQ", "Contact"
    ]

    init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
        let draft = viewModel.websiteDraft
        _category = State(initialValue: draft?.category ?? "")
        _name = State(initialValue: draft?.name ?? "")
        _purpose = State(initialValue: draft?.purpose ?? "")
        _audience = State(initialValue: draft?.audience ?? "")
        _visualStyle = State(initialValue: draft?.visualStyle ?? "")
        _accent = State(initialValue: draft?.accent ?? "Bleu")
        _sections = State(initialValue: Set(draft?.sections ?? ["Accueil", "À propos", "Contact"]))
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                RadialGradient(
                    colors: [Color.sarahCyan.opacity(0.12), Color.clear],
                    center: .topTrailing,
                    startRadius: 10,
                    endRadius: 520
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        progress
                        questionContent
                        navigationButtons
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
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
            Text(step == 3 ? "Derniers réglages" : "Construisons ton site")
                .font(.system(size: 29, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(headerSubtitle)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var headerSubtitle: String {
        switch step {
        case 0:
            return "Choisis une carte. Raphaël adaptera ensuite les questions au type de site."
        case 1:
            return "Donne le nom, l'objectif et le public. Tu pourras tout modifier ensuite."
        case 2:
            return "Choisis une vraie direction graphique : Apple, Google ou Microsoft."
        default:
            return "Sélectionne les sections à afficher avant la première maquette locale."
        }
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Question \(step + 1) sur 4")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.sarahCyan)
                Spacer()
                Text("\((step + 1) * 25) %")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.45))
            }
            ProgressView(value: Double(step + 1), total: 4)
                .tint(.sarahCyan)
        }
    }

    @ViewBuilder
    private var questionContent: some View {
        switch step {
        case 0:
            questionTitle(
                "Quel type de site veux-tu créer ?",
                subtitle: "Les cartes sont numérotées pour que ce parcours puisse aussi être utilisé facilement à la voix."
            )

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Array(categories.enumerated()), id: \.element.id) { index, choice in
                    choiceCard(
                        number: index + 1,
                        title: choice.title,
                        detail: choice.detail,
                        icon: choice.icon,
                        selected: category == choice.title
                    ) {
                        HapticService.shared.buttonTap()
                        category = choice.title
                    }
                }
            }

        case 1:
            questionTitle(
                "Quelle est l'idée du site ?",
                subtitle: "Le nom est requis. L'objectif peut rester très court."
            )

            VStack(spacing: 12) {
                textField("Nom du site ou de la marque", text: $name)
                textField("Objectif en une phrase (facultatif)", text: $purpose)
            }

            chipSection(title: "Public visé", options: audiences, selection: $audience)

        case 2:
            questionTitle(
                "Quel style graphique veux-tu ?",
                subtitle: "Ce choix change réellement la typographie, les formes, les surfaces, les boutons et les espacements de la maquette."
            )

            VStack(spacing: 12) {
                ForEach(Array(styleChoices.enumerated()), id: \.element.id) { index, choice in
                    styleCard(
                        number: index + 1,
                        choice: choice,
                        selected: visualStyle == choice.title
                    ) {
                        HapticService.shared.buttonTap()
                        visualStyle = choice.title
                    }
                }
            }

            chipSection(title: "Couleur d'accent", options: accentOptions, selection: $accent)

        default:
            questionTitle(
                "Quelles sections faut-il afficher ?",
                subtitle: "Sélectionne les blocs importants. Raphaël créera aussi la navigation correspondante."
            )

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(sectionOptions, id: \.self) { section in
                    Button {
                        HapticService.shared.buttonTap()
                        if sections.contains(section) {
                            sections.remove(section)
                        } else {
                            sections.insert(section)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: sections.contains(section) ? "checkmark.circle.fill" : "circle")
                            Text(section)
                                .font(.subheadline.weight(.medium))
                            Spacer(minLength: 0)
                        }
                        .foregroundColor(sections.contains(section) ? .white : .white.opacity(0.58))
                        .padding(13)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(sections.contains(section) ? Color.sarahCyan.opacity(0.24) : Color.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(sections.contains(section) ? Color.sarahCyan.opacity(0.85) : Color.white.opacity(0.10), lineWidth: 1)
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
                Button("Retour") {
                    HapticService.shared.buttonTap()
                    withAnimation(.easeInOut(duration: 0.18)) { step -= 1 }
                }
                .buttonStyle(WebsiteSecondaryButtonStyle())
            }

            Button(step == 3 ? "Créer avec Raphaël" : "Continuer") {
                HapticService.shared.buttonTap()
                if step == 3 {
                    completeBrief()
                } else {
                    withAnimation(.easeInOut(duration: 0.18)) { step += 1 }
                }
            }
            .disabled(!canContinue)
            .buttonStyle(WebsitePrimaryButtonStyle())
        }
        .padding(.top, 4)
    }

    private var canContinue: Bool {
        switch step {
        case 0:
            return !category.isEmpty
        case 1:
            return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !audience.isEmpty
        case 2:
            return !visualStyle.isEmpty && !accent.isEmpty
        default:
            return !sections.isEmpty
        }
    }

    private func questionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundColor(.white)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.50))
        }
    }

    private func textField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textInputAutocapitalization(.sentences)
            .disableAutocorrection(false)
            .foregroundColor(.white)
            .padding(.horizontal, 15)
            .frame(height: 52)
            .sarahLiquidGlass(cornerRadius: 16, tint: .white, intensity: 0.055)
    }

    private func chipSection(title: String, options: [String], selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 9)], alignment: .leading, spacing: 9) {
                ForEach(options, id: \.self) { option in
                    Button(option) {
                        HapticService.shared.buttonTap()
                        selection.wrappedValue = option
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(selection.wrappedValue == option ? .white : .white.opacity(0.56))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(selection.wrappedValue == option ? Color.sarahCyan.opacity(0.28) : Color.white.opacity(0.06))
                    )
                    .overlay(
                        Capsule()
                            .stroke(selection.wrappedValue == option ? Color.sarahCyan.opacity(0.90) : Color.white.opacity(0.10), lineWidth: 1)
                    )
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func choiceCard(
        number: Int,
        title: String,
        detail: String,
        icon: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(selected ? .white : .sarahCyan)
                    Spacer()
                    Text("\(number)")
                        .font(.caption.weight(.bold))
                        .foregroundColor(selected ? .black : .white.opacity(0.66))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(selected ? Color.white : Color.white.opacity(0.08)))
                }

                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(detail)
                    .font(.caption)
                    .foregroundColor(selected ? .white.opacity(0.88) : .white.opacity(0.48))
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(selected ? Color.sarahCyan.opacity(0.23) : Color.white.opacity(0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(selected ? Color.sarahCyan.opacity(0.95) : Color.white.opacity(0.10), lineWidth: selected ? 1.5 : 1)
            )
            .shadow(color: selected ? Color.sarahCyan.opacity(0.16) : .clear, radius: 15)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Option \(number), \(title), \(detail)")
    }

    private func styleCard(
        number: Int,
        choice: WebsiteStyleChoice,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(selected ? Color.white.opacity(0.15) : Color.white.opacity(0.07))
                    Image(systemName: choice.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(selected ? .white : .sarahCyan)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(number). \(choice.title)")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.sarahCyan)
                        }
                    }
                    Text(choice.detail)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.52))
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(selected ? Color.sarahCyan.opacity(0.18) : Color.white.opacity(0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(selected ? Color.sarahCyan.opacity(0.95) : Color.white.opacity(0.10), lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Style \(number), \(choice.title). \(choice.detail)")
    }

    private func completeBrief() {
        let finalSections = sections.count >= 2
            ? Array(sections).sorted()
            : ["Accueil", "À propos", "Produits / services", "Contact"]

        let brief = WebsiteBrief(
            category: category,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            purpose: purpose.trimmingCharacters(in: .whitespacesAndNewlines),
            audience: audience,
            visualStyle: visualStyle,
            accent: accent,
            sections: finalSections
        )

        // On conserve le flux existant de Raphaël (historique, message et voix),
        // puis on remplace le HTML par la variante réellement stylée choisie ici.
        viewModel.completeWebsiteBrief(brief)
        let styledHTML = generateStyledWebsiteHTML(brief)
        _ = VAICodeEngine.shared.saveFile(filename: "index.html", content: styledHTML)
        viewModel.vaiCurrentCode = styledHTML
        viewModel.websiteDraft = brief
        dismiss()
    }

    private func generateStyledWebsiteHTML(_ brief: WebsiteBrief) -> String {
        let siteName = escapeHTML(brief.name.isEmpty ? "Mon nouveau site" : brief.name)
        let goal = escapeHTML(brief.purpose.isEmpty ? "Une expérience claire et adaptée à vos visiteurs." : brief.purpose)
        let audience = escapeHTML(brief.audience.isEmpty ? "vos visiteurs" : brief.audience)
        let category = escapeHTML(brief.category)
        let style = brief.visualStyle
        let colors = accentColors(brief.accent)

        let nav = brief.sections.map { section in
            let safe = escapeHTML(section)
            let anchor = safe.replacingOccurrences(of: " ", with: "-")
            return "<a href=\"#\(anchor)\">\(safe)</a>"
        }.joined(separator: "")

        let bodySections = brief.sections.map { sectionHTML($0, audience: audience) }.joined(separator: "\n")
        let profile = designProfile(style: style, primary: colors.0, secondary: colors.1)

        return """
        <!doctype html>
        <html lang="fr">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
          <meta name="theme-color" content="\(profile.themeColor)">
          <title>\(siteName)</title>
          <style>
            \(profile.css)
            * { box-sizing: border-box; }
            html { scroll-behavior: smooth; }
            body { margin: 0; min-height: 100vh; line-height: 1.5; }
            button, a { -webkit-tap-highlight-color: transparent; }
            .shell { width: min(1120px, 100%); margin: 0 auto; padding: max(18px, env(safe-area-inset-top)) 20px calc(42px + env(safe-area-inset-bottom)); }
            nav { display: flex; align-items: center; justify-content: space-between; gap: 18px; margin-bottom: 26px; }
            .brand { font-size: 20px; font-weight: 800; letter-spacing: -.45px; }
            .links { display: flex; flex-wrap: wrap; justify-content: flex-end; gap: 12px; }
            .links a { text-decoration: none; font-size: 13px; font-weight: 650; }
            .hero { position: relative; overflow: hidden; padding: clamp(46px, 8vw, 88px) clamp(24px, 6vw, 70px); }
            .eyebrow { margin: 0 0 12px; font-size: 12px; font-weight: 800; letter-spacing: .11em; text-transform: uppercase; }
            h1 { max-width: 760px; margin: 0; font-size: clamp(42px, 9vw, 82px); line-height: .98; letter-spacing: -.055em; }
            .hero p { max-width: 650px; margin: 22px 0 0; font-size: clamp(16px, 2.4vw, 20px); }
            .cta { margin-top: 28px; padding: 13px 18px; border: 0; font: inherit; font-weight: 750; cursor: pointer; }
            section { margin: 24px 0; padding: clamp(24px, 5vw, 38px); }
            h2 { margin: 0 0 10px; font-size: clamp(25px, 5vw, 38px); letter-spacing: -.03em; }
            .intro { max-width: 760px; }
            .cards { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 12px; margin-top: 22px; }
            .card { padding: 20px; }
            .card b { display: block; margin-bottom: 7px; }
            .card p { margin: 0; font-size: 14px; }
            .contact { display: flex; align-items: center; justify-content: space-between; gap: 20px; }
            .status { min-height: 24px; margin-top: 16px; font-size: 13px; font-weight: 650; }
            footer { padding: 20px 4px 8px; text-align: center; font-size: 12px; opacity: .62; }
            @media (max-width: 680px) {
              .shell { padding-left: 12px; padding-right: 12px; }
              nav { align-items: flex-start; flex-direction: column; }
              .links { justify-content: flex-start; }
              .cards { grid-template-columns: 1fr; }
              .contact { align-items: flex-start; flex-direction: column; }
            }
          </style>
        </head>
        <body>
          <main class="shell">
            <nav>
              <div class="brand">\(siteName)</div>
              <div class="links">\(nav)</div>
            </nav>

            <header class="hero">
              <p class="eyebrow">\(category) · style \(escapeHTML(style))</p>
              <h1>\(siteName)</h1>
              <p>\(goal)</p>
              <button class="cta" onclick="showContact()">Découvrir</button>
              <div id="contact-status" class="status" aria-live="polite"></div>
            </header>

            \(bodySections)

            <footer>Maquette locale · direction graphique \(escapeHTML(style)) · créée avec Raphaël</footer>
          </main>
          <script>
            function showContact() {
              const node = document.getElementById('contact-status');
              if (node) node.textContent = 'Interaction prête. Raphaël peut maintenant personnaliser cette action.';
            }
          </script>
        </body>
        </html>
        """
    }

    private func sectionHTML(_ section: String, audience: String) -> String {
        let safe = escapeHTML(section)
        let anchor = safe.replacingOccurrences(of: " ", with: "-")

        switch section {
        case "Accueil":
            return "<section id=\"\(anchor)\"><h2>Bienvenue</h2><p class=\"intro\">Une première page pensée pour \(audience).</p><div class=\"cards\"><article class=\"card\"><b>Clair</b><p>Une hiérarchie simple à comprendre.</p></article><article class=\"card\"><b>Responsive</b><p>Une mise en page adaptée à l’iPhone.</p></article><article class=\"card\"><b>Évolutif</b><p>Chaque bloc peut être modifié avec Raphaël.</p></article></div></section>"
        case "À propos":
            return "<section id=\"\(anchor)\"><h2>À propos</h2><p class=\"intro\">Présente ici l’histoire, les valeurs et l’identité du projet.</p></section>"
        case "Produits / services":
            return "<section id=\"\(anchor)\"><h2>Produits et services</h2><div class=\"cards\"><article class=\"card\"><b>Offre 01</b><p>Présente le produit ou service principal.</p></article><article class=\"card\"><b>Offre 02</b><p>Ajoute les détails utiles et le prix.</p></article><article class=\"card\"><b>Offre 03</b><p>Guide l’utilisateur vers l’action suivante.</p></article></div></section>"
        case "Galerie":
            return "<section id=\"\(anchor)\"><h2>Galerie</h2><div class=\"cards\"><article class=\"card\"><b>Projet 01</b><p>Emplacement pour une image ou réalisation.</p></article><article class=\"card\"><b>Projet 02</b><p>Un second contenu visuel.</p></article><article class=\"card\"><b>Projet 03</b><p>Une troisième mise en avant.</p></article></div></section>"
        case "Avis clients":
            return "<section id=\"\(anchor)\"><h2>Avis clients</h2><p class=\"intro\">« Ajoute ici un témoignage authentique qui explique la valeur du projet. »</p></section>"
        case "FAQ":
            return "<section id=\"\(anchor)\"><h2>FAQ</h2><div class=\"cards\"><article class=\"card\"><b>Comment ça marche ?</b><p>Ajoute une réponse concise.</p></article><article class=\"card\"><b>Quels sont les délais ?</b><p>Explique le fonctionnement.</p></article><article class=\"card\"><b>Comment vous contacter ?</b><p>Indique le canal de contact.</p></article></div></section>"
        case "Contact":
            return "<section id=\"\(anchor)\" class=\"contact\"><div><h2>Contact</h2><p class=\"intro\">Une question ? Cette zone est prête pour ton formulaire ou tes coordonnées.</p></div><button class=\"cta\" onclick=\"showContact()\">Contacter</button></section>"
        default:
            return "<section id=\"\(anchor)\"><h2>\(safe)</h2><p class=\"intro\">Cette section est prête à être personnalisée.</p></section>"
        }
    }

    private func designProfile(style: String, primary: String, secondary: String) -> (themeColor: String, css: String) {
        switch style.lowercased() {
        case "google":
            return (
                "#F8FAFD",
                """
                :root { --primary: \(primary); --secondary: \(secondary); --ink: #1f1f1f; --muted: #5f6368; --surface: #ffffff; --soft: #f8fafd; --line: #e1e3e7; }
                body { color: var(--ink); background: var(--soft); font-family: Roboto, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
                .links a { color: var(--muted); padding: 8px 12px; border-radius: 999px; }
                .hero { border-radius: 32px; color: var(--ink); background: color-mix(in srgb, var(--primary) 10%, #ffffff); border: 1px solid color-mix(in srgb, var(--primary) 18%, #e1e3e7); }
                .eyebrow { color: var(--primary); }
                .hero p, .intro, .card p { color: var(--muted); }
                .cta { color: #fff; background: var(--primary); border-radius: 999px; box-shadow: 0 2px 5px rgba(60,64,67,.20); }
                section { border-radius: 28px; background: var(--surface); border: 1px solid var(--line); box-shadow: 0 1px 2px rgba(60,64,67,.08); }
                .card { border-radius: 22px; background: var(--soft); border: 1px solid var(--line); }
                """
            )

        case "microsoft":
            return (
                "#0F1115",
                """
                :root { --primary: \(primary); --secondary: \(secondary); --ink: #f5f5f5; --muted: #b6bbc4; --surface: rgba(35,38,44,.82); --soft: #111318; --line: rgba(255,255,255,.10); }
                body { color: var(--ink); background: radial-gradient(circle at 85% -10%, color-mix(in srgb, var(--primary) 25%, transparent), transparent 34%), #0f1115; font-family: "Segoe UI", -apple-system, BlinkMacSystemFont, sans-serif; }
                .links a { color: #d8dbe0; padding: 8px 11px; border-radius: 8px; }
                .hero { border-radius: 16px; color: #fff; background: linear-gradient(145deg, rgba(255,255,255,.09), rgba(255,255,255,.035)); border: 1px solid var(--line); backdrop-filter: blur(22px); box-shadow: 0 22px 70px rgba(0,0,0,.35); }
                .eyebrow { color: color-mix(in srgb, var(--primary) 70%, white); }
                .hero p, .intro, .card p { color: var(--muted); }
                .cta { color: #fff; background: var(--primary); border-radius: 8px; box-shadow: inset 0 0 0 1px rgba(255,255,255,.13), 0 4px 16px rgba(0,0,0,.24); }
                section { border-radius: 14px; background: var(--surface); border: 1px solid var(--line); backdrop-filter: blur(18px); }
                .card { border-radius: 10px; background: rgba(255,255,255,.055); border: 1px solid rgba(255,255,255,.08); }
                """
            )

        default:
            return (
                "#000000",
                """
                :root { --primary: \(primary); --secondary: \(secondary); --ink: #f5f5f7; --muted: #a1a1a6; --surface: rgba(28,28,30,.78); --soft: #000000; --line: rgba(255,255,255,.12); }
                body { color: var(--ink); background: radial-gradient(circle at 50% -10%, color-mix(in srgb, var(--primary) 22%, transparent), transparent 34%), #000; font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Helvetica Neue", sans-serif; }
                .links a { color: #e8e8ed; padding: 8px 12px; border-radius: 999px; background: rgba(255,255,255,.055); backdrop-filter: blur(20px); }
                .hero { border-radius: 34px; color: #fff; background: linear-gradient(145deg, rgba(255,255,255,.105), rgba(255,255,255,.025)); border: 1px solid var(--line); backdrop-filter: saturate(160%) blur(28px); box-shadow: 0 34px 90px rgba(0,0,0,.42); }
                .eyebrow { color: color-mix(in srgb, var(--primary) 68%, white); }
                .hero p, .intro, .card p { color: var(--muted); }
                .cta { color: #fff; background: linear-gradient(135deg, var(--primary), var(--secondary)); border-radius: 999px; box-shadow: 0 8px 28px color-mix(in srgb, var(--primary) 26%, transparent); }
                section { border-radius: 28px; background: var(--surface); border: 1px solid var(--line); backdrop-filter: saturate(140%) blur(22px); }
                .card { border-radius: 20px; background: rgba(255,255,255,.06); border: 1px solid rgba(255,255,255,.09); }
                """
            )
        }
    }

    private func accentColors(_ accent: String) -> (String, String) {
        switch accent.lowercased() {
        case "bleu": return ("#0A84FF", "#64D2FF")
        case "rose": return ("#FF2D55", "#FF7A9A")
        case "orange": return ("#FF9500", "#FFD60A")
        case "vert": return ("#30D158", "#63E6BE")
        case "noir & blanc": return ("#8E8E93", "#E5E5EA")
        default: return ("#7C5CFF", "#BF5AF2")
        }
    }

    private func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
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
private struct WebsiteStyleChoice: Identifiable {
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
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.sarahCyan.opacity(configuration.isPressed ? 0.62 : 0.90))
            )
            .opacity(configuration.isPressed ? 0.86 : 1)
    }
}

@available(iOS 15.0, *)
private struct WebsiteSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(15)
            .font(.headline)
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.05 : 0.10))
            )
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
