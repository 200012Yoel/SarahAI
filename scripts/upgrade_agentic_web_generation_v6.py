from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def p(rel: str) -> Path:
    return ROOT / rel


def read(rel: str) -> str:
    return p(rel).read_text(encoding="utf-8")


def write(rel: str, text: str) -> None:
    p(rel).write_text(text, encoding="utf-8")


def replace_regex(text: str, pattern: str, replacement: str, label: str) -> str:
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f"{label}: expected one match, found {count}")
    return updated


# -----------------------------------------------------------------------------
# 1) VAICodeEngine: stronger audits, richer generation, quality review, 2 repairs.
# -----------------------------------------------------------------------------
rel = "SarahIA/SarahIA/Services/VAICodeEngine.swift"
s = read(rel)

new_audit = r'''    public func auditWebHTML(_ html: String) -> SarahWebAuditReport {
        let lower = html.lowercased()
        var errors: [String] = []
        var warnings: [String] = []
        var passed: [String] = []

        func hasRegex(_ pattern: String) -> Bool {
            (try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]))?
                .firstMatch(in: html, range: NSRange(html.startIndex..., in: html)) != nil
        }

        if lower.contains("<!doctype html") { passed.append("DOCTYPE") } else { errors.append("DOCTYPE manquant") }
        if lower.contains("name=\"viewport\"") || lower.contains("name='viewport'") { passed.append("Viewport mobile") } else { errors.append("Viewport mobile manquant") }
        if lower.contains("<html") && lower.contains("</html>") { passed.append("Document HTML fermé") } else { errors.append("Balises HTML incomplètes") }
        if lower.contains("<body") && lower.contains("</body>") { passed.append("Body présent") } else { errors.append("Body incomplet") }
        if hasRegex("<html[^>]*\\slang\\s*=") { passed.append("Langue du document") } else { warnings.append("Attribut lang manquant sur <html>") }
        if lower.contains("charset=") { passed.append("UTF-8 déclaré") } else { warnings.append("Meta charset manquante") }
        if hasRegex("<title>\\s*[^<]{2,}\\s*</title>") { passed.append("Titre de page") } else { errors.append("Titre de page vide ou manquant") }
        if lower.contains("name=\"description\"") || lower.contains("name='description'") { passed.append("Meta description") } else { warnings.append("Meta description manquante") }
        if lower.contains("<main") { passed.append("Landmark main") } else { warnings.append("Balise <main> manquante") }
        if hasRegex("<h1(?:\\s|>)[\\s\\S]*?</h1>") { passed.append("Titre H1") } else { errors.append("H1 manquant") }
        if lower.contains("@media") || lower.contains("clamp(") || lower.contains("min(") || lower.contains("max(") { passed.append("Responsive CSS") } else { warnings.append("Peu de règles responsive détectées") }

        let forbiddenPlaceholders = ["lorem ipsum", "produit 01", "offre 01", "example.com", "placeholder.com", "à compléter", "todo:"]
        let foundPlaceholders = forbiddenPlaceholders.filter { lower.contains($0) }
        if foundPlaceholders.isEmpty { passed.append("Contenu non factice") } else { errors.append("Contenu factice détecté : " + foundPlaceholders.joined(separator: ", ")) }

        let remoteAssetPatterns = [
            "(?:src|poster)\\s*=\\s*[\\\"']https?://",
            "<link[^>]+href\\s*=\\s*[\\\"']https?://",
            "url\\(\\s*[\\\"']?https?://"
        ]
        if remoteAssetPatterns.contains(where: hasRegex) {
            errors.append("Ressource distante détectée : le site doit rester autonome et hors ligne")
        } else {
            passed.append("Assets autonomes")
        }

        if lower.contains("document.write(") { warnings.append("document.write() détecté") }
        if lower.contains("javascript:void(0)") { warnings.append("Lien javascript:void(0) détecté") }
        if html.count > 900_000 { warnings.append("Document très volumineux") }
        if html.count < 2_000 { warnings.append("Document très court pour un site complet") }

        return SarahWebAuditReport(errors: errors, warnings: warnings, passedChecks: passed)
    }

'''
s = replace_regex(
    s,
    r"    public func auditWebHTML\(_ html: String\) -> SarahWebAuditReport \{.*?\n    \}\n\n    private func extractHTMLDocument",
    new_audit + "    private func extractHTMLDocument",
    "web static audit",
)

