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
                    onRegenerate: { message in
                        let prompt = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !prompt.isEmpty else { return }
                        keyboard.dismiss()
                        viewModel.cancelCurrentGeneration()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                            viewModel.sendMessage(prompt)
                        }
                    },
                    onOpenStudio: {
                        viewModel.isShowingVAICodingStudio = true
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .allowsHitTesting(false)
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
                        contextRibbon
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

    private var stepTitle: String {
        switch step {
        case 0: return "Type de site"
        case 1: return "Identité et public"
        case 2: return "Ambiance"
        case 3: return "Style du site"
        default: return "Sections"
        }
    }

    private var selectedContextSummary: String {
        switch step {
        case 0:
            return category.isEmpty ? "Aucun type choisi" : category
        case 1:
            if name.isEmpty { return "Nom à définir" }
            if audience.isEmpty { return "\(name) · public à définir" }
            return "\(name) · \(audience)"
        case 2:
            return designMood.isEmpty ? "Ambiance à choisir" : "\(designMood) · \(accent)"
        case 3:
            return visualStyle.isEmpty ? "Style adapté à \(category.isEmpty ? "ton site" : category)" : visualStyle
        default:
            return sections.isEmpty ? "Aucune section" : "\(sections.count) section\(sections.count > 1 ? "s" : "") sélectionnée\(sections.count > 1 ? "s" : "")"
        }
    }

    private var contextRibbon: some View {
        HStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.18))
                Image(systemName: viewModel.isContinuousConversationActive ? "waveform" : "wand.and.stars")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.purple)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(stepTitle)
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white)
                Text(selectedContextSummary)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.56))
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if viewModel.isContinuousConversationActive {
                Text("Voix active")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.purple)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.purple.opacity(0.13)))
            } else {
                Text("Touchez ou parlez")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.white.opacity(0.44))
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
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
                        voiceGuideGeneration = UUID()
                        voiceFocusedOption = nil
                        category = choice.title
                        if viewModel.isContinuousConversationActive {
                            viewModel.speakWebsiteGuide("\(choice.title) sélectionné. Tu peux continuer quand tu veux.")
                        }
                    }
                }
            }

        case 1:
            questionTitle(
                "Quelle est l'idée du site ?",
                subtitle: "Donne un nom et explique ce que le site doit réellement proposer. Raphaël s'en sert pour construire le contenu."
            )

            VStack(spacing: 12) {
                textField("Nom du site ou de la marque", text: $name)
                textField("Ce que le site doit proposer", text: $purpose)
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
                        voiceGuideGeneration = UUID()
                        voiceFocusedOption = nil
                        designMood = choice.title
                        if viewModel.isContinuousConversationActive {
                            viewModel.speakWebsiteGuide("Ambiance \(choice.title) sélectionnée.")
                        }
                    }
                }
            }

            chipSection(title: "Couleur d’accent", options: accentOptions, selection: $accent)

        case 3:
            questionTitle(
                "Quelle direction graphique veux-tu ?",
                subtitle: "Les styles ci-dessous sont adaptés à \(category.isEmpty ? "ton type de site" : category). Tu peux dire simplement Apple, Amazon, Microsoft ou le nom partiel d'un style."
            )

            VStack(spacing: 12) {
                ForEach(Array(styleChoices.enumerated()), id: \.element.id) { index, choice in
                    styleCard(number: index + 1, choice: choice, selected: visualStyle == choice.title, focused: voiceFocusedOption == choice.title) {
                        HapticService.shared.buttonTap()
                        voiceGuideGeneration = UUID()
                        voiceFocusedOption = nil
                        visualStyle = choice.title
                        if viewModel.isContinuousConversationActive {
                            viewModel.speakWebsiteGuide("Style \(choice.title) sélectionné. Je garde cette direction graphique pour le site.")
                        }
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
                        voiceGuideGeneration = UUID()
                        voiceFocusedOption = nil
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
                    voiceGuideGeneration = UUID()
                    if viewModel.isContinuousConversationActive {
                        viewModel.cancelWebsiteGuideSpeech()
                    }
                    withAnimation(.easeInOut(duration: 0.18)) { step -= 1 }
                    announceCurrentStepAfterManualNavigation()
                }
                .buttonStyle(WebsiteSecondaryButtonStyle())
            }

            Button(step == 4 ? "Créer avec Raphaël" : "Continuer") {
                HapticService.shared.buttonTap()
                voiceGuideGeneration = UUID()
                if viewModel.isContinuousConversationActive {
                    viewModel.cancelWebsiteGuideSpeech()
                }
                if step == 4 {
                    completeBrief()
                } else {
                    withAnimation(.easeInOut(duration: 0.18)) { step += 1 }
                    announceCurrentStepAfterManualNavigation()
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
            return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !audience.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                        voiceGuideGeneration = UUID()
                        voiceFocusedOption = nil
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
        let iconColor: Color = active ? .white : .purple
        let badgeForeground: Color = active ? .black : .white.opacity(0.66)
        let badgeBackground: Color = active ? .white : .white.opacity(0.08)
        let detailColor: Color = active ? .white.opacity(0.88) : .white.opacity(0.48)

        let fillColor: Color
        if selected {
            fillColor = .purple.opacity(0.23)
        } else if focused {
            fillColor = .purple.opacity(0.13)
        } else {
            fillColor = .white.opacity(0.055)
        }

        let strokeColor: Color = active ? .purple.opacity(0.98) : .white.opacity(0.10)
        let strokeWidth: CGFloat = focused ? 2.2 : (selected ? 1.5 : 1.0)
        let shadowColor: Color = focused ? .purple.opacity(0.60) : (selected ? .purple.opacity(0.16) : .clear)
        let shadowRadius: CGFloat = focused ? 24 : 15

        return Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(iconColor)
                    Spacer()
                    Text("\(number)")
                        .font(.caption.weight(.bold))
                        .foregroundColor(badgeForeground)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(badgeBackground))
                }

                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(detail)
                    .font(.caption)
                    .foregroundColor(detailColor)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(fillColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(strokeColor, lineWidth: strokeWidth)
            )
            .shadow(color: shadowColor, radius: shadowRadius)
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
        let iconBackground: Color = active ? .white.opacity(0.15) : .white.opacity(0.07)
        let iconColor: Color = active ? .white : .purple

        let fillColor: Color
        if selected {
            fillColor = .purple.opacity(0.18)
        } else if focused {
            fillColor = .purple.opacity(0.12)
        } else {
            fillColor = .white.opacity(0.045)
        }

        let strokeColor: Color = active ? .purple.opacity(0.98) : .white.opacity(0.10)
        let strokeWidth: CGFloat = focused ? 2.2 : (selected ? 1.5 : 1.0)
        let shadowColor: Color = focused ? .purple.opacity(0.60) : .clear
        let shadowRadius: CGFloat = focused ? 24 : 0

        return Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(iconBackground)
                    Image(systemName: choice.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(number). \(choice.title)")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        if active {
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
                    .fill(fillColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(strokeColor, lineWidth: strokeWidth)
            )
            .shadow(color: shadowColor, radius: shadowRadius)
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

    private func readCurrentVoiceOptions() {
        guard viewModel.isContinuousConversationActive else { return }
        let generation = UUID()
        voiceGuideGeneration = generation

        if step == 1 {
            voiceFocusedOption = nil
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.speakWebsiteGuide("Question deux. Dis-moi d'abord le nom du site. Tu peux répondre librement.")
            } else if purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.speakWebsiteGuide("Le site s'appelle \(name). Maintenant, explique-moi en une phrase ce qu'il doit proposer ou permettre de faire.")
            } else if audience.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.speakWebsiteGuide("J'ai compris l'objectif : \(purpose). Dis-moi maintenant à qui le site s'adresse. Tu peux choisir une carte ou répondre librement.")
            } else {
                viewModel.speakWebsiteGuide("J'ai le nom, l'objectif et le public. Tu peux dire suivant pour choisir l'ambiance graphique.")
            }
            return
        }

        let choices = currentVoiceChoices
        guard !choices.isEmpty else { return }
        let spokenItems = choices.enumerated().map { index, choice in
            "Option \(index + 1). \(choice.title). \(choice.detail)."
        } + ["Tu peux dire le nom, le numéro, ou dire celui-là pendant qu'une carte est éclairée."]

        viewModel.speakWebsiteGuideSequence(
            spokenItems,
            onItemStart: { index in
                guard voiceGuideGeneration == generation,
                      viewModel.isShowingWebsiteBuilder else { return }
                withAnimation(.easeInOut(duration: 0.22)) {
                    voiceFocusedOption = index < choices.count ? choices[index].title : nil
                }
            },
            completion: {
                guard voiceGuideGeneration == generation else { return }
                withAnimation(.easeInOut(duration: 0.22)) {
                    voiceFocusedOption = nil
                }
            }
        )
    }

    private func currentStepStatusText() -> String {
        switch step {
        case 0:
            if category.isEmpty {
                return "Tu es à la question 1 sur 5. Choisis le type de site : e-commerce, voyage, restaurant, portfolio, entreprise ou événement."
            }
            return "Tu es à la question 1 sur 5. Le type \(category) est sélectionné. Tu peux continuer ou choisir une autre carte."
        case 1:
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Tu es à la question 2 sur 5. Il me faut d'abord le nom du site. Tu peux me le dire librement."
            }
            if purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Tu es à la question 2 sur 5. Le nom est \(name). Maintenant, explique ce que le site doit réellement proposer."
            }
            if audience.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Tu es à la question 2 sur 5. Le nom et l'objectif sont notés. Maintenant, dis-moi le public visé avec tes propres mots."
            }
            return "Tu es à la question 2 sur 5. Le site s'appelle \(name), son objectif est \(purpose), pour \(audience). Tu peux continuer vers l'ambiance graphique."
        case 2:
            let modes = moodChoices.map(\.title).joined(separator: ", ")
            if designMood.isEmpty {
                return "Tu es à la question 3 sur 5. Choisis l'ambiance graphique. Les modes sont : \(modes)."
            }
            return "Tu es à la question 3 sur 5. L'ambiance \(designMood) est sélectionnée. Les modes disponibles sont : \(modes)."
        case 3:
            let modes = styleChoices.map(\.title).joined(separator: ", ")
            if visualStyle.isEmpty {
                return "Tu es à la question 4 sur 5. Il faut choisir le mode visuel du site. Pour \(category), les modes sont : \(modes)."
            }
            return "Tu es à la question 4 sur 5. Le mode \(visualStyle) est sélectionné. Pour \(category), les autres modes disponibles sont : \(modes)."
        default:
            let selected = sections.sorted().joined(separator: ", ")
            if selected.isEmpty {
                return "Tu es à la question 5 sur 5. Choisis les sections du site : \(sectionOptions.joined(separator: ", "))."
            }
            return "Tu es à la question 5 sur 5. Les sections sélectionnées sont : \(selected). Tu peux encore en ajouter ou dire suivant pour créer le site."
        }
    }

    private func speakCurrentStepStatus() {
        voiceGuideGeneration = UUID()
        voiceFocusedOption = nil
        viewModel.speakWebsiteGuide(currentStepStatusText())
    }

    private func announceCurrentStepAfterManualNavigation() {
        guard viewModel.isContinuousConversationActive else { return }
        let expectedStep = step
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            guard step == expectedStep,
                  viewModel.isShowingWebsiteBuilder,
                  viewModel.isContinuousConversationActive else { return }
            speakCurrentStepStatus()
        }
    }

    private func aliasesForVoiceChoice(_ choice: WebsiteChoice) -> [String] {
        let title = normalizedVoiceText(choice.title)
        var aliases = [title]

        switch step {
        case 0:
            if title.contains("e commerce") { aliases += ["e commerce", "ecommerce", "commerce", "boutique", "magasin", "shop"] }
            if title.contains("voyage") { aliases += ["voyage", "travel", "vacances", "tourisme"] }
            if title.contains("restaurant") { aliases += ["restaurant", "resto", "cuisine", "menu"] }
            if title.contains("portfolio") { aliases += ["portfolio", "book", "projets", "travaux"] }
            if title.contains("entreprise") { aliases += ["entreprise", "societe", "business", "corporate", "pro"] }
            if title.contains("evenement") { aliases += ["evenement", "event", "concert", "conference"] }
        case 2:
            if title.contains("minimaliste") { aliases += ["minimaliste", "minimal", "simple", "epure", "epuree"] }
            if title.contains("elegant") { aliases += ["elegant", "elegance", "raffine", "raffinee", "premium"] }
            if title.contains("energique") { aliases += ["energique", "dynamique", "vif", "colore", "coloree"] }
            if title.contains("luxe") { aliases += ["luxe", "luxueux", "haut de gamme", "prestige"] }
            if title.contains("naturel") { aliases += ["naturel", "nature", "organique", "doux"] }
            if title.contains("tech") { aliases += ["tech", "technologie", "futuriste", "numerique"] }
        case 3:
            let brandAliases: [(String, [String])] = [
                ("apple", ["apple", "iphone", "ios"]),
                ("amazon", ["amazon", "amazone", "marketplace"]),
                ("shopify", ["shopify", "shopi"]),
                ("google", ["google", "material"]),
                ("nike", ["nike"]),
                ("microsoft", ["microsoft", "fluent", "windows"]),
                ("stripe", ["stripe"]),
                ("sarah", ["sarah", "sara"]),
                ("airbnb", ["airbnb", "air bnb"]),
                ("booking", ["booking"]),
                ("expedia", ["expedia"]),
                ("national geographic", ["national geographic", "national geo"]),
                ("tesla", ["tesla"]),
                ("michelin", ["michelin"]),
                ("uber eats", ["uber eats", "ubereats", "uber"]),
                ("deliveroo", ["deliveroo"]),
                ("opentable", ["opentable", "open table"]),
                ("notion", ["notion"]),
                ("behance", ["behance"]),
                ("adobe", ["adobe"]),
                ("linear", ["linear"]),
                ("salesforce", ["salesforce"]),
                ("eventbrite", ["eventbrite"]),
                ("ticketmaster", ["ticketmaster"]),
                ("spotify", ["spotify"])
            ]
            for (brand, words) in brandAliases where title.contains(brand) {
                aliases += words
            }
        default:
            if title.contains("accueil") { aliases += ["accueil", "home"] }
            if title.contains("a propos") { aliases += ["a propos", "presentation", "qui sommes nous"] }
            if title.contains("produits") { aliases += ["produits", "services", "catalogue"] }
            if title.contains("galerie") { aliases += ["galerie", "photos", "images"] }
            if title.contains("avis") { aliases += ["avis", "temoignages", "clients"] }
            if title.contains("faq") { aliases += ["faq", "questions", "questions frequentes"] }
            if title.contains("contact") { aliases += ["contact", "nous contacter"] }
        }

        return Array(Set(aliases.map(normalizedVoiceText).filter { !$0.isEmpty }))
    }

    private func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs)
        let b = Array(rhs)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0...b.count)
        for (i, ca) in a.enumerated() {
            var current = [i + 1] + Array(repeating: 0, count: b.count)
            for (j, cb) in b.enumerated() {
                let cost = ca == cb ? 0 : 1
                current[j + 1] = min(
                    min(current[j] + 1, previous[j + 1] + 1),
                    previous[j] + cost
                )
            }
            previous = current
        }
        return previous[b.count]
    }

    private func bestVoiceChoice(for normalized: String, choices: [WebsiteChoice]) -> WebsiteChoice? {
        for choice in choices {
            let aliases = aliasesForVoiceChoice(choice)
            if aliases.contains(where: { alias in
                normalized == alias || normalized.contains(" " + alias + " ") ||
                normalized.hasPrefix(alias + " ") || normalized.hasSuffix(" " + alias) ||
                normalized.contains(alias)
            }) {
                return choice
            }
        }

        let spokenWords = normalized.split(separator: " ").map(String.init)
        var best: (choice: WebsiteChoice, distance: Int)? = nil
        for choice in choices {
            for alias in aliasesForVoiceChoice(choice) {
                guard !alias.contains(" "), alias.count >= 5 else { continue }
                for word in spokenWords where word.count >= 5 {
                    let distance = editDistance(word, alias)
                    let allowed = max(word.count, alias.count) >= 8 ? 2 : 1
                    if distance <= allowed && (best == nil || distance < best!.distance) {
                        best = (choice, distance)
                    }
                }
            }
        }
        return best?.choice
    }

    private func refersToFocusedChoice(_ normalized: String) -> Bool {
        let phrases = [
            "celui la", "celle la", "ce style", "ce mode", "cette option", "cette carte",
            "je prends celui", "je prends celle", "je veux celui", "je veux celle",
            "garde celui", "garde celle", "choisis celui", "choisis celle"
        ]
        return phrases.contains(where: normalized.contains)
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

    private func confirmVoiceChoiceWithoutAdvance(_ text: String) {
        voiceGuideGeneration = UUID()
        voiceFocusedOption = nil
        viewModel.speakWebsiteGuide(text + " Je reste sur cette question. Dis suivant quand tu veux continuer.")
    }

    private func applyVoiceChoice(_ choice: WebsiteChoice) {
        voiceFocusedOption = choice.title
        switch step {
        case 0:
            category = choice.title
            confirmVoiceChoiceWithoutAdvance("Très bien. \(choice.title) est sélectionné.")
        case 1:
            audience = choice.title
            if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                confirmVoiceChoiceWithoutAdvance("Public \(choice.title) sélectionné.")
            } else {
                viewModel.speakWebsiteGuide("Public \(choice.title) sélectionné. Il me manque encore le nom ou l'objectif du site.")
            }
        case 2:
            designMood = choice.title
            confirmVoiceChoiceWithoutAdvance("Ambiance \(choice.title) sélectionnée.")
        case 3:
            visualStyle = choice.title
            confirmVoiceChoiceWithoutAdvance("Style \(choice.title) sélectionné. Cette direction sera réellement utilisée dans le rendu.")
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

        if normalized.contains("j en suis ou") || normalized.contains("on en est ou") ||
            normalized.contains("je suis ou") || normalized.contains("on est ou") ||
            normalized.contains("je fais quoi") || normalized.contains("je dois faire quoi") ||
            normalized.contains("qu est ce que je fais") || normalized.contains("qu est ce qu il faut") ||
            normalized.contains("c est quoi l etape") || normalized.contains("quelle etape") ||
            normalized.contains("quel mode je dois") || normalized.contains("quel mode maintenant") {
            speakCurrentStepStatus()
            return
        }

        if normalized.contains("repete") || normalized.contains("lis moi") || normalized.contains("lire les") ||
            normalized.contains("quelles options") || normalized.contains("quels choix") ||
            normalized.contains("quels styles") || normalized.contains("formes de site") ||
            normalized.contains("types de site") || normalized.contains("propose moi") {
            readCurrentVoiceOptions()
            return
        }

        if normalized.contains("retour") || normalized.contains("precedent") || normalized.contains("reviens") {
            if step > 0 {
                viewModel.cancelWebsiteGuideSpeech()
                withAnimation(.easeInOut(duration: 0.18)) { step -= 1 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    guard viewModel.isShowingWebsiteBuilder else { return }
                    readCurrentVoiceOptions()
                }
            }
            return
        }

        if normalized == "suivant" || normalized.contains("continue") || normalized.contains("valide") || normalized.contains("c est bon") {
            if canContinue {
                viewModel.cancelWebsiteGuideSpeech()
                if step == 4 {
                    completeBrief()
                } else {
                    withAnimation(.easeInOut(duration: 0.18)) { step += 1 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        guard viewModel.isShowingWebsiteBuilder else { return }
                        readCurrentVoiceOptions()
                    }
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
                    name = proposed.prefix(1).uppercased() + String(proposed.dropFirst())
                    viewModel.speakWebsiteGuide("Parfait. Le site s'appellera \(name). Maintenant, explique-moi ce qu'il doit proposer.")
                    return
                }
            } else if purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let proposedPurpose = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if !proposedPurpose.isEmpty {
                    purpose = proposedPurpose
                    viewModel.speakWebsiteGuide("D'accord. J'ai noté l'objectif. Maintenant, à qui s'adresse le site ?")
                    return
                }
            }
        }

        let choices = currentVoiceChoices

        if refersToFocusedChoice(normalized),
           let focusedTitle = voiceFocusedOption,
           let focusedChoice = choices.first(where: { $0.title == focusedTitle }) {
            applyVoiceChoice(focusedChoice)
            return
        }

        if let semanticChoice = bestVoiceChoice(for: normalized, choices: choices) {
            applyVoiceChoice(semanticChoice)
            return
        }
        if let index = voiceChoiceIndex(from: normalized, count: choices.count) {
            applyVoiceChoice(choices[index])
            return
        }

        // Le public n'est pas limité aux puces affichées. Une formulation libre
        // comme « tout public », « joueurs et familles » ou toute autre phrase
        // devient directement le public du brief au lieu d'être rejetée.
        if step == 1,
           !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let freeAudience = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !freeAudience.isEmpty {
                audience = freeAudience
                confirmVoiceChoiceWithoutAdvance(
                    "D'accord. Je retiens comme public : \(freeAudience)."
                )
                return
            }
        }

        viewModel.speakWebsiteGuide("Je n'ai pas reconnu ce choix sur l'étape actuelle. Tu peux dire répète, demander j'en suis où, donner le numéro d'une carte, ou dire directement le nom de l'option.")
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

        viewModel.completeWebsiteBrief(brief)
        dismiss()
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
