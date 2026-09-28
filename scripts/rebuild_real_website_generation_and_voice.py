from pathlib import Path

# ------------------------------------------------------------
# 1) ChatScreenView: better voice sequencing + richer brief
# ------------------------------------------------------------
view_path = Path('SarahIA/SarahIA/Views/ChatScreenView.swift')
view = view_path.read_text()

# Objective is now required: without content, a site inevitably falls back to generic copy.
view = view.replace(
'''        case 1:
            return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !audience.isEmpty
''',
'''        case 1:
            return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !audience.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
''', 1)

view = view.replace(
'''            questionTitle(
                "Quelle est l'idée du site ?",
                subtitle: "Le nom est requis. L'objectif peut rester très court."
            )

            VStack(spacing: 12) {
                textField("Nom du site ou de la marque", text: $name)
                textField("Objectif en une phrase (facultatif)", text: $purpose)
            }
''',
'''            questionTitle(
                "Quelle est l'idée du site ?",
                subtitle: "Donne un nom et une vraie phrase sur ce que le site doit proposer. Raphaël s'en sert pour générer le contenu, pas pour afficher une maquette par défaut."
            )

            VStack(spacing: 12) {
                textField("Nom du site ou de la marque", text: $name)
                textField("Ce que le site doit proposer", text: $purpose)
            }
''', 1)

# Replace timer-based card reading by actual AVSpeechSynthesizer completion sequencing.
start = view.find('''    private func estimatedSpeechDuration(_ text: String) -> Double {''')
reader = view.find('''    private func readCurrentVoiceOptions() {''', start)
status = view.find('''    private func currentStepStatusText() -> String {''', reader)
if start == -1 or reader == -1 or status == -1:
    raise SystemExit('voice reader block not found')
sequence_reader = r'''    private func readCurrentVoiceOptions() {
        guard viewModel.isContinuousConversationActive else { return }
        let generation = UUID()
        voiceGuideGeneration = generation

        if step == 1 {
            voiceFocusedOption = nil
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.speakWebsiteGuide("Question deux. Dis-moi d'abord le nom du site. Tu peux répondre librement.")
            } else if purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.speakWebsiteGuide("Le site s'appelle \(name). Maintenant, décris en une phrase ce qu'il doit proposer ou permettre de faire.")
            } else if audience.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.speakWebsiteGuide("J'ai compris l'objectif : \(purpose). Dis-moi maintenant à qui le site s'adresse. Tu peux choisir une carte ou répondre avec tes propres mots.")
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

'''
view = view[:start] + sequence_reader + view[status:]

# Voice step 1 now captures name -> purpose -> audience, all free-form.
old_step1 = r'''        if step == 1 {
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
                    viewModel.speakWebsiteGuide("Parfait. Le site s'appellera \(name). Quel est le public visé ?")
                    return
                }
            }
        }
'''
new_step1 = r'''        if step == 1 {
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
                    viewModel.speakWebsiteGuide("Parfait. Le site s'appellera \(name). Maintenant, explique-moi en une phrase ce qu'il doit proposer.")
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
'''
if old_step1 not in view:
    raise SystemExit('step1 voice target missing')
view = view.replace(old_step1, new_step1, 1)

# Status text knows about purpose too.
view = view.replace(
'''            if audience.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Tu es à la question 2 sur 5. Le nom est \(name). Maintenant, dis-moi le public visé. Tu peux utiliser tes propres mots, il n'est pas obligé de correspondre à une carte."
            }
            return "Tu es à la question 2 sur 5. Le site s'appelle \(name), pour \(audience). Tu peux continuer vers l'ambiance graphique."
''',
'''            if purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Tu es à la question 2 sur 5. Le nom est \(name). Maintenant, décris ce que le site doit proposer ou permettre de faire."
            }
            if audience.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Tu es à la question 2 sur 5. Le nom est \(name) et l'objectif est noté. Maintenant, dis-moi le public visé avec tes propres mots."
            }
            return "Tu es à la question 2 sur 5. Le site s'appelle \(name), son objectif est \(purpose), pour \(audience). Tu peux continuer vers l'ambiance graphique."
''', 1)