new_stabilize = r'''    private func stabilizeHTML(_ html: String) -> String {
        var result = html.trimmingCharacters(in: .whitespacesAndNewlines)
        if !result.lowercased().contains("<!doctype html") {
            result = "<!doctype html>\n" + result
        }
        if let htmlRange = result.range(of: "<html", options: .caseInsensitive),
           let close = result[htmlRange.lowerBound...].firstIndex(of: ">") {
            let opening = String(result[htmlRange.lowerBound...close])
            if !opening.lowercased().contains(" lang=") {
                result.replaceSubrange(htmlRange.lowerBound...close, with: opening.dropLast() + " lang=\"fr\">")
            }
        }
        if !result.lowercased().contains("charset=") {
            if let range = result.range(of: "<head>", options: .caseInsensitive) {
                result.insert(contentsOf: "\n<meta charset=\"utf-8\">", at: range.upperBound)
            }
        }
        if !result.lowercased().contains("name=\"viewport\"") && !result.lowercased().contains("name='viewport'") {
            let viewport = "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1, viewport-fit=cover\">"
            if let range = result.range(of: "<head>", options: .caseInsensitive) {
                result.insert(contentsOf: "\n" + viewport, at: range.upperBound)
            }
        }
        let safetyCSS = """
        <style id="sarah-agentic-safety">
        *,*::before,*::after{box-sizing:border-box}
        html,body{max-width:100%;overflow-x:hidden}
        img,video,canvas,svg,iframe{max-width:100%;height:auto}
        button,input,select,textarea{font:inherit}
        button,a,input,select,textarea{touch-action:manipulation}
        :focus-visible{outline:3px solid currentColor;outline-offset:3px}
        @media (prefers-reduced-motion:reduce){*,*::before,*::after{scroll-behavior:auto!important;animation-duration:.001ms!important;animation-iteration-count:1!important;transition-duration:.001ms!important}}
        </style>
        """
        if !result.contains("sarah-agentic-safety") {
            result = result.replacingOccurrences(of: "</head>", with: safetyCSS + "\n</head>", options: .caseInsensitive)
        }
        return result
    }

'''
s = replace_regex(
    s,
    r"    private func stabilizeHTML\(_ html: String\) -> String \{.*?\n    \}\n\n    private func architectSystemPrompt",
    new_stabilize + "    private func architectSystemPrompt",
    "HTML stabilization",
)

new_prompts = r'''    private func architectSystemPrompt() -> String {
        """
        Tu es Raphaël Architecte, senior product designer + architecte front-end. Analyse réellement chaque demande avant le code. Produis un plan spécifique qui décrit : proposition de valeur, public, architecture de l'information, sections, hiérarchie de contenu, navigation, composants, états vides/erreurs, interactions, responsive mobile/tablette/desktop, accessibilité, contenu crédible et direction artistique. Pour un e-commerce, une réservation ou un formulaire, distingue clairement la simulation locale d'un vrai backend. Un nom de marque comme Apple, Google, Microsoft, Amazon ou Tesla indique seulement des principes visuels généraux : ne copie aucune page, aucun logo, aucun texte ni asset propriétaire. Si un projet existant est fourni, indique précisément ce qui doit être conservé et ce qui doit évoluer. Pas de template générique. Réponds uniquement avec un plan de réalisation structuré et exploitable par un développeur.
        """
    }

    private func implementerSystemPrompt() -> String {
        """
        Tu es Raphaël Code Worker, développeur front-end senior. Écris réellement le site demandé et retourne UNIQUEMENT un document HTML5 autonome complet avec CSS et JavaScript intégrés.

        EXIGENCES NON NÉGOCIABLES
        - Le contenu, la structure, les composants et les interactions doivent être spécifiques au brief et au plan, jamais un template recyclé.
        - Mobile-first, parfaitement utilisable à 320/390 px, tablette et ordinateur, sans débordement horizontal.
        - HTML sémantique : lang, charset, viewport, title, meta description, header/nav/main/section/footer quand pertinents, un H1 clair puis une hiérarchie de titres logique.
        - Accessibilité : contrastes lisibles, focus clavier visible, aria-label quand nécessaire, alt pertinents, champs associés à des labels, boutons nommés et zones tactiles confortables.
        - Toutes les interactions visibles doivent fonctionner en JavaScript local : navigation, menus, filtres, accordéons, modales, formulaires, recherche, panier/démo locale ou autres fonctions demandées.
        - Les formulaires doivent valider localement et afficher un retour succès/erreur crédible. Ne prétends jamais envoyer des données à un serveur inexistant.
        - Si le site a un panier, favoris, préférences ou progression, utilise localStorage si cela apporte une vraie valeur à la démo.
        - Aucun lorem ipsum, Produit 01, Offre 01, TODO, faux lien, bouton mort ou texte générique. Rédige de vrais textes adaptés au public et au secteur.
        - Aucun CDN, police distante, script distant, image distante, logo de marque ou asset propriétaire. Utilise CSS, dégradés, formes, emoji mesurés ou SVG inline original si un visuel est nécessaire.
        - Les références de style sont des principes visuels, jamais des copies de marques.
        - Respecte prefers-reduced-motion et évite les animations envahissantes.
        - Ne fabrique pas de paiement, compte, réservation serveur, publication, avis réels ou stock distant. Toute fonction sans backend doit être clairement locale/démonstrative.
        - Le document doit pouvoir être sauvegardé tel quel sous index.html et fonctionner hors ligne dans WKWebView.

        Avant de répondre, vérifie mentalement chaque bouton, chaque lien, les formulaires et le comportement mobile. N'ajoute aucun commentaire hors du HTML.
        """
    }

    private func qualitySystemPrompt() -> String {
        """
        Tu es Raphaël Quality Reviewer. On te donne un HTML déjà généré. Retourne UNIQUEMENT le document HTML complet amélioré. Ne change pas l'intention ni l'identité du projet. Renforce la qualité éditoriale, la cohérence visuelle, la hiérarchie, l'accessibilité, le responsive et les interactions. Supprime tout placeholder, bouton mort, lien factice, asset distant, duplication évidente ou comportement qui prétend utiliser un backend inexistant. Conserve les fonctions valides. Le fichier final doit rester autonome, hors ligne, avec CSS et JavaScript intégrés.
        """
    }

    private func repairSystemPrompt() -> String {
        """
        Tu es le relecteur final du Code Worker. Retourne uniquement le HTML complet corrigé. Corrige toutes les erreurs du rapport : WebKit, JavaScript, ressources cassées, débordement horizontal, IDs dupliqués, liens internes invalides, boutons sans texte, champs sans libellé et balises incomplètes. Préserve l'identité visuelle, le contenu spécifique et toutes les fonctions déjà valides. Aucun fallback générique et aucune ressource distante.
        """
    }

'''
s = replace_regex(
    s,
    r"    private func architectSystemPrompt\(\) -> String \{.*?\n    \}\n\n    private func remoteAgenticBuild",
    new_prompts + "    private func remoteAgenticBuild",
    "agentic prompts",
)

