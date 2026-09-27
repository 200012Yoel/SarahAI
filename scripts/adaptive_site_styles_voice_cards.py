from pathlib import Path
import re

root = Path('SarahIA/SarahIA')

# ---------------- ChatViewModel: route live voice commands into the website builder ----------------
vm_path = root / 'ViewModels/ChatViewModel.swift'
vm = vm_path.read_text()

anchor = '@Published public var isShowingWebsiteBuilder: Bool = false\n'
if 'websiteVoiceCommandSequence' not in vm:
    vm = vm.replace(anchor, anchor + '    @Published public var websiteVoiceCommand: String = ""\n    @Published public var websiteVoiceCommandSequence: Int = 0\n', 1)

old_final = '''            self.liveTranscriptionText = ""
            self.sendMessage(cleaned)
'''
new_final = '''            self.liveTranscriptionText = ""

            // Quand le créateur de site est ouvert, la voix pilote directement
            // les cartes au lieu de repartir dans le chat et de casser le parcours.
            if self.isShowingWebsiteBuilder {
                self.websiteVoiceCommand = cleaned
                self.websiteVoiceCommandSequence &+= 1
                self.voiceStatus = .processing
                return
            }

            self.sendMessage(cleaned)
'''
if 'la voix pilote directement' not in vm:
    if old_final not in vm:
        raise SystemExit('ChatViewModel final transcription anchor not found')
    vm = vm.replace(old_final, new_final, 1)

speak_anchor = '''    public func speakMessage(_ text: String) {
        ensureVoicePipelinePrepared()
        haptics.buttonTap()
        voiceManager.speak(text: text, for: activeAgent)
    }
'''
if 'speakWebsiteGuide' not in vm:
    speak_new = speak_anchor + '''
    /// Lecture vocale dédiée au parcours de création de site. La session vocale
    /// reste active afin que l'utilisateur puisse interrompre Raphaël à tout moment.
    public func speakWebsiteGuide(_ text: String) {
        ensureVoicePipelinePrepared()
        guard isContinuousConversationActive else { return }
        activeAgent = .esther
        voiceManager.speak(text: text, for: .esther)
    }
'''
    if speak_anchor not in vm:
        raise SystemExit('speakMessage anchor not found')
    vm = vm.replace(speak_anchor, speak_new, 1)

vm_path.write_text(vm)

# ---------------- ChatScreenView: adaptive styles + voice driven glowing cards ----------------
view_path = root / 'Views/ChatScreenView.swift'
s = view_path.read_text()
start = s.index('private struct WebsiteBuilderFlowView: View')
end = s.index('/// Sélecteur UIKit minimal utilisé par le bouton appareil photo.', start)
b = s[start:end]

state_anchor = '''    @State private var sections: Set<String>
'''
if 'voiceFocusedOption' not in b:
    b = b.replace(state_anchor, state_anchor + '''    @State private var voiceFocusedOption: String? = nil
    @State private var voiceGuideGeneration = UUID()
''', 1)

style_start = b.index('    private let styleChoices = [')
style_end = b.index('    private let accentOptions', style_start)
new_styles = '''    /// Les directions visuelles sont adaptées au type de site choisi.
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

'''
b = b[:style_start] + new_styles + b[style_end:]

# Alias the new inspiration names to rendering engines that already change the actual HTML.
# Amazon receives its own marketplace profile below.
b = b.replace('''        let n = style.lowercased()
        var theme = "#000000"''', '''        var n = style.lowercased()
        let originalStyle = n
        if n.contains("nike") || n.contains("tesla") { n = "tesla" }
        else if n.contains("booking") || n.contains("expedia") || n.contains("opentable") { n = "airbnb" }
        else if n.contains("national geographic") || n.contains("michelin") { n = "notion" }
        else if n.contains("uber eats") || n.contains("deliveroo") { n = "shopify" }
        else if n.contains("behance") || n.contains("adobe") { n = "linear" }
        else if n.contains("salesforce") || n.contains("ticketmaster") { n = "microsoft" }
        else if n.contains("eventbrite") { n = "stripe" }
        else if n.contains("spotify") { n = "linear" }
        var theme = "#000000"''', 1)

amazon_anchor = '''        if n.contains("google") {
'''
if 'originalStyle.contains("amazon")' not in b:
    amazon_block = '''        if originalStyle.contains("amazon") {
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

'''
    if amazon_anchor not in b:
        raise SystemExit('designProfile google anchor not found')
    b = b.replace(amazon_anchor, amazon_block + amazon_anchor, 1)

# Add voice-focused state to card calls.
b = b.replace('''                        selected: category == choice.title
                    ) {''', '''                        selected: category == choice.title,
                        focused: voiceFocusedOption == choice.title
                    ) {''', 1)
b = b.replace('''                        selected: designMood == choice.title
                    ) {''', '''                        selected: designMood == choice.title,
                        focused: voiceFocusedOption == choice.title
                    ) {''', 1)
b = b.replace('''                    styleCard(number: index + 1, choice: choice, selected: visualStyle == choice.title) {''', '''                    styleCard(number: index + 1, choice: choice, selected: visualStyle == choice.title, focused: voiceFocusedOption == choice.title) {''', 1)

