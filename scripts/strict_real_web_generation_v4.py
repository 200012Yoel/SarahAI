from pathlib import Path


def rep(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"Missing target: {label}")
    return text.replace(old, new, 1)

# =============================================================================
# VAICodeEngine.swift
# =============================================================================
engine_path = Path('SarahIA/SarahIA/Services/VAICodeEngine.swift')
engine = engine_path.read_text()

# Delete the old hard-coded prompt -> template generator.
start = engine.find('''    /// Générateur Web polyvalent de Raphaël.''')
end = engine.find('''    /// Génère une base SwiftUI locale''', start)
if start == -1 or end == -1:
    raise SystemExit('generateWebUI block missing')
engine = engine[:start] + '''    // Génération Web par templates supprimée : aucun dashboard, boutique ou
    // landing page prédéfini n'est fabriqué en secours.

''' + engine[end:]

# Delete the hard-coded WebsiteBrief assembler.
start = engine.find('''    /// Construit un document web à partir de toutes les valeurs du brief.''')
end = engine.find('''    // Les anciens templates WebsiteBrief ont été supprimés.''', start)
if start == -1 or end == -1:
    raise SystemExit('generateWebsiteFromBrief block missing')
engine = engine[:start] + '''    // Aucun site n'est assemblé avec des blocs HTML codés en dur. Le brief
    // passe exclusivement par le pipeline de modèles de code ci-dessous.

''' + engine[end:]

# Typed failures for honest UI/voice feedback.
marker = '''public struct SarahAgenticWebBuildResult {
    public var html: String
    public var revision: Int
    public var wasRefinement: Bool
    public var architectModel: SarahCodingModelProfile
    public var implementerModel: SarahCodingModelProfile
    public var staticAudit: SarahWebAuditReport
    public var browserAudit: SarahBrowserSmokeReport?
    public var usedRemoteModels: Bool
}
'''
if marker not in engine:
    raise SystemExit('SarahAgenticWebBuildResult marker missing')
engine = engine.replace(marker, marker + '''
public enum SarahRealWebsiteGenerationError: LocalizedError {
    case runtimeNotConfigured
    case modelGenerationFailed
    case invalidRender(String)

    public var errorDescription: String? {
        switch self {
        case .runtimeNotConfigured:
            return "Aucun moteur de code génératif réel n'est connecté. Ouvre Réglages > Sarah Engine et configure un endpoint OpenAI-compatible. Aucun template de secours ne sera utilisé."
        case .modelGenerationFailed:
            return "Le moteur de code n'a pas renvoyé un document HTML complet. Aucun faux site n'a été créé à la place."
        case .invalidRender(let details):
            return "Le HTML généré n'a pas passé le contrôle WebKit : \\(details). Aucun fallback prédéfini n'a été injecté."
        }
    }
}
''', 1)

# New project cleanup also removes stale index.html.
engine = rep(
    engine,
'''    public func resetCurrentWebProject() {
        try? FileManager.default.removeItem(at: agenticProjectURL)
    }
''',
'''    public func resetCurrentWebProject() {
        try? FileManager.default.removeItem(at: agenticProjectURL)
        try? FileManager.default.removeItem(at: workspaceDirectory.appendingPathComponent("index.html"))
    }

    public var isRealWebGenerationConfigured: Bool {
        SarahCodingRuntime.shared.isConfigured
    }
''',
    'resetCurrentWebProject'
)

# Delete local deterministic refinement and createOrRefineWebsite. They were the
# hidden fallback path back to generateWebUI.
start = engine.find('''    private func appleStyleRefinement(_ html: String) -> String {''')
end = engine.find('''    private func architectSystemPrompt() -> String {''', start)
if start == -1 or end == -1:
    raise SystemExit('deterministic refinement block missing')
engine = engine[:start] + engine[end:]

# Make both model roles explicitly generate project-specific code.
old_arch = '''    private func architectSystemPrompt() -> String {
        """
        Tu es l'architecte web de Sarah IA. Comprends précisément la demande en langage naturel, conserve les contraintes du projet déjà créé, repère les erreurs et prépare un plan exécutable pour un second modèle. Réponds uniquement avec un plan concis et structuré, sans HTML complet.
        """
    }
'''
new_arch = '''    private func architectSystemPrompt() -> String {
        """
        Tu es Raphaël Architecte. Analyse réellement chaque demande : objectif, public, contenu, hiérarchie, navigation, fonctions et direction artistique. Un nom de marque comme Apple, Google, Microsoft, Amazon ou Tesla indique seulement des principes visuels généraux : ne copie aucune page, aucun logo, aucun texte ni asset propriétaire. Si un projet existant est fourni, conserve uniquement ce qui reste pertinent. Prépare un plan spécifique à CE projet, jamais un template générique. Réponds uniquement avec un plan de réalisation structuré.
        """
    }
'''
engine = rep(engine, old_arch, new_arch, 'architect prompt')

