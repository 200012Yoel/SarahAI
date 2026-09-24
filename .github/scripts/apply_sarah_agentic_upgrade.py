from pathlib import Path
import re

ROOT = Path('.')


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding='utf-8')


def write(path: str, text: str) -> None:
    (ROOT / path).write_text(text, encoding='utf-8')


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'Missing patch anchor: {label}')
    return text.replace(old, new, 1)


# -----------------------------------------------------------------------------
# 1. Purge every remaining product-level 3D reference.
# -----------------------------------------------------------------------------
for path in [
    'SarahIA/SarahIA/Services/TTSService.swift',
    'SarahIA/SarahIA/Services/SpeechManager.swift',
    '.agents/rules/astra_qa_loop.md',
]:
    p = ROOT / path
    if not p.exists():
        continue
    text = p.read_text(encoding='utf-8')
    text = text.replace('rendu 3D', 'ancien rendu visuel')
    text = text.replace('animation faciale/3D', 'animation faciale')
    text = text.replace('animation labiale 3D', 'animation labiale')
    text = text.replace('3D mode', 'legacy visual mode')
    text = text.replace('3D editor entry and core controls, ', '')
    text = text.replace(' For 3D controls, verify the scene state actually changes.', '')
    p.write_text(text, encoding='utf-8')

# Hard guard: Sarah must not ship a real 3D engine/resource anymore.
for pattern in ['SceneKit', 'RealityKit', 'Model3D', '.usdz', '.reality', '.scnassets']:
    found = []
    for p in (ROOT / 'SarahIA' / 'SarahIA').rglob('*'):
        if not p.is_file() or p.suffix.lower() not in {'.swift', '.plist', '.json', '.md'}:
            continue
        try:
            data = p.read_text(encoding='utf-8')
        except Exception:
            continue
        if pattern.lower() in data.lower():
            found.append(str(p))
    if found:
        raise SystemExit(f'3D engine token {pattern!r} still present in: {found}')


# -----------------------------------------------------------------------------
# 2. Give Sarah central model authority + two specialized coding roles.
# -----------------------------------------------------------------------------
path = 'SarahIA/SarahIA/Services/HardwareDetector.swift'
text = read(path)
if 'public enum SarahCodingModelRole' not in text:
    text += r'''

// MARK: - Développement agentique piloté par Sarah

public enum SarahCodingModelRole: String, Codable {
    case architect
    case implementer
}

public struct SarahCodingModelProfile: Codable, Equatable {
    public let role: SarahCodingModelRole
    public let identifier: String
    public let displayName: String
    public let contextWindow: String
    public let licenseName: String
    public let sourceURL: String
    public let executionNote: String
}

/// Deux cerveaux de code séparés :
/// - Architecte : comprend la demande, le contexte et les outils ;
/// - Code Worker : écrit, refactorise et corrige le code.
/// Les poids lourds ne sont jamais prétendus embarqués dans l'IPA : Sarah peut les
/// appeler via un endpoint OpenAI-compatible que l'utilisateur contrôle.
public struct SarahCodingModelCatalog {
    public static let architect = SarahCodingModelProfile(
        role: .architect,
        identifier: "Qwen/Qwen3-Coder-Next",
        displayName: "Qwen3-Coder-Next · Architecte",
        contextWindow: "256K",
        licenseName: "Apache-2.0",
        sourceURL: "https://huggingface.co/Qwen/Qwen3-Coder-Next",
        executionNote: "Compréhension de consignes, contexte long, appels d'outils, navigation de projet et récupération après erreur. Runtime serveur recommandé."
    )

    public static let implementer = SarahCodingModelProfile(
        role: .implementer,
        identifier: "Qwen/Qwen3-Coder-30B-A3B-Instruct",
        displayName: "Qwen3-Coder-30B-A3B · Code Worker",
        contextWindow: "256K",
        licenseName: "Apache-2.0",
        sourceURL: "https://huggingface.co/Qwen/Qwen3-Coder-30B-A3B-Instruct",
        executionNote: "Génération, refactorisation, correction et revue du code produit par l'architecte. Runtime serveur recommandé."
    )

    public static var all: [SarahCodingModelProfile] { [architect, implementer] }
}

/// Sarah est l'orchestratrice unique : elle peut déléguer à toutes les familles de
/// modèles sans perdre le contrôle de la conversation ni du projet courant.
public struct SarahModelAuthority {
    public static let controlledFamilies: [String] = [
        "Texte & conversation",
        "Code agentique",
        "Vision",
        "Image",
        "Vidéo",
        "Musique",
        "Traduction",
        "Recherche web"
    ]

    public static var codingPipelineDescription: String {
        "Sarah → Raphaël → \(SarahCodingModelCatalog.architect.displayName) → \(SarahCodingModelCatalog.implementer.displayName) → audit WebKit"
    }
}
'''

