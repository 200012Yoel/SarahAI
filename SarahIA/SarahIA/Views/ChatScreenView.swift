import SwiftUI

/// Écran principal de discussion 100% natif SwiftUI avec interface multi-agents,
/// disposition fixe Header / Messages / Barre basse au-dessus du clavier,
/// Voice Orb plein écran et Studio VAI Coding.
@available(iOS 15.0, *)
public struct ChatScreenView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject private var keyboard = KeyboardObserver.shared
    @Binding var isShowingSettings: Bool
    
    @State private var isShowingActionSheet: Bool = false
    @State private var isShowingVoiceCallScreen: Bool = false
    
    public init(viewModel: ChatViewModel, isShowingSettings: Binding<Bool>) {
        self.viewModel = viewModel
        self._isShowingSettings = isShowingSettings
    }
    
    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.top, 4)
                    .padding(.bottom, 4)

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
                .contentShape(Rectangle())
                .onTapGesture {
                    keyboard.dismiss()
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MessageBar(
                text: $viewModel.inputText,
                activeAgent: $viewModel.activeAgent,
                isRecording: viewModel.isMicRunning,
                onSend: { text in
                    viewModel.sendMessage(text)
                },
                onToggleMic: {
                    viewModel.toggleMicrophone()
                },
                onOpenVoiceOrb: {
                    keyboard.dismiss()
                    viewModel.isShowingVoiceOrbModal = true
                },
                onOpenVAICoding: {
                    viewModel.isShowingVAICodingStudio = true
                }
            )
            .background(Color.black.opacity(0.97))
        }
        .sheet(isPresented: $viewModel.isShowingVoiceOrbModal) {
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
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSNotification.Name("SarahPresentVoiceCallModal")
            )
        ) { _ in
            isShowingVoiceCallScreen = true
        }
        .actionSheet(isPresented: $isShowingActionSheet) {
            ActionSheet(
                title: Text("Écosystème Développeur & Multi-Agents"),
                buttons: [
                    .default(Text("📞 Appel Vocal WebRTC & Traduction IA")) {
                        if WebRTCVoiceCallManager.shared.callState == .idle,
                           let c = VoiceCallContactManager.shared.contacts.first {
                            WebRTCVoiceCallManager.shared.startOutboundCall(to: c)
                        }
                        isShowingVoiceCallScreen = true
                    },
                    .default(Text("🎨 Générer une Image HD (Local CoreML / Metal)")) {
                        viewModel.inputText = "Génère une photo de "
                    },
                    .default(Text("🎵 Composer une Musique 100% Locale (DSP)")) {
                        viewModel.inputText = "Génère une musique lo-fi"
                    },
                    .default(Text("👁️ Vision & Analyse Multimodale (OCR)")) {
                        viewModel.inputText = "Analyse cette photo et décris ce que tu vois"
                    },
                    .default(Text("📱 Nathan — Publier sur les Réseaux Sociaux")) {
                        viewModel.activeAgent = .nathan
                        viewModel.sendMessage("Nathan, quels sont mes réseaux sociaux connectés ?")
                    },
                    .default(Text("🎨 Ethel — Créativité & Studio Graphique")) {
                        viewModel.activeAgent = .ethel
                        viewModel.sendMessage("Bonjour Ethel ! Raconte-moi ce que tu prépares.")
                    },
                    .default(Text("🎵 Nathan — Générer une Musique Rapide")) {
                        viewModel.activeAgent = .nathan
                        viewModel.inputText = "Compose une musique "
                    },
                    .default(Text("🤖 Nathan — Meilleurs modèles d'IA")) {
                        viewModel.activeAgent = .nathan
                        viewModel.sendMessage("Quels sont les meilleurs modèles d'IA disponibles en ce moment ?")
                    },
                    .default(Text("💻 Studio Raphaël — Code & prototypes")) {
                        viewModel.activeAgent = .esther
                        viewModel.isShowingVAICodingStudio = true
                    },
                    .default(Text("🐙 Se Connecter à GitHub")) {
                        viewModel.activeAgent = .esther
                        viewModel.sendMessage("Connecte-toi à GitHub")
                    },
                    .default(Text("📧 Boîte Google Gmail")) {
                        viewModel.activeAgent = .esther
                        viewModel.sendMessage("Ouvre mes mails Gmail")
                    },
                    .default(Text("🔮 Ouvrir le mode vocal")) {
                        viewModel.isShowingVoiceOrbModal = true
                    },
                    .default(Text("🇮🇱 Traduction Hébreu ⇄ Français (Yohan)")) {
                        viewModel.activeAgent = .yohan
                        viewModel.inputText = "Comment on dit en hébreu : "
                    },
                    .default(Text("🌍 Débat Géopolitique & Histoire (Tom)")) {
                        viewModel.activeAgent = .tom
                        viewModel.inputText = "Raconte-moi l'histoire de "
                    },
                    .default(Text("👑 Parler à Sarah (Pilote)")) {
                        viewModel.activeAgent = .sarah
                        viewModel.introduceSarah()
                    },
                    .cancel(Text("Annuler"))
                ]
            )
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
            // Le mode vocal s'ouvre immédiatement en grand.
            // Le geste de descente standard d'iOS permet de revenir au chat.
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
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
        HStack(spacing: 10) {
            topBarButton(systemName: "line.3.horizontal") {
                HapticService.shared.buttonTap()
                keyboard.dismiss()
                viewModel.openDrawer()
            }
            .accessibilityLabel("Ouvrir le menu")

            Spacer(minLength: 8)

            Button {
                HapticService.shared.buttonTap()
                keyboard.dismiss()
                viewModel.isShowingVoiceOrbModal = true
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.activeAgent.themeColor)
                        .frame(width: 7, height: 7)

                    Text(viewModel.activeAgent.displayName)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Image(systemName: "waveform")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.42))
                }
                .padding(.horizontal, 10)
                .frame(height: 38)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.045))
                )
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Ouvrir le mode vocal avec \(viewModel.activeAgent.displayName)")

            Spacer(minLength: 8)

            topBarButton(systemName: "gearshape") {
                HapticService.shared.buttonTap()
                keyboard.dismiss()
                isShowingSettings = true
            }
            .accessibilityLabel("Ouvrir les paramètres")
        }
        .padding(.horizontal, 12)
    }

    private func topBarButton(
        systemName: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.105))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.05), lineWidth: 0.7)
                )
        }
        .buttonStyle(ScaleBounceButtonStyle())
    }

}