# Replace fixed-delay auto-advance with TTS-completion driven advance.
old_apply = r'''    private func applyVoiceChoice(_ choice: WebsiteChoice) {
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
'''
new_apply = r'''    private func confirmVoiceChoiceAndAdvance(_ text: String, to nextStep: Int) {
        let generation = UUID()
        voiceGuideGeneration = generation
        viewModel.speakWebsiteGuideSequence(
            [text],
            onItemStart: { _ in },
            completion: {
                guard voiceGuideGeneration == generation,
                      viewModel.isShowingWebsiteBuilder else { return }
                withAnimation(.easeInOut(duration: 0.18)) { step = nextStep }
                readCurrentVoiceOptions()
            }
        )
    }

    private func applyVoiceChoice(_ choice: WebsiteChoice) {
        voiceFocusedOption = choice.title
        switch step {
        case 0:
            category = choice.title
            confirmVoiceChoiceAndAdvance("Très bien. \(choice.title) est sélectionné.", to: 1)
        case 1:
            audience = choice.title
            if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                confirmVoiceChoiceAndAdvance("Public \(choice.title) sélectionné.", to: 2)
            } else {
                viewModel.speakWebsiteGuide("Public \(choice.title) sélectionné. Il me manque encore le nom ou l'objectif du site.")
            }
        case 2:
            designMood = choice.title
            confirmVoiceChoiceAndAdvance("Ambiance \(choice.title) sélectionnée.", to: 3)
        case 3:
            visualStyle = choice.title
            confirmVoiceChoiceAndAdvance("Style \(choice.title) sélectionné. Je garde réellement cette direction graphique pour le rendu.", to: 4)
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
'''
if old_apply not in view:
    raise SystemExit('applyVoiceChoice target missing')
view = view.replace(old_apply, new_apply, 1)
view_path.write_text(view)

# ------------------------------------------------------------
# 2) MultiAgentVoiceManager: sequence handoff must not kill next speech
# ------------------------------------------------------------
voice_path = Path('SarahIA/SarahIA/Services/MultiAgentVoiceManager.swift')
voice = voice_path.read_text()
old = '''            let completion = sequenceCompletion
            clearSpeechSequence()
            completion?()
            AudioSessionManager.shared.deactivateSession()
            onSpeechFinished?()
            return
'''
new = '''            let completion = sequenceCompletion
            clearSpeechSequence()
            completion?()
            // Une completion peut immédiatement lancer la lecture de l'écran suivant.
            // Dans ce cas on ne désactive surtout pas la session audio sous la nouvelle voix.
            if !synthesizer.isSpeaking {
                AudioSessionManager.shared.deactivateSession()
                onSpeechFinished?()
            }
            return
'''
if old not in voice:
    raise SystemExit('voice sequence completion target missing')
voice = voice.replace(old, new, 1)
voice_path.write_text(voice)

# ------------------------------------------------------------
# 3) VAICodingStudio: absolutely no automatic dashboard/sample fallback
# ------------------------------------------------------------
studio_path = Path('SarahIA/SarahIA/Views/VAICodingStudioView.swift')
studio = studio_path.read_text()
studio = studio.replace(
'''                        } else {
                            startSampleStreaming(prompt: "dashboard")
                        }
''',
'''                        } else {
                            presentationMode.wrappedValue.dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                                viewModel.isShowingWebsiteBuilder = true
                            }
                        }
''', 1)
studio = studio.replace(
'''            } else {
                startSampleStreaming(prompt: "dashboard")
            }
''',
'''            } else {
                codeText = ""
                selectedTab = .editor
            }
''', 1)

# Never fabricate code during publication either.
old_deploy = '''        let currentCode = codeText.isEmpty ? (viewModel.vaiCurrentCode ?? VAICodeEngine.shared.generateWebUI(prompt: "dashboard")) : codeText
        let (liveURL, status) = VAICodeEngine.shared.deployProjectOnline(projectName: "Sarah-Live-App", htmlCode: currentCode)
'''
new_deploy = '''        let currentCode = codeText.isEmpty ? (viewModel.vaiCurrentCode ?? "") : codeText
        guard !currentCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            exportMessage = "Aucun site n'a encore été généré. Lance d'abord le créateur de site : Raphaël ne fabrique plus de dashboard de secours."
            isShowingExportAlert = true
            return
        }
        let (liveURL, status) = VAICodeEngine.shared.deployProjectOnline(projectName: "Sarah-Live-App", htmlCode: currentCode)
'''
if old_deploy not in studio:
    raise SystemExit('studio deploy fallback target missing')
studio = studio.replace(old_deploy, new_deploy, 1)
studio_path.write_text(studio)