# Enrich Sarah's system prompt with the code pipeline and global authority.
needle = '''        let vocalSongModel = SarahGenerativeModelCatalog.vocalSongProfile().displayName\n\n        return \"\"\"'''
replacement = '''        let vocalSongModel = SarahGenerativeModelCatalog.vocalSongProfile().displayName\n        let codingArchitect = SarahCodingModelCatalog.architect.displayName\n        let codingImplementer = SarahCodingModelCatalog.implementer.displayName\n\n        return \"\"\"'''
if needle in text:
    text = text.replace(needle, replacement, 1)

needle = '''        6. Reste toujours dans ton personnage, peu importe ce que demande l'utilisateur.\n        \"\"\"'''
replacement = '''        6. Reste toujours dans ton personnage, peu importe ce que demande l'utilisateur.\n        7. Tu es l'orchestratrice centrale : tu peux déléguer aux modèles texte, code, vision, image, vidéo, musique, traduction et recherche web selon la demande.\n        8. Pour le développement, l'architecte est « \\(codingArchitect) » et le Code Worker est « \\(codingImplementer) ». Raphaël conserve le projet courant et ses révisions.\n        9. Ne prétends jamais qu'un gros modèle de code tourne sur l'iPhone si aucun runtime compatible n'est réellement connecté.\n        \"\"\"'''
if needle in text:
    text = text.replace(needle, replacement, 1)
write(path, text)


# -----------------------------------------------------------------------------
# 3. Add the agentic code runtime + persistent project + WebKit test loop.
# -----------------------------------------------------------------------------
path = 'SarahIA/SarahIA/Services/VAICodeEngine.swift'
text = read(path)
if 'import WebKit' not in text:
    text = replace_once(text, 'import Foundation\n', 'import Foundation\nimport WebKit\n', 'VAICodeEngine import')