/// Brief conservé entre une première maquette et ses améliorations.
/// Il ne représente jamais un site déjà publié : le rendu est d'abord local dans le Studio VAI.
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
        let normalized = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let creationWords = [
            "site internet", "site web", "site e-commerce", "site ecommerce",
            "genere un site", "creer un site", "creation de site", "fabrique un site",
            "faire un site", "lance un site"
        ]
        return creationWords.contains { normalized.contains($0) } || isRefinementRequest(text)
    }

    public static func isRefinementRequest(_ text: String) -> Bool {
        let normalized = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return ["ameliore le site", "ameliorer le site", "modifie le site", "modifier le site", "refais le site", "maquette"].contains {
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
    private let styles = ["Minimaliste", "Élégant", "Énergique", "Luxe", "Naturel", "Tech"]
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
                        .background(RoundedRectangle(cornerRadius: 14).fill(sections.contains(section) ? Color.purple.opacity(0.72) : Color.white.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(sections.contains(section) ? Color.purple : Color.white.opacity(0.12), lineWidth: 1))
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
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.09)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.13), lineWidth: 1))
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
            .background(RoundedRectangle(cornerRadius: 18).fill(selected ? Color.purple.opacity(0.72) : Color.white.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(selected ? Color.purple : Color.white.opacity(0.12), lineWidth: 1))
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