# Add quality review helpers before repairLocalBuild.
quality_helpers = r'''    private func qualityReviewLocalBuild(
        _ build: SarahAgenticWebBuildResult,
        originalPrompt: String,
        completion: @escaping (SarahAgenticWebBuildResult) -> Void
    ) {
        let reviewPrompt = qualitySystemPrompt()
            + "\n\nDEMANDE ORIGINALE :\n" + originalPrompt
            + "\n\nHTML À RELIRE :\n" + build.html

        AIService.shared.generateLocalCodeDocument(prompt: reviewPrompt) { result in
            guard case .success(let raw) = result,
                  var html = self.extractHTMLDocument(raw) else {
                completion(build)
                return
            }
            html = self.stabilizeHTML(html)
            var improved = build
            improved.html = html
            improved.staticAudit = self.auditWebHTML(html)
            completion(improved)
        }
    }

    private func qualityReviewRemoteBuild(
        _ build: SarahAgenticWebBuildResult,
        originalPrompt: String,
        completion: @escaping (SarahAgenticWebBuildResult) -> Void
    ) {
        guard SarahCodingRuntime.shared.isConfigured else {
            completion(build)
            return
        }
        SarahCodingRuntime.shared.generate(
            model: SarahCodingModelCatalog.implementer,
            system: qualitySystemPrompt(),
            user: "DEMANDE ORIGINALE :\n\(originalPrompt)\n\nHTML À RELIRE :\n\(build.html)"
        ) { result in
            guard case .success(let raw) = result,
                  var html = self.extractHTMLDocument(raw) else {
                completion(build)
                return
            }
            html = self.stabilizeHTML(html)
            var improved = build
            improved.html = html
            improved.staticAudit = self.auditWebHTML(html)
            completion(improved)
        }
    }

'''
if "private func qualityReviewLocalBuild(" not in s:
    marker = "    private func repairLocalBuild("
    if marker not in s:
        raise SystemExit("quality helper insertion point missing")
    s = s.replace(marker, quality_helpers + marker, 1)