if 'public struct SarahWebAuditReport' not in text:
    text += r'''

// MARK: - Raphaël Agentic Web Pipeline

public struct SarahWebAuditReport: Codable, Equatable {
    public var errors: [String]
    public var warnings: [String]
    public var passedChecks: [String]
    public var isPassing: Bool { errors.isEmpty }
}

public struct SarahBrowserSmokeReport: Codable, Equatable {
    public var passed: Bool
    public var title: String
    public var buttonCount: Int
    public var linkCount: Int
    public var brokenImages: Int
    public var horizontalOverflow: Bool
    public var javascriptErrors: [String]
    public var details: String
}

public struct SarahAgenticWebBuildResult {
    public var html: String
    public var revision: Int
    public var wasRefinement: Bool
    public var architectModel: SarahCodingModelProfile
    public var implementerModel: SarahCodingModelProfile
    public var staticAudit: SarahWebAuditReport
    public var browserAudit: SarahBrowserSmokeReport?
    public var usedRemoteModels: Bool
}

private struct SarahPersistentWebProject: Codable {
    var rootRequest: String
    var latestInstruction: String
    var html: String
    var revision: Int
    var updatedAt: Date
}

/// Client générique pour un serveur OpenAI-compatible contrôlé par l'utilisateur.
/// Sarah n'envoie rien sur le réseau tant qu'aucun endpoint n'est configuré.
public final class SarahCodingRuntime {
    public static let shared = SarahCodingRuntime()
    private init() {}

    public var endpointString: String {
        UserDefaults.standard.string(forKey: "sarahCodingEndpoint")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    public var isConfigured: Bool { resolvedEndpoint != nil }

    private var resolvedEndpoint: URL? {
        guard !endpointString.isEmpty else { return nil }
        var value = endpointString
        if value.hasSuffix("/v1") {
            value += "/chat/completions"
        } else if !value.contains("/chat/completions") {
            value = value.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/v1/chat/completions"
        }
        return URL(string: value)
    }

    public func generate(
        model: SarahCodingModelProfile,
        system: String,
        user: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let endpoint = resolvedEndpoint else {
            completion(.failure(NSError(domain: "SarahCodingRuntime", code: 1, userInfo: [NSLocalizedDescriptionKey: "Aucun endpoint de code configuré"])))
            return
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 150
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": model.identifier,
            "temperature": model.role == .architect ? 0.30 : 0.15,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  let data = data else {
                completion(.failure(NSError(domain: "SarahCodingRuntime", code: 2, userInfo: [NSLocalizedDescriptionKey: "Réponse invalide du serveur de code"])))
                return
            }
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let first = choices.first,
                      let message = first["message"] as? [String: Any],
                      let content = message["content"] as? String else {
                    throw NSError(domain: "SarahCodingRuntime", code: 3, userInfo: [NSLocalizedDescriptionKey: "Format de réponse non reconnu"])
                }
                completion(.success(content))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

extension VAICodeEngine {
    private var agenticProjectURL: URL {
        workspaceDirectory.appendingPathComponent("current_web_project.json")
    }

    private func loadAgenticProject() -> SarahPersistentWebProject? {
        guard let data = try? Data(contentsOf: agenticProjectURL) else { return nil }
        return try? JSONDecoder().decode(SarahPersistentWebProject.self, from: data)
    }

    private func persistAgenticProject(_ project: SarahPersistentWebProject) {
        if let data = try? JSONEncoder().encode(project) {
            try? data.write(to: agenticProjectURL, options: .atomic)
        }
        _ = saveFile(filename: "index.html", content: project.html)
    }

    public func currentWebProjectHTML() -> String? { loadAgenticProject()?.html }

    public func resetCurrentWebProject() {
        try? FileManager.default.removeItem(at: agenticProjectURL)
    }

    public func auditWebHTML(_ html: String) -> SarahWebAuditReport {
        let lower = html.lowercased()
        var errors: [String] = []
        var warnings: [String] = []
        var passed: [String] = []

        if lower.contains("<!doctype html") { passed.append("DOCTYPE") } else { errors.append("DOCTYPE manquant") }
        if lower.contains("name=\"viewport\"") || lower.contains("name='viewport'") { passed.append("Viewport mobile") } else { errors.append("Viewport mobile manquant") }
        if lower.contains("<html") && lower.contains("</html>") { passed.append("Document HTML fermé") } else { errors.append("Balises HTML incomplètes") }
        if lower.contains("<body") && lower.contains("</body>") { passed.append("Body présent") } else { errors.append("Body incomplet") }
        if lower.contains("@media") || lower.contains("clamp(") || lower.contains("min(") { passed.append("Responsive CSS") } else { warnings.append("Peu de règles responsive détectées") }
        if lower.contains("document.write(") { warnings.append("document.write() détecté") }
        if html.count > 750_000 { warnings.append("Document très volumineux") }

        return SarahWebAuditReport(errors: errors, warnings: warnings, passedChecks: passed)
    }

    private func extractHTMLDocument(_ raw: String) -> String? {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = cleaned.range(of: "```html", options: .caseInsensitive),
           let end = cleaned.range(of: "```", options: [], range: start.upperBound..<cleaned.endIndex) {
            cleaned = String(cleaned[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            cleaned = cleaned.replacingOccurrences(of: "```html", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard cleaned.lowercased().contains("<html") || cleaned.lowercased().contains("<!doctype html") else { return nil }
        return cleaned
    }

    private func stabilizeHTML(_ html: String) -> String {
        var result = html
        if !result.lowercased().contains("<!doctype html") {
            result = "<!doctype html>\n" + result
        }
        if !result.lowercased().contains("name=\"viewport\"") && !result.lowercased().contains("name='viewport'") {
            let viewport = "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1, viewport-fit=cover\">"
            if let range = result.range(of: "<head>", options: .caseInsensitive) {
                result.insert(contentsOf: "\n" + viewport, at: range.upperBound)
            }
        }
        let safetyCSS = """
        <style id="sarah-agentic-safety">
        html,body{max-width:100%;overflow-x:hidden}img,video,canvas,svg,iframe{max-width:100%;height:auto}*{box-sizing:border-box}
        </style>
        """
        if !result.contains("sarah-agentic-safety") {
            result = result.replacingOccurrences(of: "</head>", with: safetyCSS + "\n</head>", options: .caseInsensitive)
        }
        return result
    }

    private func appleStyleRefinement(_ html: String) -> String {
        guard !html.contains("sarah-apple-refinement") else { return html }
        let patch = """
        <style id="sarah-apple-refinement">
        :root{--sarah-glass:rgba(255,255,255,.075);--sarah-line:rgba(255,255,255,.12)}
        body{-webkit-font-smoothing:antialiased;text-rendering:optimizeLegibility}
        button,a,input,textarea,select{border-radius:14px}
        .card,.feature,.tool,.product,section{backdrop-filter:blur(22px);-webkit-backdrop-filter:blur(22px)}
        button,a{transition:transform .18s ease,opacity .18s ease}button:active,a:active{transform:scale(.98)}
        </style>
        """
        return html.replacingOccurrences(of: "</head>", with: patch + "\n</head>", options: .caseInsensitive)
    }

    private func applyLiteralEditIfPossible(_ instruction: String, html: String) -> String? {
        let patterns = [
            #"(?i)remplace\s+[«\"“](.+?)[»\"”]\s+par\s+[«\"“](.+?)[»\"”]"#,
            #"(?i)change\s+[«\"“](.+?)[»\"”]\s+(?:en|par)\s+[«\"“](.+?)[»\"”]"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(instruction.startIndex..., in: instruction)
            guard let match = regex.firstMatch(in: instruction, range: range), match.numberOfRanges >= 3,
                  let oldRange = Range(match.range(at: 1), in: instruction),
                  let newRange = Range(match.range(at: 2), in: instruction) else { continue }
            let old = String(instruction[oldRange])
            let new = String(instruction[newRange])
            if html.contains(old) { return html.replacingOccurrences(of: old, with: new) }
        }
        return nil
    }

    public func createOrRefineWebsite(prompt: String) -> SarahAgenticWebBuildResult {
        let clean = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = clean.lowercased()
        let existing = loadAgenticProject()
        let explicitNew = lower.contains("nouveau site") || lower.contains("nouveau projet") || lower.contains("repars de zéro") || lower.contains("repars de zero")
        let refinementWords = ["corrige", "change", "remplace", "modifie", "améliore", "ameliore", "erreur", "bug", "plus beau", "style apple", "ajoute", "supprime", "déplace", "deplace"]
        let looksLikeRefinement = refinementWords.contains { lower.contains($0) }
        let shouldRefine = existing != nil && !explicitNew && looksLikeRefinement

        var rootRequest = clean
        var html: String
        var revision = 1

        if shouldRefine, let existing = existing {
            rootRequest = existing.rootRequest
            revision = existing.revision + 1
            if let edited = applyLiteralEditIfPossible(clean, html: existing.html) {
                html = edited
            } else if lower.contains("apple") || lower.contains("plus beau") || lower.contains("design") || lower.contains("interface") {
                html = appleStyleRefinement(existing.html)
            } else {
                html = generateWebUI(prompt: existing.rootRequest + "\nModification : " + clean)
            }
        } else {
            html = generateWebUI(prompt: clean)
        }

        html = stabilizeHTML(html)
        let audit = auditWebHTML(html)
        let project = SarahPersistentWebProject(rootRequest: rootRequest, latestInstruction: clean, html: html, revision: revision, updatedAt: Date())
        persistAgenticProject(project)

        return SarahAgenticWebBuildResult(
            html: html,
            revision: revision,
            wasRefinement: shouldRefine,
            architectModel: SarahCodingModelCatalog.architect,
            implementerModel: SarahCodingModelCatalog.implementer,
            staticAudit: audit,
            browserAudit: nil,
            usedRemoteModels: false
        )
    }

    private func architectSystemPrompt() -> String {
        """
        Tu es l'architecte web de Sarah IA. Comprends précisément la demande en langage naturel, conserve les contraintes du projet déjà créé, repère les erreurs et prépare un plan exécutable pour un second modèle. Réponds uniquement avec un plan concis et structuré, sans HTML complet.
        """
    }

    private func implementerSystemPrompt() -> String {
        """
        Tu es le Code Worker de Sarah IA. Retourne uniquement un document HTML autonome complet avec CSS et JavaScript intégrés. Respecte le plan, préserve les fonctions déjà valides du projet existant, corrige les bugs signalés, rends le site responsive et accessible, et n'ajoute aucune fonctionnalité factice présentée comme réelle.
        """
    }

    private func repairSystemPrompt() -> String {
        """
        Tu es le relecteur final du Code Worker. Retourne uniquement le HTML complet corrigé. Corrige les erreurs WebKit, le débordement horizontal, les erreurs JavaScript et les balises incomplètes sans supprimer les fonctions valides du site.
        """
    }

    private func remoteAgenticBuild(prompt: String, completion: @escaping (SarahAgenticWebBuildResult?) -> Void) {
        let existing = loadAgenticProject()
        let context = existing.map { "Projet existant, révision \($0.revision). Demande initiale : \($0.rootRequest)\nHTML actuel :\n\($0.html)" } ?? "Aucun projet existant."

        SarahCodingRuntime.shared.generate(
            model: SarahCodingModelCatalog.architect,
            system: architectSystemPrompt(),
            user: context + "\n\nNouvelle demande : " + prompt
        ) { architectResult in
            guard case .success(let plan) = architectResult else { completion(nil); return }

            let implementerUser = "Plan de l'architecte :\n\(plan)\n\nDemande utilisateur :\n\(prompt)\n\nHTML précédent si présent :\n\(existing?.html ?? "Aucun")"
            SarahCodingRuntime.shared.generate(
                model: SarahCodingModelCatalog.implementer,
                system: self.implementerSystemPrompt(),
                user: implementerUser
            ) { codeResult in
                guard case .success(let rawCode) = codeResult,
                      var html = self.extractHTMLDocument(rawCode) else { completion(nil); return }

                html = self.stabilizeHTML(html)
                let revision = (existing?.revision ?? 0) + 1
                let root = existing?.rootRequest ?? prompt
                let project = SarahPersistentWebProject(rootRequest: root, latestInstruction: prompt, html: html, revision: revision, updatedAt: Date())
                self.persistAgenticProject(project)
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
            }
        }
    }

    public func runBrowserSmokeTest(html: String, completion: @escaping (SarahBrowserSmokeReport) -> Void) {
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

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                let script = """
                (() => JSON.stringify({
                  title: document.title || '',
                  buttons: document.querySelectorAll('button').length,
                  links: document.querySelectorAll('a').length,
                  body: !!document.body,
                  ready: document.readyState,
                  overflow: document.documentElement.scrollWidth > (window.innerWidth + 2),
                  brokenImages: Array.from(document.images).filter(i => i.complete && i.naturalWidth === 0).length,
                  errors: window.__sarahErrors || []
                }))()
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
                    let ready = json["ready"] as? String ?? ""
                    let overflow = json["overflow"] as? Bool ?? false
                    let brokenImages = json["brokenImages"] as? Int ?? 0
                    let jsErrors = json["errors"] as? [String] ?? []
                    let passed = body && (ready == "complete" || ready == "interactive") && !overflow && jsErrors.isEmpty

                    var details: [String] = []
                    details.append("DOM: \(ready.isEmpty ? "inconnu" : ready)")
                    if overflow { details.append("débordement horizontal") }
                    if brokenImages > 0 { details.append("\(brokenImages) image(s) cassée(s)") }
                    if !jsErrors.isEmpty { details.append("\(jsErrors.count) erreur(s) JavaScript") }
                    if passed { details.append("rendu mobile valide") }

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

    private func repairRemoteBuild(_ build: SarahAgenticWebBuildResult, report: SarahBrowserSmokeReport, completion: @escaping (SarahAgenticWebBuildResult) -> Void) {
        guard SarahCodingRuntime.shared.isConfigured else { completion(build); return }
        let auditText = "WebKit: \(report.details)\nErreurs JavaScript: \(report.javascriptErrors.joined(separator: " | "))\nAudit statique: \(build.staticAudit.errors.joined(separator: " | "))"
        SarahCodingRuntime.shared.generate(
            model: SarahCodingModelCatalog.implementer,
            system: repairSystemPrompt(),
            user: "Voici le HTML à corriger :\n\(build.html)\n\nRapport de test :\n\(auditText)"
        ) { result in
            guard case .success(let raw) = result,
                  var repaired = self.extractHTMLDocument(raw) else { completion(build); return }
            repaired = self.stabilizeHTML(repaired)
            var updated = build
            updated.html = repaired
            updated.staticAudit = self.auditWebHTML(repaired)
            if var project = self.loadAgenticProject() {
                project.html = repaired
                project.updatedAt = Date()
                self.persistAgenticProject(project)
            }
            completion(updated)
        }
    }

    public func buildAndTestWebsite(prompt: String, completion: @escaping (SarahAgenticWebBuildResult) -> Void) {
        let finish: (SarahAgenticWebBuildResult) -> Void = { build in
            self.runBrowserSmokeTest(html: build.html) { firstReport in
                if firstReport.passed {
                    var final = build
                    final.browserAudit = firstReport
                    completion(final)
                    return
                }

                self.repairRemoteBuild(build, report: firstReport) { repairedBuild in
                    let locallyStabilized = self.stabilizeHTML(repairedBuild.html)
                    self.runBrowserSmokeTest(html: locallyStabilized) { secondReport in
                        var final = repairedBuild
                        final.html = locallyStabilized
                        final.staticAudit = self.auditWebHTML(locallyStabilized)
                        final.browserAudit = secondReport
                        if var project = self.loadAgenticProject() {
                            project.html = locallyStabilized
                            project.updatedAt = Date()
                            self.persistAgenticProject(project)
                        }
                        completion(final)
                    }
                }
            }
        }

        if SarahCodingRuntime.shared.isConfigured {
            remoteAgenticBuild(prompt: prompt) { remote in
                if let remote = remote { finish(remote) }
                else { finish(self.createOrRefineWebsite(prompt: prompt)) }
            }
        } else {
            finish(createOrRefineWebsite(prompt: prompt))
        }
    }
}
'''
write(path, text)