# ------------------------------------------------------------
# 4) MultiAgentCoordinator: no fake dashboard on publish request
# ------------------------------------------------------------
coord_path = Path('SarahIA/SarahIA/Services/MultiAgentCoordinator.swift')
coord = coord_path.read_text()
old = '''            let currentCode = VAICodeEngine.shared.currentWebProjectHTML() ?? VAICodeEngine.shared.generateWebUI(prompt: "dashboard")
            let (_, status) = VAICodeEngine.shared.deployProjectOnline(projectName: "Sarah-App", htmlCode: currentCode)
'''
new = '''            guard let currentCode = VAICodeEngine.shared.currentWebProjectHTML(),
                  !currentCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                completion(AgentResponse(
                    agent: .esther,
                    text: "💻 **Raphaël**\n\nAucun vrai site n'est prêt à publier. Je ne crée plus de dashboard de secours. Dis « crée-moi un site » pour lancer le brief puis générer le fichier réel.",
                    spokenText: "Aucun site réel n'est prêt. Je ne crée plus de faux dashboard de secours."
                ))
                return
            }
            let (_, status) = VAICodeEngine.shared.deployProjectOnline(projectName: "Sarah-App", htmlCode: currentCode)
'''
if old not in coord:
    raise SystemExit('coordinator dashboard fallback target missing')
coord = coord.replace(old, new, 1)
coord_path.write_text(coord)

# ------------------------------------------------------------
# 5) VAICodeEngine: generated-from-brief HTML, no canned site asset
# ------------------------------------------------------------
engine_path = Path('SarahIA/SarahIA/Services/VAICodeEngine.swift')
engine = engine_path.read_text()
marker = '''    // Les anciens templates WebsiteBrief ont été supprimés. Le créateur de site
    // utilise maintenant l'inférence réelle pilotée par ChatViewModel.

'''
if marker not in engine:
    raise SystemExit('engine insertion marker missing')