# Remote candidate always gets one quality-review pass before browser audit.
old_remote_completion = r'''                let revision = (existing?.revision ?? 0) + 1
                completion(SarahAgenticWebBuildResult(
                    html: html,
                    revision: revision,
                    wasRefinement: existing != nil,
                    architectModel: SarahCodingModelCatalog.architect,
                    implementerModel: SarahCodingModelCatalog.implementer,
                    staticAudit: self.auditWebHTML(html),
                    browserAudit: nil,
                    usedRemoteModels: true
                ))
'''
new_remote_completion = r'''                let revision = (existing?.revision ?? 0) + 1
                let candidate = SarahAgenticWebBuildResult(
                    html: html,
                    revision: revision,
                    wasRefinement: existing != nil,
                    architectModel: SarahCodingModelCatalog.architect,
                    implementerModel: SarahCodingModelCatalog.implementer,
                    staticAudit: self.auditWebHTML(html),
                    browserAudit: nil,
                    usedRemoteModels: true
                )
                self.qualityReviewRemoteBuild(candidate, originalPrompt: prompt, completion: completion)
'''
if old_remote_completion in s:
    s = s.replace(old_remote_completion, new_remote_completion, 1)
elif "qualityReviewRemoteBuild(candidate" not in s:
    raise SystemExit("remote quality pass target missing")

old_local_completion = r'''            completion(SarahAgenticWebBuildResult(
                html: html,
                revision: (existing?.revision ?? 0) + 1,
                wasRefinement: existing != nil,
                architectModel: SarahCodingModelCatalog.architect,
                implementerModel: SarahCodingModelCatalog.implementer,
                staticAudit: self.auditWebHTML(html),
                browserAudit: nil,
                usedRemoteModels: false
            ))
'''
new_local_completion = r'''            let candidate = SarahAgenticWebBuildResult(
                html: html,
                revision: (existing?.revision ?? 0) + 1,
                wasRefinement: existing != nil,
                architectModel: SarahCodingModelCatalog.architect,
                implementerModel: SarahCodingModelCatalog.implementer,
                staticAudit: self.auditWebHTML(html),
                browserAudit: nil,
                usedRemoteModels: false
            )
            self.qualityReviewLocalBuild(candidate, originalPrompt: prompt, completion: completion)
'''
if old_local_completion in s:
    s = s.replace(old_local_completion, new_local_completion, 1)
elif "qualityReviewLocalBuild(candidate" not in s:
    raise SystemExit("local quality pass target missing")