# -----------------------------------------------------------------------------
# 4. Route Raphaël into the persistent architect -> worker -> WebKit loop.
# -----------------------------------------------------------------------------
path = 'SarahIA/SarahIA/Services/MultiAgentCoordinator.swift'
text = read(path)
text = text.replace(
    'let currentCode = VAICodeEngine.shared.generateWebUI(prompt: "dashboard")',
    'let currentCode = VAICodeEngine.shared.currentWebProjectHTML() ?? VAICodeEngine.shared.generateWebUI(prompt: "dashboard")'
)

# Make website requests route to Raphaël even if the user never says "code".
route_old = '''        if normalized.contains("esther") || normalized.contains("raphael") ||\n           normalized.contains("code") || normalized.contains("programme") ||\n           normalized.contains("shortcut") || normalized.contains("raccourci") ||'''
route_new = '''        if normalized.contains("esther") || normalized.contains("raphael") ||\n           normalized.contains("code") || normalized.contains("programme") ||\n           normalized.contains("site web") || normalized.contains("site internet") ||\n           normalized.contains("website") || normalized.contains("page web") ||\n           normalized.contains("frontend") || normalized.contains("javascript") ||\n           normalized.contains("shortcut") || normalized.contains("raccourci") ||'''
if route_old in text:
    text = text.replace(route_old, route_new, 1)

