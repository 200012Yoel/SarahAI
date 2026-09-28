from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"Missing patch target: {label}")
    return text.replace(old, new, 1)

# -----------------------------------------------------------------------------
# 1) VAICodeEngine: remove every HTML template/fallback and require the real
#    coding runtime. A failed/missing model now fails visibly instead of showing
#    a fake dashboard or a procedural page.
# -----------------------------------------------------------------------------
engine_path = Path('SarahIA/SarahIA/Services/VAICodeEngine.swift')
engine = engine_path.read_text()

# Remove the old prompt-switch template generator completely.
start = engine.find('''    /// Générateur Web polyvalent de Raphaël.''')
end = engine.find('''    /// Génère une base SwiftUI locale''', start)
if start == -1 or end == -1:
    raise SystemExit('generateWebUI template block not found')
engine = engine[:start] + '''    // La génération Web par templates a été supprimée. Raphaël ne fabrique plus
    // de dashboard, boutique ou landing page prédéfinie lorsqu'un vrai modèle de
    // code n'est pas disponible.

''' + engine[end:]

# Remove the WebsiteBrief procedural HTML assembler completely.
start = engine.find('''    /// Construit un document web à partir de toutes les valeurs du brief.''')
end = engine.find('''    // Les anciens templates WebsiteBrief ont été supprimés.''', start)
if start == -1 or end == -1:
    raise SystemExit('generateWebsiteFromBrief procedural block not found')
engine = engine[:start] + '''    // Aucun HTML de site n'est assemblé ici à partir de blocs codés en dur.
    // Le brief est envoyé au pipeline de génération de code réel plus bas.

''' + engine[end:]

# Add a typed error so UI and voice can explain the real failure without lying.
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
addition = marker + '''
public enum SarahRealWebsiteGenerationError: LocalizedError {
    case runtimeNotConfigured
    case modelGenerationFailed
    case invalidRender(String)

    public var errorDescription: String? {
        switch self {
        case .runtimeNotConfigured:
            return "Aucun moteur de code génératif réel n'est configuré. Ouvre Réglages > Sarah Engine et connecte un endpoint OpenAI-compatible. Aucun template de secours ne sera utilisé."
        case .modelGenerationFailed:
            return "Le moteur de code n'a pas renvoyé un document HTML complet. Aucun site factice n'a été créé à la place."
        case .invalidRender(let details):
            return "Le site généré n'a pas passé le contrôle WebKit : \\(details). Aucun fallback prédéfini n'a été injecté."
        }
    }
}
'''
engine = replace_once(engine, marker, addition, 'real generation error enum')

# Reset removes the persisted project and the generated index, avoiding stale UI.
engine = replace_once(
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
    'reset project cleanup'
)

# Remove deterministic local refinement/template fallback code.
start = engine.find('''    private func appleStyleRefinement(_ html: String) -> String {''')
end = engine.find('''    private func architectSystemPrompt() -> String {''', start)
if start == -1 or end == -1:
    raise SystemExit('local template/refinement fallback block not found')
engine = engine[:start] + engine[end:]