generator = r'''    // Le créateur de site n'utilise plus de dashboard ou de page exemple.
    // Ce générateur assemble un document différent à partir du brief réel : type,
    // contenu, public, style, couleur et sections. Aucune ressource externe n'est injectée.
    public func generateWebsiteFromBrief(_ brief: WebsiteBrief) -> String {
        let cleanName = brief.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let siteName = htmlEscaped(cleanName.isEmpty ? "Projet" : cleanName)
        let purposeRaw = brief.purpose.trimmingCharacters(in: .whitespacesAndNewlines)
        let purpose = htmlEscaped(purposeRaw.isEmpty ? "Présenter clairement ce projet et permettre aux visiteurs d'agir." : purposeRaw)
        let audience = htmlEscaped(brief.audience.isEmpty ? "visiteurs" : brief.audience)
        let category = brief.category.lowercased()
        let style = brief.visualStyle.lowercased()
        let combined = brief.name + brief.category + brief.visualStyle + brief.purpose + brief.audience
        let seed = combined.unicodeScalars.reduce(17) { (($0 &* 31) &+ Int($1.value)) & 0x7fffffff }
        let layoutVariant = seed % 3

        func slug(_ value: String) -> String {
            value.lowercased()
                .folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
                .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
                .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        }

        func accentFromBrief() -> String {
            let a = brief.accent.lowercased()
            if a.contains("bleu") { return "#1677ff" }
            if a.contains("violet") { return "#7c3aed" }
            if a.contains("vert") { return "#16a34a" }
            if a.contains("orange") { return "#f97316" }
            if a.contains("rouge") { return "#ef4444" }
            if a.contains("rose") { return "#ec4899" }
            if a.contains("jaune") { return "#eab308" }
            return "#6d5dfc"
        }

        var bg = "#0a0a0b"
        var surface = "#151517"
        var text = "#f7f7f8"
        var muted = "#a7a7b1"
        var accent = accentFromBrief()
        var accent2 = "#22d3ee"
        var radius = "26px"
        var navBlur = "blur(24px)"

        if style.contains("apple") {
            bg = "#f5f5f7"; surface = "#ffffff"; text = "#1d1d1f"; muted = "#6e6e73"; accent = "#0071e3"; accent2 = "#5ac8fa"; radius = "30px"
        } else if style.contains("amazon") {
            bg = "#f3f3f3"; surface = "#ffffff"; text = "#111820"; muted = "#5f6b76"; accent = "#ff9900"; accent2 = "#146eb4"; radius = "16px"; navBlur = "none"
        } else if style.contains("google") {
            bg = "#f8fafd"; surface = "#ffffff"; text = "#202124"; muted = "#5f6368"; accent = "#4285f4"; accent2 = "#ea4335"; radius = "24px"
        } else if style.contains("microsoft") || style.contains("fluent") {
            bg = "#f3f3f3"; surface = "#ffffff"; text = "#1b1b1b"; muted = "#626262"; accent = "#0067c0"; accent2 = "#50e6ff"; radius = "12px"
        } else if style.contains("tesla") {
            bg = "#050505"; surface = "#0f0f10"; text = "#ffffff"; muted = "#b9b9bd"; accent = "#e82127"; accent2 = "#ffffff"; radius = "8px"; navBlur = "blur(10px)"
        } else if style.contains("shopify") {
            bg = "#f6f6f2"; surface = "#ffffff"; text = "#1f2d2a"; muted = "#61706b"; accent = "#008060"; accent2 = "#95bf47"; radius = "22px"
        } else if style.contains("airbnb") {
            bg = "#ffffff"; surface = "#ffffff"; text = "#222222"; muted = "#717171"; accent = "#ff385c"; accent2 = "#ff8a9d"; radius = "26px"
        } else if style.contains("stripe") {
            bg = "#0a2540"; surface = "#102f50"; text = "#ffffff"; muted = "#b5c8dc"; accent = "#635bff"; accent2 = "#00d4ff"; radius = "24px"
        } else if style.contains("sarah") {
            bg = "#05070a"; surface = "#0c141d"; text = "#f8fbff"; muted = "#8fa7ba"; accent = "#00b7ff"; accent2 = "#8b5cf6"; radius = "28px"
        }

        let sections = brief.sections.isEmpty
            ? ["Accueil", "À propos", "Produits / services", "Contact"]
            : brief.sections
        let navigation = sections.map { section in
            let id = slug(section)
            return "<a href=\"#\(id)\">\(htmlEscaped(section))</a>"
        }.joined(separator: "")

        let heroClass = layoutVariant == 0 ? "hero centered" : (layoutVariant == 1 ? "hero split" : "hero editorial")

        func categoryExperience() -> String {
            if category.contains("commerce") {
                let p1 = siteName + " Essentiel"
                let p2 = siteName + " Signature"
                let p3 = siteName + " Studio"
                let base = 29 + (seed % 23)
                return """
                <section class="generated-section" id="catalogue">
                  <div class="section-head"><span>Boutique</span><h2>Une sélection pensée pour \(audience)</h2></div>
                  <div class="product-grid">
                    <article class="product"><div class="art a1"></div><h3>\(p1)</h3><p>\(purpose)</p><strong>\(base) €</strong><button onclick="addToCart('\(p1)',\(base))">Ajouter au panier</button></article>
                    <article class="product"><div class="art a2"></div><h3>\(p2)</h3><p>Une version plus complète, cohérente avec l'identité \(siteName).</p><strong>\(base + 20) €</strong><button onclick="addToCart('\(p2)',\(base + 20))">Ajouter au panier</button></article>
                    <article class="product"><div class="art a3"></div><h3>\(p3)</h3><p>L'édition conçue pour celles et ceux qui veulent aller plus loin.</p><strong>\(base + 40) €</strong><button onclick="addToCart('\(p3)',\(base + 40))">Ajouter au panier</button></article>
                  </div>
                  <div id="cart" class="cart">Panier · <b id="cartCount">0</b> article · <b id="cartTotal">0 €</b></div>
                </section>
                """
            }
            if category.contains("restaurant") {
                return """
                <section class="generated-section" id="menu">
                  <div class="section-head"><span>Carte</span><h2>La signature \(siteName)</h2></div>
                  <div class="menu-grid">
                    <article><b>Création \(siteName)</b><span>\(18 + seed % 8) €</span><p>\(purpose)</p></article>
                    <article><b>Assiette de saison</b><span>\(22 + seed % 9) €</span><p>Une proposition courte, lisible et pensée pour \(audience).</p></article>
                    <article><b>Final maison</b><span>\(9 + seed % 5) €</span><p>Une note douce pour terminer l'expérience.</p></article>
                  </div>
                  <button class="primary" onclick="openReservation()">Réserver une table</button>
                </section>
                """
            }
            if category.contains("voyage") {
                return """
                <section class="generated-section" id="destinations">
                  <div class="section-head"><span>Explorer</span><h2>Des départs imaginés pour \(audience)</h2></div>
                  <div class="filters"><button onclick="filterCards('all')">Tout</button><button onclick="filterCards('city')">Ville</button><button onclick="filterCards('nature')">Nature</button></div>
                  <div class="destination-grid">
                    <article data-kind="city"><div class="art a1"></div><h3>Escapade urbaine</h3><p>\(purpose)</p></article>
                    <article data-kind="nature"><div class="art a2"></div><h3>Respirer ailleurs</h3><p>Un séjour plus calme, construit autour de l'expérience \(siteName).</p></article>
                    <article data-kind="city"><div class="art a3"></div><h3>Week-end signature</h3><p>Une sélection courte, claire et facile à réserver.</p></article>
                  </div>
                </section>
                """
            }
            if category.contains("portfolio") {
                return """
                <section class="generated-section" id="projets">
                  <div class="section-head"><span>Portfolio</span><h2>Le travail derrière \(siteName)</h2></div>
                  <div class="project-grid">
                    <article><div class="art a1"></div><span>Direction</span><h3>Identité \(siteName)</h3><p>\(purpose)</p></article>
                    <article><div class="art a2"></div><span>Projet</span><h3>Expérience éditoriale</h3><p>Un projet conçu pour parler directement à \(audience).</p></article>
                    <article><div class="art a3"></div><span>Étude</span><h3>Système visuel</h3><p>Une déclinaison cohérente du langage graphique sélectionné.</p></article>
                  </div>
                </section>
                """
            }
            if category.contains("evenement") {
                return """
                <section class="generated-section" id="programme">
                  <div class="section-head"><span>Programme</span><h2>\(siteName), du premier moment au dernier</h2></div>
                  <div class="timeline"><article><time>10:00</time><div><h3>Ouverture</h3><p>\(purpose)</p></div></article><article><time>14:00</time><div><h3>Temps fort</h3><p>Une séquence pensée pour \(audience).</p></div></article><article><time>18:00</time><div><h3>Final</h3><p>Clôture et rencontre.</p></div></article></div>
                  <button class="primary" onclick="showToast('Inscription enregistrée localement')">S'inscrire</button>
                </section>
                """
            }
            return """
            <section class="generated-section" id="services">
              <div class="section-head"><span>Services</span><h2>Ce que \(siteName) apporte vraiment</h2></div>
              <div class="service-grid"><article><b>Clarté</b><p>\(purpose)</p></article><article><b>Accompagnement</b><p>Un parcours conçu pour \(audience).</p></article><article><b>Résultat</b><p>Des actions simples, visibles et mesurables.</p></article></div>
            </section>
            """
        }

        func sectionHTML(_ section: String) -> String {
            let lower = section.lowercased().folding(options: .diacriticInsensitive, locale: .current)
            let id = slug(section)
            if lower.contains("accueil") { return "" }
            if lower.contains("produit") || lower.contains("service") { return categoryExperience() }
            if lower.contains("a propos") || lower.contains("apropos") {
                return """
                <section class="generated-section about" id="\(id)"><div class="section-head"><span>À propos</span><h2>\(siteName), avec une idée claire</h2></div><div class="about-grid"><p>\(purpose)</p><p>Le site est pensé d'abord pour \(audience), avec une navigation directe et une identité cohérente avec le style choisi.</p></div></section>
                """
            }
            if lower.contains("galerie") || lower.contains("photo") {
                return """
                <section class="generated-section" id="\(id)"><div class="section-head"><span>Galerie</span><h2>L'univers visuel de \(siteName)</h2></div><div class="gallery"><div class="art a1"></div><div class="art a2"></div><div class="art a3"></div><div class="art a4"></div></div></section>
                """
            }
            if lower.contains("avis") || lower.contains("temoign") {
                return """
                <section class="generated-section" id="\(id)"><div class="section-head"><span>Avis</span><h2>Ce que retiennent les visiteurs</h2></div><div class="reviews"><blockquote>« L'expérience est claire et on comprend immédiatement ce que propose \(siteName). »</blockquote><blockquote>« Une interface simple, rapide et beaucoup plus cohérente. »</blockquote><blockquote>« Le parcours va droit au but. »</blockquote></div></section>
                """
            }
            if lower.contains("faq") || lower.contains("question") {
                return """
                <section class="generated-section" id="\(id)"><div class="section-head"><span>FAQ</span><h2>Questions fréquentes</h2></div><details><summary>À qui s'adresse \(siteName) ?</summary><p>Principalement à \(audience).</p></details><details><summary>Quel est l'objectif ?</summary><p>\(purpose)</p></details><details><summary>Le site fonctionne-t-il sur mobile ?</summary><p>Oui, toute la mise en page est responsive.</p></details></section>
                """
            }
            if lower.contains("contact") {
                return """
                <section class="generated-section" id="\(id)"><div class="section-head"><span>Contact</span><h2>Parler avec \(siteName)</h2></div><form id="contactForm"><input required placeholder="Nom"><input required type="email" placeholder="E-mail"><textarea required placeholder="Votre message"></textarea><button class="primary" type="submit">Envoyer</button></form></section>
                """
            }
            return """
            <section class="generated-section" id="\(id)"><div class="section-head"><span>\(htmlEscaped(section))</span><h2>\(htmlEscaped(section)) · \(siteName)</h2></div><p class="lead">\(purpose)</p></section>
            """
        }

        var generatedSections = sections.map(sectionHTML).joined(separator: "\n")
        let lowerGenerated = generatedSections.lowercased()
        if !lowerGenerated.contains("product-grid") && !lowerGenerated.contains("menu-grid") && !lowerGenerated.contains("destination-grid") && !lowerGenerated.contains("project-grid") && !lowerGenerated.contains("timeline") && !lowerGenerated.contains("service-grid") {
            generatedSections = categoryExperience() + "\n" + generatedSections
        }

        return """
        <!doctype html>
        <html lang="fr">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
          <meta name="theme-color" content="\(bg)">
          <title>\(siteName)</title>
          <style>
            :root{--bg:\(bg);--surface:\(surface);--text:\(text);--muted:\(muted);--accent:\(accent);--accent2:\(accent2);--radius:\(radius)}
            *{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;background:var(--bg);color:var(--text);font-family:-apple-system,BlinkMacSystemFont,"SF Pro Display","Segoe UI",sans-serif;line-height:1.5;overflow-x:hidden}button,input,textarea{font:inherit}button{cursor:pointer}.shell{width:min(1180px,100%);margin:auto;padding:0 22px 72px}.nav{position:sticky;top:0;z-index:20;display:flex;align-items:center;justify-content:space-between;gap:18px;padding:16px 22px;margin:0 -22px;background:color-mix(in srgb,var(--bg) 78%,transparent);backdrop-filter:\(navBlur);-webkit-backdrop-filter:\(navBlur);border-bottom:1px solid color-mix(in srgb,var(--text) 10%,transparent)}.brand{font-weight:850;letter-spacing:-.04em}.links{display:flex;gap:8px;flex-wrap:wrap;justify-content:flex-end}.links a{color:var(--text);text-decoration:none;font-size:13px;padding:8px 11px;border-radius:999px;border:1px solid color-mix(in srgb,var(--text) 10%,transparent)}.hero{min-height:72vh;display:grid;align-items:center;gap:40px;padding:80px 0 58px;position:relative}.hero.centered{text-align:center;place-items:center}.hero.centered .hero-copy{max-width:850px}.hero.split{grid-template-columns:1.1fr .9fr}.hero.editorial{grid-template-columns:.75fr 1.25fr}.eyebrow{display:inline-flex;padding:8px 12px;border-radius:999px;background:color-mix(in srgb,var(--accent) 14%,transparent);color:var(--accent);font-size:12px;font-weight:800;text-transform:uppercase;letter-spacing:.12em}h1{font-size:clamp(52px,9vw,104px);line-height:.94;letter-spacing:-.065em;margin:18px 0;max-width:950px}.hero p,.lead{font-size:clamp(17px,2.2vw,22px);color:var(--muted);max-width:720px}.hero-art{min-height:390px;border-radius:calc(var(--radius) * 1.15);background:radial-gradient(circle at 28% 30%,var(--accent2),transparent 28%),radial-gradient(circle at 72% 60%,var(--accent),transparent 34%),linear-gradient(145deg,color-mix(in srgb,var(--surface) 92%,var(--accent) 8%),var(--surface));border:1px solid color-mix(in srgb,var(--text) 12%,transparent);box-shadow:0 35px 90px rgba(0,0,0,.20);position:relative;overflow:hidden}.hero-art:before,.hero-art:after{content:"";position:absolute;border-radius:999px;border:1px solid color-mix(in srgb,var(--text) 18%,transparent)}.hero-art:before{width:260px;height:260px;left:12%;top:14%}.hero-art:after{width:180px;height:180px;right:10%;bottom:12%}.actions{display:flex;gap:10px;flex-wrap:wrap;margin-top:28px}.primary,.secondary,.product button,.filters button{border:0;border-radius:14px;padding:12px 17px;font-weight:750}.primary,.product button{background:var(--accent);color:white}.secondary,.filters button{background:color-mix(in srgb,var(--surface) 86%,var(--text) 6%);color:var(--text);border:1px solid color-mix(in srgb,var(--text) 11%,transparent)}.generated-section{padding:78px 0;border-top:1px solid color-mix(in srgb,var(--text) 10%,transparent)}.section-head{max-width:760px;margin-bottom:30px}.section-head>span{color:var(--accent);font-weight:800;font-size:12px;text-transform:uppercase;letter-spacing:.12em}.section-head h2{font-size:clamp(34px,5vw,64px);line-height:1;letter-spacing:-.045em;margin:9px 0}.product-grid,.destination-grid,.project-grid,.service-grid,.menu-grid,.reviews,.gallery{display:grid;grid-template-columns:repeat(3,1fr);gap:15px}.product,.destination-grid article,.project-grid article,.service-grid article,.menu-grid article,.reviews blockquote,.about-grid>p,details,form{background:var(--surface);border:1px solid color-mix(in srgb,var(--text) 10%,transparent);border-radius:var(--radius);padding:20px}.product{display:flex;flex-direction:column;gap:9px}.product strong{font-size:22px}.art{min-height:180px;border-radius:calc(var(--radius) * .72);background:linear-gradient(135deg,color-mix(in srgb,var(--accent) 78%,white 6%),color-mix(in srgb,var(--accent2) 75%,black 7%));position:relative;overflow:hidden}.art:after{content:"";position:absolute;inset:20%;border-radius:45% 55% 48% 52%;background:rgba(255,255,255,.24);filter:blur(3px)}.a2{filter:hue-rotate(42deg)}.a3{filter:hue-rotate(95deg)}.a4{filter:hue-rotate(155deg)}.menu-grid article{display:grid;grid-template-columns:1fr auto;gap:6px}.menu-grid p{grid-column:1/-1}.about-grid{display:grid;grid-template-columns:1fr 1fr;gap:15px}.reviews blockquote{margin:0;font-size:18px}.gallery{grid-template-columns:1.3fr .7fr .7fr 1.3fr}.timeline{display:grid;gap:12px}.timeline article{display:grid;grid-template-columns:90px 1fr;gap:20px;padding:20px;border-radius:var(--radius);background:var(--surface);border:1px solid color-mix(in srgb,var(--text) 10%,transparent)}.timeline time{font-weight:850;color:var(--accent)}.filters{display:flex;gap:8px;margin-bottom:18px}.cart{position:sticky;bottom:16px;margin-top:18px;padding:14px 18px;border-radius:999px;background:var(--text);color:var(--bg);display:inline-flex;gap:8px;font-weight:750;box-shadow:0 18px 60px rgba(0,0,0,.25)}form{display:grid;gap:10px;max-width:700px}input,textarea{width:100%;border:1px solid color-mix(in srgb,var(--text) 13%,transparent);background:color-mix(in srgb,var(--surface) 94%,var(--text) 3%);color:var(--text);padding:13px 14px;border-radius:14px}textarea{min-height:130px;resize:vertical}details+details{margin-top:10px}summary{font-weight:750;cursor:pointer}.toast{position:fixed;right:18px;bottom:18px;padding:12px 16px;border-radius:14px;background:var(--text);color:var(--bg);font-weight:750;opacity:0;transform:translateY(10px);pointer-events:none;transition:.2s}.toast.show{opacity:1;transform:none}
            @media(max-width:760px){.shell{padding-inline:16px}.nav{margin-inline:-16px;padding-inline:16px}.links{display:none}.hero,.hero.split,.hero.editorial{grid-template-columns:1fr;min-height:auto;padding:58px 0 40px}.hero-art{min-height:300px}.product-grid,.destination-grid,.project-grid,.service-grid,.menu-grid,.reviews,.gallery,.about-grid{grid-template-columns:1fr}.generated-section{padding:54px 0}.timeline article{grid-template-columns:70px 1fr}h1{font-size:clamp(48px,16vw,78px)}}
          </style>
        </head>
        <body>
          <main class="shell">
            <nav class="nav"><div class="brand">\(siteName)</div><div class="links">\(navigation)</div></nav>
            <section class="\(heroClass)" id="accueil">
              <div class="hero-copy"><span class="eyebrow">\(htmlEscaped(brief.category)) · \(htmlEscaped(brief.visualStyle))</span><h1>\(siteName)</h1><p>\(purpose)</p><div class="actions"><a class="primary" href="#\(sections.dropFirst().first.map(slug) ?? "contact")">Découvrir</a><button class="secondary" onclick="showToast('Bienvenue chez \(siteName)')">Voir l'expérience</button></div></div>
              <div class="hero-art" aria-label="Composition visuelle générée pour \(siteName)"></div>
            </section>
            \(generatedSections)
          </main>
          <div id="toast" class="toast" role="status"></div>
          <script>
            let cartCount=0,cartTotal=0;
            function showToast(message){const t=document.getElementById('toast');t.textContent=message;t.classList.add('show');clearTimeout(window.__toastTimer);window.__toastTimer=setTimeout(()=>t.classList.remove('show'),1800)}
            function addToCart(name,price){cartCount++;cartTotal+=price;const c=document.getElementById('cartCount'),t=document.getElementById('cartTotal');if(c)c.textContent=cartCount;if(t)t.textContent=cartTotal.toFixed(0)+' €';showToast(name+' ajouté')}
            function filterCards(kind){document.querySelectorAll('[data-kind]').forEach(card=>card.style.display=(kind==='all'||card.dataset.kind===kind)?'block':'none')}
            function openReservation(){showToast('Réservation prête à être renseignée')}
            const form=document.getElementById('contactForm');if(form)form.addEventListener('submit',e=>{e.preventDefault();showToast('Message enregistré localement');form.reset()});
          </script>
        </body>
        </html>
        """
    }

'''
engine = engine.replace(marker, generator + marker, 1)
engine_path.write_text(engine)