old = r'''        // 7. Projet web par défaut
        else {
            let html = VAICodeEngine.shared.generateWebUI(prompt: prompt)
            _ = VAICodeEngine.shared.saveFile(filename: "index.html", content: html)
            DevCodeInjector.injectRender(html: html, css: "", js: "")
            let responseText = "💻 **Raphaël [Prototype web]**\n\nJ’ai préparé un composant web dans `Documents/VAI_Workspace/index.html`. Ouvre le Studio si tu veux voir la prévisualisation, puis demande-moi les améliorations souhaitées."
            completion(AgentResponse(
                agent: .esther,
                text: responseText,
                spokenText: "Le prototype web est prêt. Tu peux ouvrir le Studio pour le voir, puis me demander des améliorations.",
                openStudio: true,
                generatedCode: html
            ))
        }
'''
new = r'''        // 7. Projet web agentique : Raphaël conserve le projet et ses révisions.
        else {
            VAICodeEngine.shared.buildAndTestWebsite(prompt: prompt) { build in
                DevCodeInjector.injectRender(html: build.html, css: "", js: "")

                let browserStatus: String
                if let browser = build.browserAudit {
                    browserStatus = browser.passed
                        ? "✅ WebKit : DOM chargé, JavaScript propre et largeur mobile valide."
                        : "⚠️ WebKit : \(browser.details)"
                } else {
                    browserStatus = "⚠️ Test WebKit indisponible."
                }

                let modelStatus = build.usedRemoteModels
                    ? "\(build.architectModel.displayName) → \(build.implementerModel.displayName)"
                    : "Moteur local de secours. Configure un endpoint OpenAI-compatible dans Réglages > Sarah Engine pour activer les deux modèles de code."

                let action = build.wasRefinement ? "mise à jour" : "création"
                let responseText = """
                💻 **Raphaël [Atelier Web Agentique]**

                Révision **#\(build.revision)** · \(action) terminée.
                **Pipeline :** \(modelStatus)
                \(browserStatus)

                Le fichier courant est `Documents/VAI_Workspace/index.html`. Tu peux maintenant dire « corrige ce bouton », « change ce texte », « ajoute une section » ou « rends-le plus Apple » dans la même discussion : Raphaël repartira de cette révision.
                """

                completion(AgentResponse(
                    agent: .esther,
                    text: responseText,
                    spokenText: "La révision \(build.revision) est prête. Le site a été chargé et testé dans WebKit. Tu peux me demander une nouvelle correction dans la même discussion.",
                    openStudio: true,
                    generatedCode: build.html
                ))
            }
        }
'''
text = replace_once(text, old, new, 'Raphael default web branch')
write(path, text)