old_impl = '''    private func implementerSystemPrompt() -> String {
        """
        Tu es le Code Worker de Sarah IA. Retourne uniquement un document HTML autonome complet avec CSS et JavaScript intégrés. Respecte le plan, préserve les fonctions déjà valides du projet existant, corrige les bugs signalés, rends le site responsive et accessible, et n'ajoute aucune fonctionnalité factice présentée comme réelle.
        """
    }
'''
new_impl = '''    private func implementerSystemPrompt() -> String {
        """
        Tu es Raphaël Code Worker. Écris réellement le site demandé. Retourne UNIQUEMENT un document HTML5 autonome complet avec CSS et JavaScript intégrés. Chaque texte, section, composant, disposition et interaction doit découler du brief et du plan. Interdiction d'utiliser un dashboard de secours, du lorem ipsum, « Produit 01 », des blocs préfabriqués, des URLs d'images factices, un CDN, une police distante, un logo de marque ou un asset propriétaire. Les références de style sont des principes visuels, jamais des copies. Le résultat doit être responsive, accessible, utilisable hors ligne et les interactions demandées doivent fonctionner réellement en JavaScript local.
        """
    }
'''
engine = rep(engine, old_impl, new_impl, 'implementer prompt')

# A model response is not persisted until it passes WebKit.
engine = rep(
    engine,
'''                let revision = (existing?.revision ?? 0) + 1
                let root = existing?.rootRequest ?? prompt
                let project = SarahPersistentWebProject(rootRequest: root, latestInstruction: prompt, html: html, revision: revision, updatedAt: Date())
                self.persistAgenticProject(project)
                completion(SarahAgenticWebBuildResult(
''',
'''                let revision = (existing?.revision ?? 0) + 1
                completion(SarahAgenticWebBuildResult(
''',
    'remote persistence before test'
)

engine = rep(
    engine,
'''            updated.html = repaired
            updated.staticAudit = self.auditWebHTML(repaired)
            if var project = self.loadAgenticProject() {
                project.html = repaired
                project.updatedAt = Date()
                self.persistAgenticProject(project)
            }
            completion(updated)
''',
'''            updated.html = repaired
            updated.staticAudit = self.auditWebHTML(repaired)
            completion(updated)
''',
    'repair persistence before test'
)

# Replace the old build function that silently fell back to createOrRefineWebsite.
start = engine.find('''    public func buildAndTestWebsite(prompt: String, completion: @escaping (SarahAgenticWebBuildResult) -> Void) {''')
if start == -1:
    raise SystemExit('old buildAndTestWebsite signature missing')
end = engine.find('\n    }\n}', start)
if end == -1:
    raise SystemExit('old buildAndTestWebsite end missing')
end += len('\n    }')
strict = r'''    public func buildAndTestWebsite(
        prompt: String,
        completion: @escaping (Result<SarahAgenticWebBuildResult, Error>) -> Void
    ) {
        guard SarahCodingRuntime.shared.isConfigured else {
            completion(.failure(SarahRealWebsiteGenerationError.runtimeNotConfigured))
            return
        }

        let previousProject = loadAgenticProject()

        let persistPassing: (SarahAgenticWebBuildResult) -> Void = { build in
            let project = SarahPersistentWebProject(
                rootRequest: previousProject?.rootRequest ?? prompt,
                latestInstruction: prompt,
                html: build.html,
                revision: build.revision,
                updatedAt: Date()
            )
            self.persistAgenticProject(project)
            completion(.success(build))
        }

        remoteAgenticBuild(prompt: prompt) { remote in
            guard let remote = remote else {
                completion(.failure(SarahRealWebsiteGenerationError.modelGenerationFailed))
                return
            }

            self.runBrowserSmokeTest(html: remote.html) { firstReport in
                if firstReport.passed && remote.staticAudit.isPassing {
                    var final = remote
                    final.browserAudit = firstReport
                    persistPassing(final)
                    return
                }

                self.repairRemoteBuild(remote, report: firstReport) { repaired in
                    let stabilized = self.stabilizeHTML(repaired.html)
                    self.runBrowserSmokeTest(html: stabilized) { secondReport in
                        var final = repaired
                        final.html = stabilized
                        final.staticAudit = self.auditWebHTML(stabilized)
                        final.browserAudit = secondReport

                        guard secondReport.passed, final.staticAudit.isPassing else {
                            completion(.failure(
                                SarahRealWebsiteGenerationError.invalidRender(secondReport.details)
                            ))
                            return
                        }
                        persistPassing(final)
                    }
                }
            }
        }
    }'''