# Replace browser smoke test with a stricter DOM quality gate.
new_browser = r'''    public func runBrowserSmokeTest(html: String, completion: @escaping (SarahBrowserSmokeReport) -> Void) {
        DispatchQueue.main.async {
            let config = WKWebViewConfiguration()
            let probe = """
            window.__sarahErrors = [];
            window.addEventListener('error', function(e) {
              window.__sarahErrors.push(String(e.message || 'JavaScript error'));
            });
            window.addEventListener('unhandledrejection', function(e) {
              window.__sarahErrors.push(String(e.reason || 'Unhandled promise rejection'));
            });
            """
            config.userContentController.addUserScript(WKUserScript(source: probe, injectionTime: .atDocumentStart, forMainFrameOnly: false))
            let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: config)
            webView.loadHTMLString(html, baseURL: nil)

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
                let script = """
                (() => {
                  const ids = Array.from(document.querySelectorAll('[id]')).map(e => e.id).filter(Boolean);
                  const duplicateIds = ids.filter((id, index) => ids.indexOf(id) !== index).length;
                  const emptyButtons = Array.from(document.querySelectorAll('button')).filter(b => !(b.innerText || b.getAttribute('aria-label') || b.getAttribute('title') || '').trim()).length;
                  const controls = Array.from(document.querySelectorAll('input:not([type=hidden]), select, textarea'));
                  const unlabeledInputs = controls.filter(el => {
                    const id = el.id;
                    return !(el.getAttribute('aria-label') || el.getAttribute('aria-labelledby') || (id && document.querySelector(`label[for="${CSS.escape(id)}"]`)) || el.closest('label'));
                  }).length;
                  const localLinks = Array.from(document.querySelectorAll('a[href^="#"]')).filter(a => a.getAttribute('href') && a.getAttribute('href') !== '#');
                  const brokenLocalLinks = localLinks.filter(a => !document.querySelector(a.getAttribute('href'))).length;
                  const emptyLinks = Array.from(document.querySelectorAll('a')).filter(a => !(a.innerText || a.getAttribute('aria-label') || a.getAttribute('title') || '').trim()).length;
                  return JSON.stringify({
                    title: document.title || '',
                    buttons: document.querySelectorAll('button').length,
                    links: document.querySelectorAll('a').length,
                    body: !!document.body,
                    h1: document.querySelectorAll('h1').length,
                    main: document.querySelectorAll('main').length,
                    ready: document.readyState,
                    overflow: document.documentElement.scrollWidth > (window.innerWidth + 2),
                    brokenImages: Array.from(document.images).filter(i => i.complete && i.naturalWidth === 0).length,
                    duplicateIds,
                    emptyButtons,
                    unlabeledInputs,
                    brokenLocalLinks,
                    emptyLinks,
                    errors: window.__sarahErrors || []
                  });
                })()
                """
                webView.evaluateJavaScript(script) { value, error in
                    if let error = error {
                        completion(SarahBrowserSmokeReport(passed: false, title: "", buttonCount: 0, linkCount: 0, brokenImages: 0, horizontalOverflow: false, javascriptErrors: [error.localizedDescription], details: error.localizedDescription))
                        return
                    }
                    guard let jsonString = value as? String,
                          let data = jsonString.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        completion(SarahBrowserSmokeReport(passed: false, title: "", buttonCount: 0, linkCount: 0, brokenImages: 0, horizontalOverflow: false, javascriptErrors: [], details: "Le DOM n'a pas répondu au test."))
                        return
                    }

                    let title = json["title"] as? String ?? ""
                    let buttons = json["buttons"] as? Int ?? 0
                    let links = json["links"] as? Int ?? 0
                    let body = json["body"] as? Bool ?? false
                    let h1 = json["h1"] as? Int ?? 0
                    let main = json["main"] as? Int ?? 0
                    let ready = json["ready"] as? String ?? ""
                    let overflow = json["overflow"] as? Bool ?? false
                    let brokenImages = json["brokenImages"] as? Int ?? 0
                    let duplicateIds = json["duplicateIds"] as? Int ?? 0
                    let emptyButtons = json["emptyButtons"] as? Int ?? 0
                    let unlabeledInputs = json["unlabeledInputs"] as? Int ?? 0
                    let brokenLocalLinks = json["brokenLocalLinks"] as? Int ?? 0
                    let emptyLinks = json["emptyLinks"] as? Int ?? 0
                    let jsErrors = json["errors"] as? [String] ?? []

                    let passed = body
                        && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        && h1 == 1
                        && main >= 1
                        && (ready == "complete" || ready == "interactive")
                        && !overflow
                        && brokenImages == 0
                        && duplicateIds == 0
                        && emptyButtons == 0
                        && brokenLocalLinks == 0
                        && emptyLinks == 0
                        && jsErrors.isEmpty

                    var details: [String] = []
                    details.append("DOM: \(ready.isEmpty ? "inconnu" : ready)")
                    details.append("\(buttons) bouton(s) · \(links) lien(s)")
                    if overflow { details.append("débordement horizontal") }
                    if brokenImages > 0 { details.append("\(brokenImages) image(s) cassée(s)") }
                    if duplicateIds > 0 { details.append("\(duplicateIds) ID dupliqué(s)") }
                    if emptyButtons > 0 { details.append("\(emptyButtons) bouton(s) sans nom") }
                    if unlabeledInputs > 0 { details.append("\(unlabeledInputs) champ(s) sans label") }
                    if brokenLocalLinks > 0 { details.append("\(brokenLocalLinks) ancre(s) interne(s) cassée(s)") }
                    if emptyLinks > 0 { details.append("\(emptyLinks) lien(s) sans nom") }
                    if !jsErrors.isEmpty { details.append("\(jsErrors.count) erreur(s) JavaScript") }
                    if passed { details.append("quality gate mobile validé") }

                    completion(SarahBrowserSmokeReport(
                        passed: passed,
                        title: title,
                        buttonCount: buttons,
                        linkCount: links,
                        brokenImages: brokenImages,
                        horizontalOverflow: overflow,
                        javascriptErrors: jsErrors,
                        details: details.joined(separator: " · ")
                    ))
                }
            }
        }
    }

'''
s = replace_regex(
    s,
    r"    public func runBrowserSmokeTest\(html: String, completion: @escaping \(SarahBrowserSmokeReport\) -> Void\) \{.*?\n    \}\n\n    private func repairRemoteBuild",
    new_browser + "    private func repairRemoteBuild",
    "browser quality gate",
)

# Keep revision snapshots as well as index.html.
old_persist = r'''    private func persistAgenticProject(_ project: SarahPersistentWebProject) {
        if let data = try? JSONEncoder().encode(project) {
            try? data.write(to: agenticProjectURL, options: .atomic)
        }
        _ = saveFile(filename: "index.html", content: project.html)
    }
'''
new_persist = r'''    private func persistAgenticProject(_ project: SarahPersistentWebProject) {
        if let data = try? JSONEncoder().encode(project) {
            try? data.write(to: agenticProjectURL, options: .atomic)
        }
        _ = saveFile(filename: "index.html", content: project.html)

        let revisions = workspaceDirectory.appendingPathComponent("revisions", isDirectory: true)
        try? FileManager.default.createDirectory(at: revisions, withIntermediateDirectories: true)
        let snapshot = revisions.appendingPathComponent("index-r\(project.revision).html")
        try? project.html.write(to: snapshot, atomically: true, encoding: .utf8)
    }
'''
if old_persist in s:
    s = s.replace(old_persist, new_persist, 1)