# -----------------------------------------------------------------------------
# 5. Settings/About: expose the agentic runtime honestly.
# -----------------------------------------------------------------------------
path = 'SarahIA/SarahIA/Views/SettingsView.swift'
text = read(path)
text = text.replace(
    '/// Vue Réglages épurée et optimisée de Sarah AI Multi-Agents (100% Moteur Local On-Device) :',
    '/// Vue Réglages de Sarah AI Multi-Agents : moteurs locaux, voix et runtime de code agentique optionnel :'
)

old = r'''private struct SarahEngineSettingsView: View {
    @ObservedObject var viewModel: ChatViewModel

    private let imageProfile = SarahGenerativeModelCatalog.imageProfile()
    private let videoProfile = SarahGenerativeModelCatalog.videoProfile()
    private let musicProfile = SarahGenerativeModelCatalog.musicProfile()
    private let vocalSongProfile = SarahGenerativeModelCatalog.vocalSongProfile()
'''
new = r'''private struct SarahEngineSettingsView: View {
    @ObservedObject var viewModel: ChatViewModel
    @AppStorage("sarahCodingEndpoint") private var codingEndpoint: String = ""

    private let imageProfile = SarahGenerativeModelCatalog.imageProfile()
    private let videoProfile = SarahGenerativeModelCatalog.videoProfile()
    private let musicProfile = SarahGenerativeModelCatalog.musicProfile()
    private let vocalSongProfile = SarahGenerativeModelCatalog.vocalSongProfile()
    private let codingArchitect = SarahCodingModelCatalog.architect
    private let codingImplementer = SarahCodingModelCatalog.implementer
'''
text = replace_once(text, old, new, 'SarahEngine properties')