engine = engine[:start] + strict + engine[end:]
engine_path.write_text(engine)

# =============================================================================
# ChatViewModel.swift
# =============================================================================
vm_path = Path('SarahIA/SarahIA/ViewModels/ChatViewModel.swift')
vm = vm_path.read_text()

# Natural interruption words in addition to the existing echo-overlap detection.
vm = rep(
    vm,
'''                    normalized.contains("laisse moi") || normalized.contains("pas ca") ||
                    normalized.contains("je veux autre")
''',
'''                    normalized.contains("laisse moi") || normalized.contains("pas ca") ||
                    normalized.contains("je veux autre") || normalized.contains("je veux plutot") ||
                    normalized.contains("je prefere") || normalized.contains("non plutot") ||
                    normalized.contains("change ca") || normalized.contains("annule")
''',
    'natural voice interruptions'
)

start = vm.find('''    /// Génère le site à partir d'un vrai moteur de génération de code.''')
end = vm.find('''    private func appendMessage(_ msg: Message) {''', start)
if start == -1 or end == -1:
    raise SystemExit('current website generation block missing')
new_generation = r'''    /// Génère le site uniquement avec le véritable pipeline de modèles de code.
    /// L'ancien faux chemin « modèle local téléchargé -> réponse déterministe » est supprimé.
    public func completeWebsiteBrief(_ brief: WebsiteBrief) {
        let isRefinement = websiteDraft != nil && vaiCurrentCode != nil
        activeAgent = .esther
        websiteDraft = brief
        isShowingWebsiteBuilder = false
        isTyping = true
        voiceStatus = .processing

        if !isRefinement {
            vaiCurrentCode = nil
            VAICodeEngine.shared.resetCurrentWebProject()
        }

        let generationID = UUID()
        websiteGenerationID = generationID
        let prompt = realWebsitePrompt(for: brief, isRefinement: isRefinement)

        appendMessage(Message(
            content: "💻 **Raphaël · génération réelle en cours**\n\nJe transmets ton brief au moteur de code. Aucun dashboard, aucune page type et aucun asset de secours ne seront utilisés.",
            isFromUser: false
        ))

        if isContinuousConversationActive {
            speakWebsiteGuide("J'ai tout le brief. Je lance le vrai moteur de code. Tu peux continuer à me parler et m'interrompre.")
        }

        VAICodeEngine.shared.buildAndTestWebsite(prompt: prompt) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self, self.websiteGenerationID == generationID else { return }
                self.isTyping = false
                self.voiceStatus = self.isContinuousConversationActive ? .processing : .idle

                switch result {
                case .success(let build):
                    self.vaiCurrentCode = build.html
                    self.websiteDraft = brief
                    _ = VAICodeEngine.shared.saveFile(filename: "index.html", content: build.html)

                    let audit = build.browserAudit?.details ?? "WebKit validé"
                    self.appendMessage(Message(
                        content: "💻 **Raphaël · site réellement généré**\n\n**\(brief.name)** a été écrit par le moteur de code à partir de ton brief, puis contrôlé dans WebKit.\n\nContrôle : \(audit)\nRévision : #\(build.revision)\n\n🧩 Ouvrir le Studio",
                        isFromUser: false
                    ))

                    if self.isContinuousConversationActive {
                        self.voiceManager.speak(
                            text: "Le site \(brief.name) est réellement généré et vérifié. Tu peux ouvrir le Studio ou me demander de le modifier.",
                            for: .esther
                        )
                    }

                case .failure(let error):
                    self.appendMessage(Message(
                        content: "💻 **Raphaël · génération réelle indisponible**\n\n\(error.localizedDescription)\n\nAucun faux site n'a été créé à la place.",
                        isFromUser: false
                    ))
                    if self.isContinuousConversationActive {
                        self.voiceManager.speak(
                            text: "La vraie génération n'a pas pu démarrer. Je n'ai créé aucun faux site. Vérifie le moteur de code dans les réglages Sarah Engine.",
                            for: .esther
                        )
                    }
                }
            }
        }
    }

    private func realWebsitePrompt(for brief: WebsiteBrief, isRefinement: Bool) -> String {
        let sectionList = brief.sections.joined(separator: ", ")
        let operation = isRefinement
            ? "MODIFICATION : repars du projet existant et applique ce nouveau brief sans casser les fonctions valides."
            : "NOUVEAU PROJET : conçois et écris le site depuis zéro."

        return """
        \(operation)

        BRIEF
        Type : \(brief.category)
        Nom : \(brief.name)
        Objectif : \(brief.purpose)
        Public : \(brief.audience)
        Direction graphique : \(brief.visualStyle)
        Accent : \(brief.accent)
        Sections : \(sectionList)

        CONTRAT STRICT
        - Écris un site réellement spécifique à ce brief, pas une variante de template.
        - Retourne uniquement un document HTML5 complet avec CSS et JavaScript intégrés.
        - Aucun dashboard générique, lorem ipsum, Produit 01, Offre 01 ou bloc préfabriqué.
        - Aucun CDN, police distante, logo de marque, asset propriétaire ou URL d'image factice.
        - Le style nommé est une inspiration de principes graphiques, pas une copie de la marque.
        - Les interactions utiles au type de site doivent fonctionner réellement côté navigateur.
        - N'invente pas de backend, paiement ou publication serveur si cela n'existe pas.
        - Responsive iPhone/tablette/ordinateur, accessible et utilisable hors ligne dans WKWebView.
        """
    }

'''
vm = vm[:start] + new_generation + vm[end:]
vm_path.write_text(vm)