# ------------------------------------------------------------
# 6) ChatViewModel: use generated brief HTML + browser validation, not fake neural text
# ------------------------------------------------------------
vm_path = Path('SarahIA/SarahIA/ViewModels/ChatViewModel.swift')
vm = vm_path.read_text()
start = vm.find('''    /// Génère réellement le site avec le moteur IA local à partir du brief.''')
end = vm.find('''    private func appendMessage(_ msg: Message) {''', start)
if start == -1 or end == -1:
    raise SystemExit('website generation block missing')
replacement = r'''    /// Génère le fichier du site directement depuis le brief validé.
    /// Aucun dashboard de secours, aucune page exemple et aucun faux moteur neuronal.
    public func completeWebsiteBrief(_ brief: WebsiteBrief) {
        activeAgent = .esther
        websiteDraft = brief
        isShowingWebsiteBuilder = false
        isTyping = true
        voiceStatus = .processing

        let generationID = UUID()
        websiteGenerationID = generationID

        appendMessage(Message(
            content: "💻 **Raphaël — génération du site**\n\nJe construis **\(brief.name)** à partir du nom, de l'objectif, du public, du style et des sections que tu as choisis. Aucun dashboard de secours ne sera injecté.",
            isFromUser: false
        ))

        if isContinuousConversationActive {
            speakWebsiteGuide("J'ai tout le brief. Je construis maintenant le site à partir de tes vrais choix.")
        }

        let html = VAICodeEngine.shared.generateWebsiteFromBrief(brief)
        VAICodeEngine.shared.runBrowserSmokeTest(html: html) { [weak self] report in
            DispatchQueue.main.async {
                guard let self = self, self.websiteGenerationID == generationID else { return }
                guard report.passed else {
                    self.isTyping = false
                    self.voiceStatus = self.isContinuousConversationActive ? .processing : .idle
                    self.appendMessage(Message(
                        content: "💻 **Raphaël — rendu bloqué avant publication**\n\nLe contrôle WebKit a trouvé un problème dans le site généré : \(report.details). Je n'ai pas remplacé le résultat par une page factice.",
                        isFromUser: false
                    ))
                    if self.isContinuousConversationActive {
                        self.voiceManager.speak(text: "Le contrôle du rendu a détecté un problème. Je n'ai pas mis de faux site à la place.", for: .esther)
                    }
                    return
                }

                _ = VAICodeEngine.shared.saveFile(filename: "index.html", content: html)
                self.vaiCurrentCode = html
                self.websiteDraft = brief
                self.isTyping = false
                self.voiceStatus = self.isContinuousConversationActive ? .processing : .idle

                let ready = "💻 **Raphaël — site généré et testé**\n\n**\(brief.name)** a été construit depuis ton brief et vérifié dans WebKit sur un écran iPhone. Le résultat contient son propre HTML, CSS et JavaScript, sans dashboard par défaut.\n\n🧩 Ouvrir le Studio"
                self.appendMessage(Message(content: ready, isFromUser: false))

                if self.isContinuousConversationActive {
                    self.voiceManager.speak(
                        text: "Le site \(brief.name) est construit et le rendu iPhone a passé le test. Tu peux ouvrir le Studio.",
                        for: .esther
                    )
                }
            }
        }
    }

'''
vm = vm[:start] + replacement + vm[end:]

# More natural barge-in phrases.
vm = vm.replace(
'''                    normalized.contains("ce n est pas ca") || normalized.contains("pas celui la") ||
                    normalized.contains("autre chose")
''',
'''                    normalized.contains("ce n est pas ca") || normalized.contains("pas celui la") ||
                    normalized.contains("autre chose") || normalized.contains("laisse moi parler") ||
                    normalized.contains("laisse moi") || normalized.contains("pas ca") ||
                    normalized.contains("change") || normalized.contains("je veux autre")
''', 1)
vm_path.write_text(vm)

print('Real brief website generation + voice overhaul applied')