anchor = r'''                    engineCard(
                        icon: "photo.fill",
                        tint: .purple,
                        title: "Génération d’images",
                        value: imageProfile.displayName,
                        detail: imageProfile.note
                    )
'''
insert = r'''                    engineCard(
                        icon: "text.bubble.fill",
                        tint: .blue,
                        title: "Code · Architecte",
                        value: codingArchitect.displayName,
                        detail: codingArchitect.executionNote
                    )

                    engineCard(
                        icon: "hammer.fill",
                        tint: .indigo,
                        title: "Code · Code Worker",
                        value: codingImplementer.displayName,
                        detail: codingImplementer.executionNote
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Runtime de code agentique", systemImage: "network")
                            .font(.headline)
                            .foregroundColor(.white)

                        TextField("https://serveur-local:8000", text: $codingEndpoint)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                            .padding(12)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        Text(codingEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                             ? "Aucun serveur configuré : Raphaël utilise son générateur local de secours. Ajoute un endpoint OpenAI-compatible pour activer l’Architecte puis le Code Worker."
                             : "Endpoint configuré. Raphaël tentera d’abord les deux modèles de code puis reviendra au moteur local si le serveur est indisponible.")
                            .font(.footnote)
                            .foregroundColor(Color.white.opacity(0.54))

                        Text("Aucune clé API n’est enregistrée ici. Ce réglage est prévu d’abord pour un serveur local ou auto-hébergé que tu contrôles.")
                            .font(.caption)
                            .foregroundColor(Color.white.opacity(0.38))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.075))
                    )

                    engineCard(
                        icon: "photo.fill",
                        tint: .purple,
                        title: "Génération d’images",
                        value: imageProfile.displayName,
                        detail: imageProfile.note
                    )
'''
text = replace_once(text, anchor, insert, 'SarahEngine code cards')

about_anchor = r'''            Section("Informations légales") {
                NavigationLink(destination: LegalNoticesView()) {
'''
about_insert = r'''            Section("Développement agentique") {
                HStack {
                    Text("Architecte")
                    Spacer()
                    Text(SarahCodingModelCatalog.architect.displayName)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Text("Code Worker")
                    Spacer()
                    Text(SarahCodingModelCatalog.implementer.displayName)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                }

                Text("Raphaël conserve la dernière révision du site, applique les nouvelles consignes sur ce même projet puis charge le HTML dans WebKit pour vérifier le DOM, le JavaScript et le responsive. Sarah reste l’orchestratrice des familles de modèles.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section("Informations légales") {
                NavigationLink(destination: LegalNoticesView()) {
'''
text = replace_once(text, about_anchor, about_insert, 'About agentic section')