# =============================================================================
# ChatScreenView.swift: the last voice timer is replaced by real TTS completion.
# =============================================================================
view_path = Path('SarahIA/SarahIA/Views/ChatScreenView.swift')
view = view_path.read_text()
view = rep(
    view,
'''                audience = freeAudience
                viewModel.speakWebsiteGuide("D'accord. Je retiens comme public : \\(freeAudience). On passe maintenant à l'ambiance graphique.")
                let captured = step
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                    guard step == captured else { return }
                    withAnimation(.easeInOut(duration: 0.18)) { step = 2 }
                    readCurrentVoiceOptions()
                }
                return
''',
'''                audience = freeAudience
                confirmVoiceChoiceAndAdvance(
                    "D'accord. Je retiens comme public : \\(freeAudience). On passe maintenant à l'ambiance graphique.",
                    to: 2
                )
                return
''',
    'free audience timer'
)
view_path.write_text(view)

# =============================================================================
# MultiAgentCoordinator.swift: strict Result API, no hidden local fallback.
# =============================================================================
coord_path = Path('SarahIA/SarahIA/Services/MultiAgentCoordinator.swift')
coord = coord_path.read_text()
start = coord.find('''        // 7. Projet web agentique : Raphaël conserve le projet et ses révisions.\n        else {''')
end = coord.find('''        }\n    }\n    \n    // Alias rétrocompatible''', start)
if start == -1 or end == -1:
    raise SystemExit('web agent branch missing')
branch = r'''        // 7. Projet web agentique : uniquement le vrai moteur de code.
        else {
            VAICodeEngine.shared.buildAndTestWebsite(prompt: prompt) { result in
                switch result {
                case .failure(let error):
                    completion(AgentResponse(
                        agent: .esther,
                        text: "💻 **Raphaël · génération réelle indisponible**\n\n\(error.localizedDescription)\n\nAucun dashboard ou template de secours n'a été créé.",
                        spokenText: "La génération réelle n'est pas disponible. Je n'ai pas créé de faux site à la place.",
                        openStudio: false,
                        generatedCode: nil
                    ))

                case .success(let build):
                    DevCodeInjector.injectRender(html: build.html, css: "", js: "")
                    let browserStatus = build.browserAudit?.passed == true
                        ? "✅ WebKit : rendu mobile et JavaScript validés."
                        : "⚠️ WebKit : contrôle incomplet."
                    let action = build.wasRefinement ? "mise à jour" : "création"
                    let responseText = """
                    💻 **Raphaël · Atelier Web génératif**

                    Révision **#\(build.revision)** · \(action) terminée.
                    **Moteurs :** \(build.architectModel.displayName) → \(build.implementerModel.displayName)
                    \(browserStatus)

                    Le fichier généré est `Documents/VAI_Workspace/index.html`. Tu peux maintenant demander une correction et Raphaël repartira de cette révision.
                    """

                    completion(AgentResponse(
                        agent: .esther,
                        text: responseText,
                        spokenText: "La révision \(build.revision) est réellement générée et vérifiée. Tu peux me demander une modification.",
                        openStudio: true,
                        generatedCode: build.html
                    ))
                }
            }
        }
'''
coord = coord[:start] + branch + coord[end:]
coord_path.write_text(coord)

print('Strict real web generation v4 applied')