elif "index-r\\(project.revision).html" not in s:
    raise SystemExit("revision persistence target missing")

# Two automatic repair passes before failure.
new_build = r'''    public func buildAndTestWebsite(
        prompt: String,
        completion: @escaping (Result<SarahAgenticWebBuildResult, Error>) -> Void
    ) {
        let previousProject = loadAgenticProject()
        let usesRemoteRuntime = SarahCodingRuntime.shared.isConfigured

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

        var validateCandidate: ((SarahAgenticWebBuildResult, Int) -> Void)!
        validateCandidate = { candidate, repairsRemaining in
            let stabilized = self.stabilizeHTML(candidate.html)
            var checked = candidate
            checked.html = stabilized
            checked.staticAudit = self.auditWebHTML(stabilized)

            self.runBrowserSmokeTest(html: stabilized) { report in
                checked.browserAudit = report
                if report.passed && checked.staticAudit.isPassing {
                    persistPassing(checked)
                    return
                }

                guard repairsRemaining > 0 else {
                    let staticProblems = checked.staticAudit.errors.joined(separator: " · ")
                    let details = [report.details, staticProblems].filter { !$0.isEmpty }.joined(separator: " · ")
                    completion(.failure(SarahRealWebsiteGenerationError.invalidRender(details)))
                    return
                }

                let continueAfterRepair: (SarahAgenticWebBuildResult) -> Void = { repaired in
                    validateCandidate(repaired, repairsRemaining - 1)
                }

                if usesRemoteRuntime {
                    self.repairRemoteBuild(checked, report: report, completion: continueAfterRepair)
                } else {
                    self.repairLocalBuild(checked, report: report, completion: continueAfterRepair)
                }
            }
        }

        let inspectCandidate: (SarahAgenticWebBuildResult?) -> Void = { candidate in
            guard let candidate else {
                completion(.failure(SarahRealWebsiteGenerationError.modelGenerationFailed))
                return
            }
            validateCandidate(candidate, 2)
        }

        if usesRemoteRuntime {
            remoteAgenticBuild(prompt: prompt, completion: inspectCandidate)
        } else {
            localAgenticBuild(prompt: prompt, completion: inspectCandidate)
        }
    }
'''
s = replace_regex(
    s,
    r"    public func buildAndTestWebsite\(\n        prompt: String,\n        completion: @escaping \(Result<SarahAgenticWebBuildResult, Error>\) -> Void\n    \) \{.*?\n    \}\n\n\}",
    new_build + "\n}\n",
    "build and test pipeline",
)
write(rel, s)


# -----------------------------------------------------------------------------
# 2) ChatViewModel: richer brief contract + more informative success state.
# -----------------------------------------------------------------------------
rel = "SarahIA/SarahIA/ViewModels/ChatViewModel.swift"
s = read(rel)