legal_anchor = r'''                Section("Génération d’images — cible locale") {
'''
legal_insert = r'''                Section("Développement agentique — Qwen3-Coder") {
                    Text("Sarah IA référence Qwen3-Coder-Next pour le rôle d’architecte et Qwen3-Coder-30B-A3B-Instruct pour le rôle de Code Worker. Les deux modèles sont publiés sous licence Apache-2.0.")
                    Text("Leurs poids ne sont pas distribués dans l’IPA. L’application sait appeler un endpoint OpenAI-compatible configuré par l’utilisateur ; sans endpoint, Raphaël utilise le moteur local de secours et l’indique explicitement.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Link("Qwen3-Coder-Next", destination: URL(string: "https://huggingface.co/Qwen/Qwen3-Coder-Next")!)
                    Link("Qwen3-Coder-30B-A3B-Instruct", destination: URL(string: "https://huggingface.co/Qwen/Qwen3-Coder-30B-A3B-Instruct")!)
                    Link("Licence Apache-2.0", destination: URL(string: "https://www.apache.org/licenses/LICENSE-2.0")!)
                }

                Section("Génération d’images — cible locale") {
'''
text = replace_once(text, legal_anchor, legal_insert, 'Legal code models')
write(path, text)


# -----------------------------------------------------------------------------
# 6. Documentation: make the new architecture visible in the repository.
# -----------------------------------------------------------------------------
path = 'README.md'
text = read(path)
marker = '## Raphaël · développement agentique'
if marker not in text:
    text += r'''

## Raphaël · développement agentique

Sarah reste l'orchestratrice centrale. Pour le développement web, Raphaël utilise une architecture à deux rôles : **Qwen3-Coder-Next** comme architecte de projet et **Qwen3-Coder-30B-A3B-Instruct** comme Code Worker. Les gros poids ne sont pas embarqués dans l'IPA : un endpoint OpenAI-compatible auto-hébergé peut être configuré dans les réglages. Sans endpoint, l'application garde son générateur local de secours.

Le projet web courant est persisté dans `Documents/VAI_Workspace/index.html` avec un numéro de révision. Les demandes suivantes peuvent modifier la même base. Chaque génération passe ensuite dans un audit statique puis dans un `WKWebView` de test qui vérifie le chargement DOM, les erreurs JavaScript capturées et les débordements horizontaux.

La branche produit ne contient plus de moteur SceneKit/RealityKit ni de ressource USDZ/Reality liée à une fonctionnalité 3D.
'''
write(path, text)


# -----------------------------------------------------------------------------
# 7. Sanity checks, then remove the temporary self-upgrade files from the result.
# -----------------------------------------------------------------------------
required_tokens = {
    'SarahIA/SarahIA/Services/HardwareDetector.swift': ['Qwen3-Coder-Next', 'SarahModelAuthority'],
    'SarahIA/SarahIA/Services/VAICodeEngine.swift': ['SarahAgenticWebBuildResult', 'runBrowserSmokeTest', 'buildAndTestWebsite'],
    'SarahIA/SarahIA/Services/MultiAgentCoordinator.swift': ['Atelier Web Agentique', 'buildAndTestWebsite'],
    'SarahIA/SarahIA/Views/SettingsView.swift': ['Runtime de code agentique', 'Développement agentique'],
}
for p, tokens in required_tokens.items():
    data = read(p)
    for token in tokens:
        if token not in data:
            raise SystemExit(f'Missing {token!r} in {p}')

# No semantic 3D engine references may remain in active app code.
for token in ['SceneKit', 'RealityKit', 'Model3D', '.usdz', '.reality']:
    for p in (ROOT / 'SarahIA' / 'SarahIA').rglob('*.swift'):
        data = p.read_text(encoding='utf-8', errors='ignore')
        if token.lower() in data.lower():
            raise SystemExit(f'Unexpected 3D token {token!r} in {p}')

# Remove the one-shot machinery itself from the committed result.
for temp in [
    ROOT / '.github' / 'workflows' / 'sarah-agentic-upgrade.yml',
    ROOT / '.github' / 'scripts' / 'apply_sarah_agentic_upgrade.py',
]:
    if temp.exists():
        temp.unlink()

print('Sarah agentic coding upgrade applied successfully')