# Strengthen architect and implementer instructions. Styles are references, not copied assets.
engine = replace_once(
    engine,
'''    private func architectSystemPrompt() -> String {
        """
        Tu es l'architecte web de Sarah IA. Comprends précisément la demande en langage naturel, conserve les contraintes du projet déjà créé, repère les erreurs et prépare un plan exécutable pour un second modèle. Réponds uniquement avec un plan concis et structuré, sans HTML complet.
        """
    }
''',
'''    private func architectSystemPrompt() -> String {
        """
        Tu es Raphaël Architecte, un véritable agent de conception web. Analyse chaque brief comme un nouveau projet : objectif, public, contenu, hiérarchie, navigation, fonctions et direction artistique. Si un projet existant est fourni, conserve seulement ce qui reste pertinent et applique précisément la nouvelle demande. Une référence comme Apple, Google, Microsoft, Amazon ou Tesla désigne uniquement un langage visuel général : ne copie ni page, ni logo, ni texte, ni asset propriétaire. Prépare un plan spécifique au projet, jamais un template générique. Réponds uniquement avec un plan de réalisation concis et structuré.
        """
    }
''',
    'architect prompt'
)
engine = replace_once(
    engine,
'''    private func implementerSystemPrompt() -> String {
        """
        Tu es le Code Worker de Sarah IA. Retourne uniquement un document HTML autonome complet avec CSS et JavaScript intégrés. Respecte le plan, préserve les fonctions déjà valides du projet existant, corrige les bugs signalés, rends le site responsive et accessible, et n'ajoute aucune fonctionnalité factice présentée comme réelle.
        """
    }
''',
'''    private func implementerSystemPrompt() -> String {
        """
        Tu es Raphaël Code Worker. Génère réellement le site demandé, pas une maquette générique. Retourne UNIQUEMENT un document HTML5 autonome complet avec tout le CSS et le JavaScript intégrés. Chaque texte, section, composant, disposition et interaction doit découler du brief et du plan. Interdiction d'utiliser un dashboard de secours, des cartes « Produit 01 », du lorem ipsum, des blocs préfabriqués, des URLs d'images factices, des logos de marques, un CDN ou des assets propriétaires. Une direction « style Apple/Google/Microsoft/Amazon/Tesla » est une inspiration de principes visuels, jamais une copie. Le document doit être responsive iPhone/tablette/ordinateur, accessible et utilisable hors ligne. Les interactions demandées doivent fonctionner réellement côté navigateur avec JavaScript local.
        """
    }
''',
    'implementer prompt'
)

# remoteAgenticBuild must not persist an untested model response.
old = '''                let revision = (existing?.revision ?? 0) + 1
                let root = existing?.rootRequest ?? prompt
                let project = SarahPersistentWebProject(rootRequest: root, latestInstruction: prompt, html: html, revision: revision, updatedAt: Date())
                self.persistAgenticProject(project)
                completion(SarahAgenticWebBuildResult(
'''
new = '''                let revision = (existing?.revision ?? 0) + 1
                completion(SarahAgenticWebBuildResult(
'''
engine = replace_once(engine, old, new, 'do not persist untested remote output')

# repairRemoteBuild also must not overwrite the project until the repaired page passes.
old = '''            updated.html = repaired
            updated.staticAudit = self.auditWebHTML(repaired)
            if var project = self.loadAgenticProject() {
                project.html = repaired
                project.updatedAt = Date()
                self.persistAgenticProject(project)
            }
            completion(updated)
'''
new = '''            updated.html = repaired
            updated.staticAudit = self.auditWebHTML(repaired)
            completion(updated)
'''
engine = replace_once(engine, old, new, 'do not persist untested repair')

# Strict real-generation entry point. There is deliberately no local/template fallback.
start = engine.find('''    public func buildAndTestWebsite(prompt: String, completion: @escaping (SarahAgenticWebBuildResult) -> Void) {''')
if start == -1:
    raise SystemExit('old buildAndTestWebsite not found')
end = engine.find('\n    }\n}', start)
if end == -1:
    raise SystemExit('buildAndTestWebsite end not found')
end += len('\n    }')
strict_builder = r'''    public func buildAndTestWebsite(
        prompt: String,
        completion: @escaping (Result<SarahAgenticWebBuildResult, Error>) -> Void
    ) {
        guard SarahCodingRuntime.shared.isConfigured else {
            completion(.failure(SarahRealWebsiteGenerationError.runtimeNotConfigured))
            return
        }

        let existingBeforeBuild = loadAgenticProject()

        let persistPassingBuild: (SarahAgenticWebBuildResult) -> Void = { build in
            let rootRequest = existingBeforeBuild?.rootRequest ?? prompt
            let project = SarahPersistentWebProject(
                rootRequest: rootRequest,
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
                    persistPassingBuild(final)
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

                        persistPassingBuild(final)
                    }
                }
            }
        }
    }'''
engine = engine[:start] + strict_builder + engine[end:]
engine_path.write_text(engine)

# -----------------------------------------------------------------------------
# 2) ChatViewModel: send the complete brief to the strict model pipeline.
# -----------------------------------------------------------------------------
vm_path = Path('SarahIA/SarahIA/ViewModels/ChatViewModel.swift')
vm = vm_path.read_text()