# Add a halo to section cards while Raphaël reads them.
b = b.replace('''                                .fill(sections.contains(section) ? Color.purple.opacity(0.24) : Color.white.opacity(0.06))''', '''                                .fill(sections.contains(section) ? Color.purple.opacity(0.24) : (voiceFocusedOption == section ? Color.purple.opacity(0.14) : Color.white.opacity(0.06)))''', 1)
b = b.replace('''                                .stroke(sections.contains(section) ? Color.purple.opacity(0.85) : Color.white.opacity(0.10), lineWidth: 1)
                        )''', '''                                .stroke((sections.contains(section) || voiceFocusedOption == section) ? Color.purple.opacity(0.95) : Color.white.opacity(0.10), lineWidth: voiceFocusedOption == section ? 2 : 1)
                        )
                        .shadow(color: voiceFocusedOption == section ? Color.purple.opacity(0.55) : .clear, radius: 18)''', 1)

# Extend choiceCard with a separate voice focus halo.
b = b.replace('''        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {''', '''        selected: Bool,
        focused: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let active = selected || focused
        return Button(action: action) {''', 1)
# First choiceCard block only, before styleCard.
choice_start = b.index('    private func choiceCard(')
style_func_start = b.index('    private func styleCard(', choice_start)
choice_block = b[choice_start:style_func_start]
choice_block = choice_block.replace('selected ? .white : .purple', 'active ? .white : .purple')
choice_block = choice_block.replace('selected ? .black : .white.opacity(0.66)', 'active ? .black : .white.opacity(0.66)')
choice_block = choice_block.replace('selected ? Color.white : Color.white.opacity(0.08)', 'active ? Color.white : Color.white.opacity(0.08)')
choice_block = choice_block.replace('selected ? .white.opacity(0.88) : .white.opacity(0.48)', 'active ? .white.opacity(0.88) : .white.opacity(0.48)')
choice_block = choice_block.replace('selected ? Color.purple.opacity(0.23) : Color.white.opacity(0.055)', 'selected ? Color.purple.opacity(0.23) : (focused ? Color.purple.opacity(0.13) : Color.white.opacity(0.055))')
choice_block = choice_block.replace('selected ? Color.purple.opacity(0.95) : Color.white.opacity(0.10), lineWidth: selected ? 1.5 : 1', '(selected || focused) ? Color.purple.opacity(0.98) : Color.white.opacity(0.10), lineWidth: focused ? 2.2 : (selected ? 1.5 : 1)')
choice_block = choice_block.replace('selected ? Color.purple.opacity(0.16) : .clear, radius: 15', 'focused ? Color.purple.opacity(0.60) : (selected ? Color.purple.opacity(0.16) : .clear), radius: focused ? 24 : 15')
b = b[:choice_start] + choice_block + b[style_func_start:]

# Extend styleCard with voice focus halo.
b = b.replace('''        choice: WebsiteStyleChoice,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {''', '''        choice: WebsiteStyleChoice,
        selected: Bool,
        focused: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let active = selected || focused
        return Button(action: action) {''', 1)
style_start2 = b.index('    private func styleCard(')
complete_start = b.index('    private func completeBrief()', style_start2)
style_block = b[style_start2:complete_start]
style_block = style_block.replace('selected ? Color.white.opacity(0.15) : Color.white.opacity(0.07)', 'active ? Color.white.opacity(0.15) : Color.white.opacity(0.07)')
style_block = style_block.replace('selected ? .white : .purple', 'active ? .white : .purple')
style_block = style_block.replace('if selected {', 'if selected || focused {')
style_block = style_block.replace('selected ? Color.purple.opacity(0.18) : Color.white.opacity(0.045)', 'selected ? Color.purple.opacity(0.18) : (focused ? Color.purple.opacity(0.12) : Color.white.opacity(0.045))')
style_block = style_block.replace('selected ? Color.purple.opacity(0.95) : Color.white.opacity(0.10), lineWidth: selected ? 1.5 : 1', '(selected || focused) ? Color.purple.opacity(0.98) : Color.white.opacity(0.10), lineWidth: focused ? 2.2 : (selected ? 1.5 : 1)')
style_block = style_block.replace('''            )
        }
        .buttonStyle(.plain)''', '''            )
            .shadow(color: focused ? Color.purple.opacity(0.60) : .clear, radius: focused ? 24 : 0)
        }
        .buttonStyle(.plain)''', 1)
b = b[:style_start2] + style_block + b[complete_start:]

# Add onAppear/onChange to keep voice active and let it control the sheet.
body_anchor = '''        .preferredColorScheme(.dark)
    }

    private var header: some View {'''
if 'websiteVoiceCommandSequence' not in b:
    body_new = '''        .preferredColorScheme(.dark)
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

    private var header: some View {'''
    if body_anchor not in b:
        raise SystemExit('builder body anchor not found')
    b = b.replace(body_anchor, body_new, 1)

# Voice helpers inserted before completeBrief.
if 'private func handleWebsiteVoiceCommand' not in b:
    helpers = r'''    private func normalizedVoiceText(_ text: String) -> String {
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

'''
    marker = '    private func completeBrief()'
    if marker not in b:
        raise SystemExit('completeBrief marker not found')
    b = b.replace(marker, helpers + marker, 1)

s = s[:start] + b + s[end:]
view_path.write_text(s)

print('Adaptive site styles and voice-guided card selection applied.')
