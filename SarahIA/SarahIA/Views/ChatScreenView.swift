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
    @State private var designMood: String
    @State private var accent: String
    @State private var sections: Set<String>
    @State private var voiceFocusedOption: String? = nil
    @State private var voiceGuideGeneration = UUID()

    private let categories = [
        WebsiteChoice(title: "E-commerce", icon: "bag.fill", detail: "Vendre des produits"),
        WebsiteChoice(title: "Voyage", icon: "airplane", detail: "Inspirer et réserver"),
        WebsiteChoice(title: "Restaurant", icon: "fork.knife", detail: "Menu et réservation"),
        WebsiteChoice(title: "Portfolio", icon: "person.crop.rectangle", detail: "Présenter son travail"),
        WebsiteChoice(title: "Entreprise", icon: "building.2.fill", detail: "Services et contact"),
        WebsiteChoice(title: "Événement", icon: "calendar", detail: "Informer et inscrire")
    ]

    private let audiences = [
        "Grand public", "Professionnels", "Familles", "Jeunes adultes",
        "Clients locaux", "International"
    ]

    private let moodChoices = [
        WebsiteChoice(title: "Minimaliste", icon: "rectangle.compress.vertical", detail: "Simple, calme et très lisible"),
        WebsiteChoice(title: "Élégant", icon: "sparkles", detail: "Raffiné, équilibré et premium"),
        WebsiteChoice(title: "Énergique", icon: "bolt.fill", detail: "Contrastes forts et rythme visuel"),
        WebsiteChoice(title: "Luxe", icon: "crown.fill", detail: "Sobre, éditorial et haut de gamme"),
        WebsiteChoice(title: "Naturel", icon: "leaf.fill", detail: "Doux, organique et chaleureux"),
        WebsiteChoice(title: "Tech", icon: "cpu", detail: "Précis, moderne et numérique")
    ]

    /// Les directions visuelles sont adaptées au type de site choisi.
    /// Elles s'inspirent de grands langages graphiques sans copier leurs pages,
    /// logos, textes ou ressources propriétaires.
    private var styleChoices: [WebsiteStyleChoice] {
        switch category {
        case "E-commerce":
            return [
                WebsiteStyleChoice(title: "Apple Store Premium", icon: "apple.logo", detail: "Produit star, grands visuels, espace et finition premium"),
                WebsiteStyleChoice(title: "Amazon Marketplace", icon: "shippingbox.fill", detail: "Catalogue dense, recherche visible, prix, avis et achat rapide"),
                WebsiteStyleChoice(title: "Shopify Store", icon: "bag.badge.plus", detail: "Boutique claire, fiches produit, panier et conversion"),
                WebsiteStyleChoice(title: "Google Shopping", icon: "circle.grid.2x2.fill", detail: "Cartes colorées, filtres simples et découverte visuelle"),
                WebsiteStyleChoice(title: "Nike Product", icon: "figure.run", detail: "Grand produit, contraste noir et blanc et appels à l'action nets"),
                WebsiteStyleChoice(title: "Microsoft Store", icon: "square.grid.2x2.fill", detail: "Grille Fluent, catégories nettes et surfaces structurées"),
                WebsiteStyleChoice(title: "Stripe Checkout", icon: "creditcard.fill", detail: "Dégradés premium, confiance et parcours d'achat fluide"),
                WebsiteStyleChoice(title: "Sarah Commerce", icon: "wand.and.stars", detail: "Verre sombre, cyan lumineux et boutique futuriste")
            ]
        case "Voyage":
            return [
                WebsiteStyleChoice(title: "Airbnb Travel", icon: "house.fill", detail: "Photographies immersives, destinations et cartes chaleureuses"),
                WebsiteStyleChoice(title: "Booking Explorer", icon: "bed.double.fill", detail: "Recherche immédiate, disponibilité et fiches destination efficaces"),
                WebsiteStyleChoice(title: "Google Travel", icon: "map.fill", detail: "Couleurs légères, cartes, itinéraires et informations rapides"),
                WebsiteStyleChoice(title: "Apple Travel", icon: "apple.logo", detail: "Carnet de voyage très épuré, photos plein écran et narration premium"),
                WebsiteStyleChoice(title: "Expedia Cards", icon: "airplane", detail: "Offres, vols, hôtels et cartes comparatives faciles à parcourir"),
                WebsiteStyleChoice(title: "National Geographic Editorial", icon: "photo.on.rectangle.angled", detail: "Grand récit visuel, photographie et lecture éditoriale"),
                WebsiteStyleChoice(title: "Tesla Journey", icon: "car.fill", detail: "Minimalisme noir et blanc, grands paysages et parcours direct"),
                WebsiteStyleChoice(title: "Sarah Explorer", icon: "sparkles", detail: "Voyage immersif sombre, halos et cartes translucides")
            ]
        case "Restaurant":
            return [
                WebsiteStyleChoice(title: "Michelin Fine Dining", icon: "fork.knife", detail: "Éditorial sobre, photos culinaires et sensation haut de gamme"),
                WebsiteStyleChoice(title: "Uber Eats", icon: "takeoutbag.and.cup.and.straw.fill", detail: "Menu rapide, catégories visibles et commande en quelques gestes"),
                WebsiteStyleChoice(title: "Deliveroo Fresh", icon: "bicycle", detail: "Cartes vivantes, visuels généreux et commande très lisible"),
                WebsiteStyleChoice(title: "Apple Minimal", icon: "apple.logo", detail: "Carte courte, typographie nette et photos très premium"),
                WebsiteStyleChoice(title: "Google Local", icon: "mappin.and.ellipse", detail: "Informations pratiques, horaires, carte et avis mis en avant"),
                WebsiteStyleChoice(title: "OpenTable Dining", icon: "calendar.badge.clock", detail: "Réservation au centre, disponibilités et ambiance élégante"),
                WebsiteStyleChoice(title: "Notion Menu", icon: "doc.text.fill", detail: "Menu éditorial, noir et blanc et lecture ultra claire"),
                WebsiteStyleChoice(title: "Sarah Bistro", icon: "wand.and.stars", detail: "Verre sombre, photos chaudes et réservations lumineuses")
            ]
        case "Portfolio":
            return [
                WebsiteStyleChoice(title: "Apple Creative", icon: "apple.logo", detail: "Très grands visuels, espace et présentation cinématographique"),
                WebsiteStyleChoice(title: "Behance Grid", icon: "square.grid.3x3.fill", detail: "Mosaïque de projets, tags et découverte rapide du travail"),
                WebsiteStyleChoice(title: "Adobe Portfolio", icon: "paintbrush.pointed.fill", detail: "Galeries propres, séries de projets et typographie créative"),
                WebsiteStyleChoice(title: "Notion Editorial", icon: "doc.text.fill", detail: "Portfolio texte-image sobre, structuré et très lisible"),
                WebsiteStyleChoice(title: "Linear Tech", icon: "sparkle", detail: "Dark mode précis, halos froids et rendu produit moderne"),
                WebsiteStyleChoice(title: "Microsoft Fluent", icon: "square.grid.2x2.fill", detail: "Cartes transparentes, profondeur et présentation structurée"),
                WebsiteStyleChoice(title: "Tesla Minimal", icon: "rectangle.portrait.fill", detail: "Une œuvre à la fois, contraste fort et presque aucun bruit visuel"),
                WebsiteStyleChoice(title: "Sarah Signature", icon: "wand.and.stars", detail: "Identité originale Sarah, verre sombre et accents cyan")
            ]
        case "Entreprise":
            return [
                WebsiteStyleChoice(title: "Microsoft Fluent", icon: "square.grid.2x2.fill", detail: "Structure professionnelle, profondeur et surfaces Fluent"),
                WebsiteStyleChoice(title: "Apple Corporate", icon: "apple.logo", detail: "Institutionnel premium, grands messages et beaucoup d'espace"),
                WebsiteStyleChoice(title: "Google Workspace", icon: "circle.grid.2x2.fill", detail: "Clair, accessible, coloré et orienté collaboration"),
                WebsiteStyleChoice(title: "Stripe Business", icon: "creditcard.fill", detail: "Dégradés nets, chiffres clés et hiérarchie SaaS premium"),
                WebsiteStyleChoice(title: "Salesforce Cloud", icon: "cloud.fill", detail: "Bleu lumineux, données, confiance et blocs orientés services"),
                WebsiteStyleChoice(title: "Notion Company", icon: "doc.text.fill", detail: "Entreprise éditoriale, transparente et très lisible"),
                WebsiteStyleChoice(title: "Linear SaaS", icon: "sparkle", detail: "Dark mode technique, précision et interface produit"),
                WebsiteStyleChoice(title: "Sarah Pro", icon: "wand.and.stars", detail: "Corporate futuriste, verre, cyan et métriques élégantes")
            ]
        case "Événement":
            return [
                WebsiteStyleChoice(title: "Apple Keynote", icon: "apple.logo", detail: "Annonce spectaculaire, grand titre et mise en scène premium"),
                WebsiteStyleChoice(title: "Eventbrite Live", icon: "ticket.fill", detail: "Billets, horaires, intervenants et inscription immédiate"),
                WebsiteStyleChoice(title: "Ticketmaster", icon: "ticket.fill", detail: "Programme dense, places, catégories et appel à l'achat direct"),
                WebsiteStyleChoice(title: "Spotify Festival", icon: "music.note.list", detail: "Dark mode musical, affiches colorées et line-up très visuel"),
                WebsiteStyleChoice(title: "Microsoft Events", icon: "person.3.fill", detail: "Agenda structuré, sessions et cartes professionnelles"),
                WebsiteStyleChoice(title: "Google I/O Color", icon: "circle.grid.2x2.fill", detail: "Couleurs franches, conférences en cartes et navigation ludique"),
                WebsiteStyleChoice(title: "Tesla Launch", icon: "bolt.fill", detail: "Lancement minimaliste, noir profond et révélation du produit"),
                WebsiteStyleChoice(title: "Sarah Live", icon: "wand.and.stars", detail: "Scène numérique sombre, halos et programme interactif")
            ]
        default:
            return [
                WebsiteStyleChoice(title: "Apple Premium", icon: "apple.logo", detail: "Épuré, spacieux et premium"),
                WebsiteStyleChoice(title: "Google Color", icon: "circle.grid.2x2.fill", detail: "Lumineux, coloré et accessible"),
                WebsiteStyleChoice(title: "Microsoft Fluent", icon: "square.grid.2x2.fill", detail: "Structuré, profond et professionnel"),
                WebsiteStyleChoice(title: "Sarah Signature", icon: "wand.and.stars", detail: "Verre sombre et accents cyan")
            ]
        }
    }

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
        let savedStyle = draft?.visualStyle ?? ""
        let savedParts = savedStyle.components(separatedBy: " · ")
        _designMood = State(initialValue: savedParts.count > 1 ? savedParts[0] : "")
        _visualStyle = State(initialValue: savedParts.count > 1 ? savedParts.dropFirst().joined(separator: " · ") : savedStyle)
        _accent = State(initialValue: draft?.accent ?? "Violet")
        _sections = State(initialValue: Set(draft?.sections ?? ["Accueil", "À propos", "Contact"]))
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                RadialGradient(
                    colors: [Color.purple.opacity(0.12), Color.clear],
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
        .onAppear {
            if viewModel.isContinuousConversationActive {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    readCurrentVoiceOptions()
                }
            }
        }
        .onChange(of: viewModel.websiteVoiceCommandSequence) { _ in
            handleWebsiteVoiceCommand(viewModel.websiteVoiceCommand)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(step == 4 ? "Derniers réglages" : "Construisons ton site")
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
        case 0: return "Choisis le type de site avec les mêmes cartes que la build 502."
        case 1: return "Donne le nom, l’objectif et le public du site."
        case 2: return "Choisis l’ambiance graphique du parcours original."
        case 3: return "Choisis ensuite une grande direction visuelle pour guider Raphaël."
        default: return "Sélectionne les sections à afficher avant la première maquette locale."
        }
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Question \(step + 1) sur 5")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.purple)
                Spacer()
                Text("\((step + 1) * 20) %")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.45))
            }
            ProgressView(value: Double(step + 1), total: 5)
                .tint(.purple)
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
                        selected: category == choice.title,
                        focused: voiceFocusedOption == choice.title
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
                "Quelle ambiance veux-tu ?",
                subtitle: "Le menu original : Minimaliste, Élégant, Énergique, Luxe, Naturel ou Tech."
            )

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Array(moodChoices.enumerated()), id: \.element.id) { index, choice in
                    choiceCard(
                        number: index + 1,
                        title: choice.title,
                        detail: choice.detail,
                        icon: choice.icon,
                        selected: designMood == choice.title,
                        focused: voiceFocusedOption == choice.title
                    ) {
                        HapticService.shared.buttonTap()
                        designMood = choice.title
                    }
                }
            }

            chipSection(title: "Couleur d’accent", options: accentOptions, selection: $accent)

        case 3:
            questionTitle(
                "Quelle direction graphique veux-tu ?",
                subtitle: "Chaque style change réellement les couleurs, la typographie, les formes, les surfaces et le rythme du site."
            )

            VStack(spacing: 12) {
                ForEach(Array(styleChoices.enumerated()), id: \.element.id) { index, choice in
                    styleCard(number: index + 1, choice: choice, selected: visualStyle == choice.title, focused: voiceFocusedOption == choice.title) {
                        HapticService.shared.buttonTap()
                        visualStyle = choice.title
                    }
                }
            }

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
                                .fill(sections.contains(section) ? Color.purple.opacity(0.24) : (voiceFocusedOption == section ? Color.purple.opacity(0.14) : Color.white.opacity(0.06)))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke((sections.contains(section) || voiceFocusedOption == section) ? Color.purple.opacity(0.95) : Color.white.opacity(0.10), lineWidth: voiceFocusedOption == section ? 2 : 1)
                        )
                        .shadow(color: voiceFocusedOption == section ? Color.purple.opacity(0.55) : .clear, radius: 18)
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

            Button(step == 4 ? "Créer avec Raphaël" : "Continuer") {
                HapticService.shared.buttonTap()
                if step == 4 {
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
            return !designMood.isEmpty && !accent.isEmpty
        case 3:
            return !visualStyle.isEmpty
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
                            .fill(selection.wrappedValue == option ? Color.purple.opacity(0.28) : Color.white.opacity(0.06))
                    )
                    .overlay(
                        Capsule()
                            .stroke(selection.wrappedValue == option ? Color.purple.opacity(0.90) : Color.white.opacity(0.10), lineWidth: 1)
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
        focused: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let active = selected || focused
        return Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(active ? .white : .purple)
                    Spacer()
                    Text("\(number)")
                        .font(.caption.weight(.bold))
                        .foregroundColor(active ? .black : .white.opacity(0.66))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(active ? Color.white : Color.white.opacity(0.08)))
                }

                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(detail)
                    .font(.caption)
                    .foregroundColor(active ? .white.opacity(0.88) : .white.opacity(0.48))
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(selected ? Color.purple.opacity(0.23) : (focused ? Color.purple.opacity(0.13) : Color.white.opacity(0.055)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke((selected || focused) ? Color.purple.opacity(0.98) : Color.white.opacity(0.10), lineWidth: focused ? 2.2 : (selected ? 1.5 : 1))
            )
            .shadow(color: focused ? Color.purple.opacity(0.60) : (selected ? Color.purple.opacity(0.16) : .clear), radius: focused ? 24 : 15)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Option \(number), \(title), \(detail)")
    }

    private func styleCard(
        number: Int,
        choice: WebsiteStyleChoice,
        selected: Bool,
        focused: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let active = selected || focused
        return Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(active ? Color.white.opacity(0.15) : Color.white.opacity(0.07))
                    Image(systemName: choice.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(active ? .white : .purple)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(number). \(choice.title)")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        if selected || focused {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.purple)
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
                    .fill(selected ? Color.purple.opacity(0.18) : (focused ? Color.purple.opacity(0.12) : Color.white.opacity(0.045)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke((selected || focused) ? Color.purple.opacity(0.98) : Color.white.opacity(0.10), lineWidth: focused ? 2.2 : (selected ? 1.5 : 1))
            )
            .shadow(color: focused ? Color.purple.opacity(0.60) : .clear, radius: focused ? 24 : 0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Style \(number), \(choice.title). \(choice.detail)")
    }

    private func normalizedVoiceText(_ text: String) -> String {
        text.lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
            .replacingOccurrences(of: "’", with: " ")
            .replacingOccurrences(of: "'", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private var currentVoiceChoices: [WebsiteChoice] {
        switch step {
        case 0:
            return categories
        case 1:
            return audiences.map { WebsiteChoice(title: $0, icon: "person.2.fill", detail: "Public visé") }
        case 2:
            return moodChoices
        case 3:
            return styleChoices.map { WebsiteChoice(title: $0.title, icon: $0.icon, detail: $0.detail) }
        default:
            return sectionOptions.map { WebsiteChoice(title: $0, icon: "square.grid.2x2", detail: "Ajouter cette section au site") }
        }
    }

    private func estimatedSpeechDuration(_ text: String) -> Double {
        let words = max(1, text.split(whereSeparator: { $0.isWhitespace }).count)
        return max(2.3, Double(words) / 2.55 + 0.9)
    }

    private func readCurrentVoiceOptions() {
        guard viewModel.isContinuousConversationActive else { return }
        let generation = UUID()
        voiceGuideGeneration = generation

        if step == 1 {
            voiceFocusedOption = nil
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.speakWebsiteGuide("Dis-moi le nom du site. Tu peux dire par exemple : le site s'appelle Horizon.")
            } else if audience.isEmpty {
                viewModel.speakWebsiteGuide("Quel est le public visé ? Tu peux dire grand public, professionnels, familles, jeunes adultes, clients locaux ou international.")
            }
            return
        }

        let choices = currentVoiceChoices
        var delay: Double = 0
        for (index, choice) in choices.enumerated() {
            let spoken = "Option \(index + 1). \(choice.title). \(choice.detail)."
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard voiceGuideGeneration == generation,
                      viewModel.isShowingWebsiteBuilder,
                      viewModel.isContinuousConversationActive else { return }
                withAnimation(.easeInOut(duration: 0.22)) {
                    voiceFocusedOption = choice.title
                }
                viewModel.speakWebsiteGuide(spoken)
            }
            delay += estimatedSpeechDuration(spoken)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard voiceGuideGeneration == generation,
                  viewModel.isShowingWebsiteBuilder,
                  viewModel.isContinuousConversationActive else { return }
            withAnimation(.easeInOut(duration: 0.22)) {
                voiceFocusedOption = nil
            }
            viewModel.speakWebsiteGuide("Tu peux me dire le nom de l'option ou son numéro. Tu peux aussi dire répète.")
        }
    }

    private func voiceChoiceIndex(from normalized: String, count: Int) -> Int? {
        let aliases: [(String, Int)] = [
            ("premier", 0), ("premiere", 0), ("un", 0), ("1", 0),
            ("deuxieme", 1), ("deux", 1), ("2", 1),
            ("troisieme", 2), ("trois", 2), ("3", 2),
            ("quatrieme", 3), ("quatre", 3), ("4", 3),
            ("cinquieme", 4), ("cinq", 4), ("5", 4),
            ("sixieme", 5), ("six", 5), ("6", 5),
            ("septieme", 6), ("sept", 6), ("7", 6),
            ("huitieme", 7), ("huit", 7), ("8", 7)
        ]
        for (word, index) in aliases where index < count {
            if normalized == word || normalized.contains("option \(word)") || normalized.contains("la \(word)") || normalized.contains("le \(word)") {
                return index
            }
        }
        return nil
    }

    private func applyVoiceChoice(_ choice: WebsiteChoice) {
        voiceFocusedOption = choice.title
        switch step {
        case 0:
            category = choice.title
            viewModel.speakWebsiteGuide("Très bien. \(choice.title) est sélectionné.")
            let captured = step
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                guard step == captured else { return }
                withAnimation(.easeInOut(duration: 0.18)) { step = 1 }
                readCurrentVoiceOptions()
            }
        case 1:
            audience = choice.title
            viewModel.speakWebsiteGuide("Public \(choice.title) sélectionné.")
            if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.easeInOut(duration: 0.18)) { step = 2 }
                    readCurrentVoiceOptions()
                }
            }
        case 2:
            designMood = choice.title
            viewModel.speakWebsiteGuide("Ambiance \(choice.title) sélectionnée.")
            let captured = step
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                guard step == captured else { return }
                withAnimation(.easeInOut(duration: 0.18)) { step = 3 }
                readCurrentVoiceOptions()
            }
        case 3:
            visualStyle = choice.title
            viewModel.speakWebsiteGuide("Style \(choice.title) sélectionné.")
            let captured = step
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                guard step == captured else { return }
                withAnimation(.easeInOut(duration: 0.18)) { step = 4 }
                readCurrentVoiceOptions()
            }
        default:
            if sections.contains(choice.title) {
                sections.remove(choice.title)
                viewModel.speakWebsiteGuide("J'enlève la section \(choice.title).")
            } else {
                sections.insert(choice.title)
                viewModel.speakWebsiteGuide("J'ajoute la section \(choice.title).")
            }
        }
    }

    private func handleWebsiteVoiceCommand(_ raw: String) {
        let normalized = normalizedVoiceText(raw)
        guard !normalized.isEmpty else { return }

        // Une nouvelle phrase utilisateur annule immédiatement les lectures planifiées.
        voiceGuideGeneration = UUID()

        if normalized.contains("repete") || normalized.contains("lis moi") || normalized.contains("lire les") ||
            normalized.contains("quelles options") || normalized.contains("quels choix") ||
            normalized.contains("quels styles") || normalized.contains("formes de site") ||
            normalized.contains("types de site") || normalized.contains("propose moi") {
            readCurrentVoiceOptions()
            return
        }

        if normalized.contains("retour") || normalized.contains("precedent") || normalized.contains("reviens") {
            if step > 0 {
                withAnimation(.easeInOut(duration: 0.18)) { step -= 1 }
                readCurrentVoiceOptions()
            }
            return
        }

        if normalized == "suivant" || normalized.contains("continue") || normalized.contains("valide") || normalized.contains("c est bon") {
            if canContinue {
                if step == 4 {
                    completeBrief()
                } else {
                    withAnimation(.easeInOut(duration: 0.18)) { step += 1 }
                    readCurrentVoiceOptions()
                }
            } else {
                viewModel.speakWebsiteGuide("Il me manque encore un choix avant de continuer.")
            }
            return
        }

        if step == 1 {
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let prefixes = ["le site s appelle ", "le site sapelle ", "il s appelle ", "nom du site ", "appelle le site "]
                var proposed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                for prefix in prefixes {
                    if let range = normalized.range(of: prefix) {
                        let suffix = normalized[range.upperBound...]
                        proposed = String(suffix).trimmingCharacters(in: .whitespacesAndNewlines)
                        break
                    }
                }
                if !proposed.isEmpty {
                    name = proposed.prefix(1).uppercased() + proposed.dropFirst()
                    viewModel.speakWebsiteGuide("Parfait. Le site s'appellera \(name). Quel est le public visé ?")
                    return
                }
            }
        }

        let choices = currentVoiceChoices
        if let exact = choices.first(where: { normalized.contains(normalizedVoiceText($0.title)) }) {
            applyVoiceChoice(exact)
            return
        }
        if let index = voiceChoiceIndex(from: normalized, count: choices.count) {
            applyVoiceChoice(choices[index])
            return
        }

        viewModel.speakWebsiteGuide("Je n'ai pas reconnu ce choix. Dis répète pour que je relise les cartes, ou dis directement le nom de l'option.")
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
            visualStyle: "\(designMood) · \(visualStyle)",
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
        var n = style.lowercased()
        let originalStyle = n
        if n.contains("nike") || n.contains("tesla") { n = "tesla" }
        else if n.contains("booking") || n.contains("expedia") || n.contains("opentable") { n = "airbnb" }
        else if n.contains("national geographic") || n.contains("michelin") { n = "notion" }
        else if n.contains("uber eats") || n.contains("deliveroo") { n = "shopify" }
        else if n.contains("behance") || n.contains("adobe") { n = "linear" }
        else if n.contains("salesforce") || n.contains("ticketmaster") { n = "microsoft" }
        else if n.contains("eventbrite") { n = "stripe" }
        else if n.contains("spotify") { n = "linear" }
        var theme = "#000000"
        var ink = "#f5f5f7"
        var muted = "#a1a1a6"
        var surface = "rgba(28,28,30,.78)"
        var soft = "#000000"
        var line = "rgba(255,255,255,.12)"
        var a1 = primary
        var a2 = secondary
        var font = "-apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Helvetica Neue', sans-serif"
        var radius = "30px"
        var cardRadius = "20px"
        var buttonRadius = "999px"
        var bodyBackground = "radial-gradient(circle at 50% -10%, rgba(10,132,255,.18), transparent 34%), #000"
        var heroBackground = "linear-gradient(145deg, rgba(255,255,255,.105), rgba(255,255,255,.025))"
        var shadow = "0 34px 90px rgba(0,0,0,.42)"

        if originalStyle.contains("amazon") {
            return (
                "#FFFFFF",
                """
                :root { --primary: #FF9900; --secondary: #146EB4; --ink: #0F1111; --muted: #565959; --surface: #ffffff; --soft: #f3f3f3; --line: #d5d9d9; }
                body { color: var(--ink); background: #eaeded; font-family: Arial, "Helvetica Neue", sans-serif; }
                nav { background: #131921; color: #fff; padding: 14px 18px; border-radius: 10px; }
                .links a { color: #fff; padding: 7px 10px; border-radius: 4px; }
                .hero { border-radius: 14px; color: #111; background: linear-gradient(135deg, #fff 0%, #fff8eb 100%); border: 1px solid #d5d9d9; box-shadow: 0 8px 28px rgba(15,17,17,.10); }
                .eyebrow { color: #146EB4; }
                .hero p, .intro, .card p { color: var(--muted); }
                .cta { color: #111; background: #FFD814; border-radius: 999px; box-shadow: 0 2px 5px rgba(213,217,217,.55); }
                section { border-radius: 12px; background: #fff; border: 1px solid #d5d9d9; }
                .card { border-radius: 10px; background: #fff; border: 1px solid #d5d9d9; }
                """
            )
        }

        if n.contains("google") {
            theme = "#F8FAFD"; ink = "#202124"; muted = "#5f6368"; surface = "#ffffff"; soft = "#f8fafd"; line = "#e1e3e7"
            a1 = "#4285F4"; a2 = "#34A853"; font = "Roboto, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif"
            radius = "34px"; cardRadius = "22px"; bodyBackground = "radial-gradient(circle at 12% 0%, rgba(66,133,244,.15), transparent 22%), radial-gradient(circle at 82% 4%, rgba(234,67,53,.12), transparent 20%), radial-gradient(circle at 64% 28%, rgba(251,188,5,.11), transparent 18%), #f8fafd"; heroBackground = "linear-gradient(135deg, rgba(66,133,244,.10), rgba(52,168,83,.08) 45%, rgba(251,188,5,.10))"; shadow = "0 2px 10px rgba(60,64,67,.10)"
        } else if n.contains("tesla") {
            theme = "#F4F4F4"; ink = "#111111"; muted = "#666666"; surface = "#ffffff"; soft = "#f4f4f4"; line = "#dedede"
            a1 = "#111111"; a2 = "#666666"; font = "Arial, 'Helvetica Neue', sans-serif"; radius = "4px"; cardRadius = "3px"; buttonRadius = "3px"; bodyBackground = "#f4f4f4"; heroBackground = "linear-gradient(180deg, #202020 0%, #060606 100%)"; shadow = "none"
        } else if n.contains("microsoft") {
            theme = "#0F1115"; ink = "#f5f5f5"; muted = "#b6bbc4"; surface = "rgba(35,38,44,.82)"; soft = "#111318"; line = "rgba(255,255,255,.10)"
            a1 = "#0078D4"; a2 = "#4CC2FF"; font = "'Segoe UI', -apple-system, BlinkMacSystemFont, sans-serif"; radius = "16px"; cardRadius = "10px"; buttonRadius = "8px"; bodyBackground = "radial-gradient(circle at 85% -10%, rgba(0,120,212,.30), transparent 36%), #0f1115"; heroBackground = "linear-gradient(145deg, rgba(255,255,255,.09), rgba(255,255,255,.035))"; shadow = "0 22px 70px rgba(0,0,0,.35)"
        } else if n.contains("stripe") {
            theme = "#F6F9FC"; ink = "#0A2540"; muted = "#425466"; surface = "rgba(255,255,255,.90)"; soft = "#f6f9fc"; line = "rgba(10,37,64,.10)"
            a1 = "#635BFF"; a2 = "#00D4FF"; cardRadius = "18px"; bodyBackground = "linear-gradient(140deg, #f6f9fc 0%, #eef4ff 55%, #f9f2ff 100%)"; heroBackground = "linear-gradient(120deg, rgba(99,91,255,.18), rgba(0,212,255,.15), rgba(255,82,191,.12))"; shadow = "0 30px 80px rgba(50,50,93,.13)"
        } else if n.contains("airbnb") {
            theme = "#FFFDFC"; ink = "#222222"; muted = "#717171"; surface = "#ffffff"; soft = "#fffdfc"; line = "#e7e7e7"
            a1 = "#FF385C"; a2 = "#E31C5F"; radius = "34px"; buttonRadius = "12px"; bodyBackground = "#fffdfc"; heroBackground = "linear-gradient(145deg, #4b2730, #b82647 58%, #ff6b81)"; shadow = "0 22px 60px rgba(0,0,0,.14)"
        } else if n.contains("shopify") {
            theme = "#F4F7F2"; ink = "#202223"; muted = "#6D7175"; surface = "#ffffff"; soft = "#f4f7f2"; line = "#dfe3df"
            a1 = "#008060"; a2 = "#95BF47"; radius = "22px"; cardRadius = "14px"; buttonRadius = "8px"; bodyBackground = "#f4f7f2"; heroBackground = "linear-gradient(135deg, #004c3f, #008060 62%, #95BF47)"; shadow = "0 18px 50px rgba(0,76,63,.14)"
        } else if n.contains("notion") {
            theme = "#FFFFFF"; ink = "#111111"; muted = "#6b6b6b"; surface = "#ffffff"; soft = "#ffffff"; line = "#e5e5e5"
            a1 = "#111111"; a2 = "#555555"; font = "Georgia, 'Times New Roman', serif"; radius = "8px"; cardRadius = "5px"; buttonRadius = "5px"; bodyBackground = "#fff"; heroBackground = "#fff"; shadow = "0 8px 26px rgba(0,0,0,.04)"
        } else if n.contains("linear") {
            theme = "#08090B"; ink = "#f4f4f5"; muted = "#9b9ba4"; surface = "rgba(18,18,24,.86)"; soft = "#08090b"; line = "rgba(255,255,255,.09)"
            a1 = "#5E6AD2"; a2 = "#8B7CFF"; radius = "24px"; cardRadius = "14px"; buttonRadius = "9px"; bodyBackground = "radial-gradient(circle at 50% -12%, rgba(94,106,210,.32), transparent 36%), #08090b"; heroBackground = "linear-gradient(145deg, rgba(94,106,210,.13), rgba(255,255,255,.025))"; shadow = "0 30px 90px rgba(0,0,0,.46)"
        } else if n.contains("sarah") {
            theme = "#05070A"; ink = "#f7fbff"; muted = "#aeb8c6"; surface = "rgba(16,22,30,.76)"; soft = "#05070a"; line = "rgba(148,220,255,.14)"
            a1 = "#64D2FF"; a2 = "#7D6CFF"; radius = "34px"; cardRadius = "18px"; bodyBackground = "radial-gradient(circle at 12% 0%, rgba(100,210,255,.18), transparent 30%), radial-gradient(circle at 90% 10%, rgba(125,108,255,.17), transparent 30%), #05070a"; heroBackground = "linear-gradient(145deg, rgba(100,210,255,.10), rgba(125,108,255,.07), rgba(255,255,255,.02))"; shadow = "0 32px 90px rgba(0,0,0,.48)"
        }

        let darkHero = n.contains("tesla") || n.contains("microsoft") || n.contains("airbnb") || n.contains("shopify") || n.contains("linear") || n.contains("sarah") || n.contains("apple")
        let heroInk = darkHero ? "#ffffff" : ink
        let heroMuted = darkHero ? "rgba(255,255,255,.82)" : muted

        return (theme, """
        :root { --primary: \(a1); --secondary: \(a2); --ink: \(ink); --muted: \(muted); --surface: \(surface); --soft: \(soft); --line: \(line); }
        body { color: var(--ink); background: \(bodyBackground); font-family: \(font); }
        .links a { color: var(--ink); padding: 8px 12px; border-radius: \(buttonRadius); background: color-mix(in srgb, var(--surface) 75%, transparent); }
        .hero { border-radius: \(radius); color: \(heroInk); background: \(heroBackground); border: 1px solid var(--line); box-shadow: \(shadow); backdrop-filter: blur(22px); }
        .eyebrow { color: var(--primary); }
        .hero p { color: \(heroMuted); }
        .intro, .card p { color: var(--muted); }
        .cta { color: #fff; background: linear-gradient(135deg, var(--primary), var(--secondary)); border-radius: \(buttonRadius); box-shadow: 0 8px 26px color-mix(in srgb, var(--primary) 22%, transparent); }
        section { border-radius: \(radius); background: var(--surface); border: 1px solid var(--line); backdrop-filter: blur(16px); }
        .card { border-radius: \(cardRadius); background: color-mix(in srgb, var(--surface) 82%, var(--soft)); border: 1px solid var(--line); }
        """)
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
                    .fill(Color.purple.opacity(configuration.isPressed ? 0.62 : 0.90))
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