new_prompt = r'''    private func realWebsitePrompt(for brief: WebsiteBrief, isRefinement: Bool) -> String {
        let sectionList = brief.sections.joined(separator: ", ")
        let operation = isRefinement
            ? "MODIFICATION : repars du projet existant, conserve les fonctions valides et applique ce nouveau brief sans régression."
            : "NOUVEAU PROJET : conçois le produit, son contenu et son interface depuis zéro."

        let domainRequirements: String
        switch brief.category {
        case "E-commerce":
            domainRequirements = "Catalogue crédible, filtres/recherche utiles, fiche produit ou détail, panier local réellement interactif avec localStorage. Aucun faux paiement ni faux stock serveur."
        case "Restaurant":
            domainRequirements = "Menu réellement lisible avec catégories/prix, informations pratiques et réservation locale avec validation. Ne prétends pas confirmer une table sur un serveur."
        case "Voyage":
            domainRequirements = "Destinations/contenus crédibles, recherche ou filtres locaux si pertinents, itinéraires ou cartes éditoriales. Aucune fausse disponibilité temps réel."
        case "Portfolio":
            domainRequirements = "Projets détaillés, navigation vers les réalisations, filtres ou modales si utiles, présentation personnelle crédible et contact local."
        case "Entreprise":
            domainRequirements = "Proposition de valeur claire, services, preuves/confiance honnêtes, équipe ou méthode si pertinent, contact avec validation locale."
        case "Événement":
            domainRequirements = "Programme, horaires, intervenants ou lieux, inscription locale avec états clairs. Aucun faux billet ou paiement serveur."
        case "SaaS / App":
            domainRequirements = "Hero produit, fonctionnalités concrètes, démonstration interactive locale si possible, tarifs si demandés, FAQ et CTA cohérents. Aucun faux compte cloud."
        case "Blog / média":
            domainRequirements = "Accueil éditorial, cartes d'articles crédibles, catégories/tags, recherche locale et lecture structurée. Aucun faux flux d'actualité temps réel."
        case "Association":
            domainRequirements = "Mission, actions, événements/projets, équipe ou bénévolat, contact/adhésion locale. Ne simule pas de don ou paiement réel."
        default:
            domainRequirements = "Choisis les interactions et composants qui servent réellement l'objectif, sans ajouter de fonctions décoratives inutiles."
        }

        return """
        \(operation)

        BRIEF PRODUIT
        Type : \(brief.category)
        Nom : \(brief.name)
        Objectif : \(brief.purpose)
        Public : \(brief.audience)
        Direction graphique : \(brief.visualStyle)
        Accent : \(brief.accent)
        Sections demandées : \(sectionList)
        Exigences métier : \(domainRequirements)

        CONTRAT DE LIVRAISON
        - Produis un vrai site spécifique au brief, avec une identité visuelle cohérente et du contenu rédigé pour ce public.
        - Retourne un seul index.html autonome avec HTML, CSS et JavaScript intégrés.
        - Mobile-first : 320/390 px, tablette et desktop. Aucun débordement horizontal.
        - Structure sémantique, un seul H1, navigation claire, sections demandées réellement remplies et footer utile.
        - Tous les boutons, menus, filtres, formulaires, accordéons, onglets, modales et liens visibles doivent avoir un comportement réel.
        - Les formulaires valident localement et montrent les états erreur/succès. N'invente jamais un backend.
        - Utilise localStorage pour les fonctions locales persistantes lorsque c'est pertinent.
        - Aucun lorem ipsum, Produit 01, Offre 01, TODO, bouton mort, faux lien ou contenu placeholder.
        - Aucun CDN, police distante, script distant, image distante, logo de marque, asset propriétaire ou URL d'image factice.
        - Les styles nommés sont des inspirations de principes graphiques, jamais des copies de marques.
        - Accessibilité réelle : contrastes, focus visible, labels de formulaires, alt, aria quand nécessaire, reduced motion.
        - Le rendu doit fonctionner hors ligne dans WKWebView.
        - Avant livraison, relis le contenu, vérifie toutes les interactions et corrige les incohérences.
        """
    }
'''
s = replace_regex(
    s,
    r"    private func realWebsitePrompt\(for brief: WebsiteBrief, isRefinement: Bool\) -> String \{.*?\n    \}\n\n    private func appendMessage",
    new_prompt + "\n    private func appendMessage",
    "website brief prompt",
)

# Improve success/failure report without changing control flow.
old_success = '''                    let audit = build.browserAudit?.details ?? "WebKit validé"
                    self.appendMessage(Message(
                        content: "💻 **Raphaël · site réellement généré**\\n\\n**\\(brief.name)** a été écrit par le moteur de code à partir de ton brief, puis contrôlé dans WebKit.\\n\\nContrôle : \\(audit)\\nRévision : #\\(build.revision)\\n\\n🧩 Ouvrir le Studio",
                        isFromUser: false
                    ))
'''
new_success = '''                    let audit = build.browserAudit?.details ?? "WebKit validé"
                    let passedChecks = build.staticAudit.passedChecks.joined(separator: " · ")
                    let warnings = build.staticAudit.warnings.isEmpty
                        ? "aucun avertissement"
                        : build.staticAudit.warnings.joined(separator: " · ")
                    let runtime = build.usedRemoteModels ? "moteur de code configuré" : "moteur IA local"
                    self.appendMessage(Message(
                        content: "💻 **Raphaël · site généré et contrôlé**\\n\\n**\\(brief.name)** est prêt. Pipeline : architecture → code → relecture qualité → WebKit → réparations automatiques si nécessaire.\\n\\nMoteur : \\(runtime)\\nContrôle navigateur : \\(audit)\\nContrôles statiques : \\(passedChecks)\\nAvertissements : \\(warnings)\\nRévision : #\\(build.revision)\\n\\n🧩 Ouvrir le Studio",
                        isFromUser: false
                    ))
'''
if old_success in s:
    s = s.replace(old_success, new_success, 1)
elif "Pipeline : architecture → code → relecture qualité" not in s:
    raise SystemExit("success message target missing")