# More natural barge-in expressions while Sarah/Raphaël is speaking.
old = '''                    normalized.contains("ce n est pas ca") || normalized.contains("pas celui la") ||
                    normalized.contains("autre chose") || normalized.contains("laisse moi parler") ||
                    normalized.contains("laisse moi") || normalized.contains("pas ca") ||
                    normalized.contains("je veux autre")
'''
new = '''                    normalized.contains("ce n est pas ca") || normalized.contains("pas celui la") ||
                    normalized.contains("autre chose") || normalized.contains("laisse moi parler") ||
                    normalized.contains("laisse moi") || normalized.contains("pas ca") ||
                    normalized.contains("je veux autre") || normalized.contains("je veux plutot") ||
                    normalized.contains("je prefere") || normalized.contains("non plutot") ||
                    normalized.contains("change ca") || normalized.contains("annule")
'''
vm = replace_once(vm, old, new, 'voice barge-in expansion')

# Replace procedural brief completion with strict generative build.
start = vm.find('''    /// Construit le site à partir du brief validé puis vérifie le rendu WebKit.''')
end = vm.find('''    private func appendMessage(_ msg: Message) {''', start)
if start == -1 or end == -1:
    raise SystemExit('ChatViewModel website completion block not found')
real_flow = r'''    /// Envoie le brief complet au véritable pipeline de génération de code.
    /// Si aucun modèle réel n'est connecté, Sarah l'annonce au lieu d'afficher un faux site.
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
        let prompt = realWebsiteGenerationPrompt(for: brief, isRefinement: isRefinement)

        appendMessage(Message(
            content: "💻 **Raphaël · génération réelle en cours**\n\nJe transmets maintenant ton brief au moteur de code. Aucun HTML prédéfini, aucun dashboard et aucun asset de secours ne seront utilisés.",
            isFromUser: false
        ))

        if isContinuousConversationActive {
            speakWebsiteGuide("J'ai tout le brief. Je lance maintenant le vrai moteur de code. Je ne mettrai aucun template de secours.")
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
                        content: "💻 **Raphaël · site réellement généré**\n\n**\(brief.name)** vient d'être écrit par le moteur de code à partir de ton brief puis contrôlé dans WebKit.\n\nContrôle : \(audit)\nRévision : #\(build.revision)\n\n🧩 Ouvrir le Studio",
                        isFromUser: false
                    ))

                    if self.isContinuousConversationActive {
                        self.voiceManager.speak(
                            text: "Le site \(brief.name) a été généré par le moteur de code et vérifié dans WebKit. Tu peux ouvrir le Studio ou me demander une modification.",
                            for: .esther
                        )
                    }

                case .failure(let error):
                    let detail = error.localizedDescription
                    self.appendMessage(Message(
                        content: "💻 **Raphaël · génération réelle indisponible**\n\n\(detail)\n\nJe n'ai créé aucun faux site à la place.",
                        isFromUser: false
                    ))

                    if self.isContinuousConversationActive {
                        self.voiceManager.speak(
                            text: "La vraie génération n'a pas pu démarrer. Je n'ai créé aucun faux site à la place. Ouvre les réglages Sarah Engine pour vérifier le moteur de code.",
                            for: .esther
                        )
                    }
                }
            }
        }
    }

    private func realWebsiteGenerationPrompt(for brief: WebsiteBrief, isRefinement: Bool) -> String {
        let sections = brief.sections.joined(separator: ", ")
        let operation = isRefinement
            ? "MODIFICATION D'UN PROJET EXISTANT : conserve les fonctions valides mais réécris ce qui est nécessaire pour respecter ce nouveau brief."
            : "NOUVEAU PROJET : conçois et écris le site depuis zéro."

        return """
        \(operation)

        BRIEF UTILISATEUR
        Type de site : \(brief.category)
        Nom : \(brief.name)
        Objectif réel : \(brief.purpose)
        Public : \(brief.audience)
        Direction graphique choisie : \(brief.visualStyle)
        Accent : \(brief.accent)
        Sections : \(sections)

        EXIGENCES
        - Le résultat doit être un vrai site unique, pas un template ou un dashboard générique.
        - Génère tout le HTML, tout le CSS et tout le JavaScript nécessaires dans un seul fichier HTML autonome.
        - Le contenu doit être spécifique au nom, à l'objectif, au public et au type de site.
        - Les interactions utiles au type de site doivent réellement fonctionner côté navigateur.
        - N'invente pas de service distant, paiement réel, réservation serveur ou publication en ligne si aucun backend n'existe.
        - N'utilise aucun asset propriétaire, logo de marque, CDN, police distante ou image factice.
        - Le style nommé est seulement une référence de principes visuels. Ne copie aucune page existante.
        - Le site doit être responsive, accessible, rapide et fonctionner hors ligne dans WKWebView.
        """
    }

'''
vm = vm[:start] + real_flow + vm[end:]
vm_path.write_text(vm)