s = s.replace(
    "💻 **Raphaël · génération réelle indisponible**",
    "💻 **Raphaël · contrôle qualité non validé**",
    1,
)
s = s.replace(
    "La vraie génération n'a pas pu démarrer. Je n'ai créé aucun faux site. Vérifie le moteur de code dans les réglages Sarah Engine.",
    "La génération ou son contrôle qualité n'a pas abouti. Je n'ai pas remplacé le résultat par un faux site. Tu peux réessayer ou préciser le brief.",
    1,
)
write(rel, s)


# -----------------------------------------------------------------------------
# 3) Website builder: broader site types, audiences and sections.
# -----------------------------------------------------------------------------
rel = "SarahIA/SarahIA/Views/ChatScreenView.swift"
s = read(rel)

old_categories = '''    private let categories = [
        WebsiteChoice(title: "E-commerce", icon: "bag.fill", detail: "Vendre des produits"),
        WebsiteChoice(title: "Voyage", icon: "airplane", detail: "Inspirer et réserver"),
        WebsiteChoice(title: "Restaurant", icon: "fork.knife", detail: "Menu et réservation"),
        WebsiteChoice(title: "Portfolio", icon: "person.crop.rectangle", detail: "Présenter son travail"),
        WebsiteChoice(title: "Entreprise", icon: "building.2.fill", detail: "Services et contact"),
        WebsiteChoice(title: "Événement", icon: "calendar", detail: "Informer et inscrire")
    ]
'''
new_categories = '''    private let categories = [
        WebsiteChoice(title: "E-commerce", icon: "bag.fill", detail: "Catalogue, panier et conversion"),
        WebsiteChoice(title: "Voyage", icon: "airplane", detail: "Destinations et exploration"),
        WebsiteChoice(title: "Restaurant", icon: "fork.knife", detail: "Menu, infos et réservation"),
        WebsiteChoice(title: "Portfolio", icon: "person.crop.rectangle", detail: "Projets et présentation"),
        WebsiteChoice(title: "Entreprise", icon: "building.2.fill", detail: "Services et contact"),
        WebsiteChoice(title: "Événement", icon: "calendar", detail: "Programme et inscription"),
        WebsiteChoice(title: "SaaS / App", icon: "app.badge.fill", detail: "Produit, fonctions et tarifs"),
        WebsiteChoice(title: "Blog / média", icon: "newspaper.fill", detail: "Articles, catégories et recherche"),
        WebsiteChoice(title: "Association", icon: "person.3.fill", detail: "Mission, actions et communauté")
    ]
'''
if old_categories in s:
    s = s.replace(old_categories, new_categories, 1)
elif 'WebsiteChoice(title: "SaaS / App"' not in s:
    raise SystemExit("categories target missing")

old_audiences = '''    private let audiences = [
        "Grand public", "Professionnels", "Familles", "Jeunes adultes",
        "Clients locaux", "International"
    ]
'''
new_audiences = '''    private let audiences = [
        "Grand public", "Professionnels", "Familles", "Jeunes adultes",
        "Clients locaux", "International", "Étudiants", "Créateurs", "Communauté / membres"
    ]
'''
if old_audiences in s:
    s = s.replace(old_audiences, new_audiences, 1)

old_sections = '''    private let sectionOptions = [
        "Accueil", "À propos", "Produits / services", "Galerie",
        "Avis clients", "FAQ", "Contact"
    ]
'''
new_sections = '''    private let sectionOptions = [
        "Accueil", "À propos", "Produits / services", "Fonctionnalités",
        "Galerie", "Projets / réalisations", "Tarifs", "Équipe",
        "Avis clients", "Programme / agenda", "Blog / actualités",
        "Réservation / inscription", "Carte / localisation", "FAQ",
        "Newsletter", "Contact"
    ]
'''
if old_sections in s:
    s = s.replace(old_sections, new_sections, 1)
elif '"Newsletter", "Contact"' not in s:
    raise SystemExit("section options target missing")

s = s.replace(
    'case 0: return "Choisis le type de site avec les mêmes cartes que la build 502."',
    'case 0: return "Choisis le type de produit web que Raphaël doit réellement construire."',
    1,
)
s = s.replace(
    'case 2: return "Choisis l’ambiance graphique du parcours original."',
    'case 2: return "Choisis l’ambiance graphique générale qui guidera tout le rendu."',
    1,
)
s = s.replace(
    'default: return "Sélectionne les sections à afficher avant la première maquette locale."',
    'default: return "Sélectionne les sections réellement nécessaires. Raphaël générera leur contenu et leurs interactions."',
    1,
)
write(rel, s)

print("Agentic website generation v6 upgrade applied")