# -----------------------------------------------------------------------------
# 3) Website builder voice: no guessed timer after a free audience answer.
# -----------------------------------------------------------------------------
view_path = Path('SarahIA/SarahIA/Views/ChatScreenView.swift')
view = view_path.read_text()
old = '''                audience = freeAudience
                viewModel.speakWebsiteGuide("D'accord. Je retiens comme public : \\(freeAudience). On passe maintenant à l'ambiance graphique.")
                let captured = step
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                    guard step == captured else { return }
                    withAnimation(.easeInOut(duration: 0.18)) { step = 2 }
                    readCurrentVoiceOptions()
                }
                return
'''
new = '''                audience = freeAudience
                confirmVoiceChoiceAndAdvance(
                    "D'accord. Je retiens comme public : \\(freeAudience). On passe maintenant à l'ambiance graphique.",
                    to: 2
                )
                return
'''
view = replace_once(view, old, new, 'free audience voice completion')
view_path.write_text(view)

# -----------------------------------------------------------------------------
# 4) MultiAgentCoordinator: compile fix + strict Result-based web generation.
# -----------------------------------------------------------------------------
coord_path = Path('SarahIA/SarahIA/Services/MultiAgentCoordinator.swift')
coord = coord_path.read_text()

# Fix the broken multiline Swift string that made build #687 fail.
old = '''                    text: "💻 **Raphaël**

Aucun vrai site n'est prêt à publier. Je ne crée plus de dashboard de secours. Dis « crée-moi un site » pour lancer le brief puis produire le fichier réel.",
'''
new = '''                    text: "💻 **Raphaël**\\n\\nAucun vrai site n'est prêt à publier. Je ne crée plus de dashboard de secours. Dis « crée-moi un site » pour lancer le brief puis produire le fichier réel.",
'''
coord = replace_once(coord, old, new, 'publication compile string')

start = coord.find('''        // 7. Projet web agentique : Raphaël conserve le projet et ses révisions.\n        else {''')
end = coord.find('''        }\n    }\n    \n    // Alias rétrocompatible''', start)
if start == -1 or end == -1:
    raise SystemExit('MultiAgentCoordinator web branch not found')
strict_branch = r'''        // 7. Projet web agentique : aucun moteur de secours ne fabrique du faux HTML.
        else {
            VAICodeEngine.shared.buildAndTestWebsite(prompt: prompt) { result in
                switch result {
                case .failure(let error):
                    completion(AgentResponse(
                        agent: .esther,
                        text: "💻 **Raphaël · génération réelle indisponible**\n\n\(error.localizedDescription)\n\nAucun dashboard ou template de secours n'a été créé.",
                        spokenText: "La génération réelle n'est pas disponible pour l'instant. Je n'ai pas créé de faux site à la place.",
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

                    Le fichier réellement généré est `Documents/VAI_Workspace/index.html`. Tu peux demander une correction dans la même discussion et Raphaël repartira de cette révision.
                    """

                    completion(AgentResponse(
                        agent: .esther,
                        text: responseText,
                        spokenText: "La révision \(build.revision) est réellement générée et vérifiée. Tu peux maintenant me demander une modification.",
                        openStudio: true,
                        generatedCode: build.html
                    ))
                }
            }
        }
'''
coord = coord[:start] + strict_branch + coord[end:]
coord_path.write_text(coord)

print('Strict real web generation v3 applied')
