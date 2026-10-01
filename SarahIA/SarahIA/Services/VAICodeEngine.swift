import Foundation
import WebKit

/// Moteur de Code Autonome Raphaël (Agent Développeur & VAI Coding).
/// Capable de générer du code Web (HTML/CSS/JS monopage), Swift et Python.
public final class VAICodeEngine {
    
    public static let shared = VAICodeEngine()
    
    public struct CodeProject: Identifiable, Codable {
        public let id: String
        public var title: String
        public var language: String // "html", "swift", "python"
        public var code: String
        public var createdAt: Date
        public var updatedAt: Date
    }
    
    private var workspaceDirectory: URL {
        let fm = FileManager.default
        let docURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let wsURL = docURL.appendingPathComponent("VAI_Workspace", isDirectory: true)
        if !fm.fileExists(atPath: wsURL.path) {
            try? fm.createDirectory(at: wsURL, withIntermediateDirectories: true, attributes: nil)
        }
        return wsURL
    }
    
    private init() {}
    
    /// Sauvegarde ou met à jour un fichier dans Documents/VAI_Workspace/
    public func saveFile(filename: String, content: String) -> URL? {
        let fileURL = workspaceDirectory.appendingPathComponent(filename)
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("❌ [VAICodeEngine] Erreur d'écriture de fichier: \(error)")
            return nil
        }
    }
    
    // Génération Web par templates supprimée : aucun dashboard, boutique ou
    // landing page prédéfini n'est fabriqué en secours.

    /// Génère une base SwiftUI locale lorsque Raphaël reçoit une demande iOS.
    /// Ce n'est pas présenté comme une application compilée : c'est un point de départ
    /// clair, que la personne peut ensuite faire préciser et améliorer dans le chat.
    public func generateSwiftUIStarter(prompt: String) -> String {
        let escapedPrompt = prompt
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")

        return """
        import SwiftUI

        /// Première base générée par Raphaël pour : \(escapedPrompt)
        struct RaphaelGeneratedView: View {
            @State private var input = ""
            @State private var items: [String] = []

            var body: some View {
                NavigationView {
                    List {
                        Section("Votre idée") {
                            TextField("Ajouter un élément", text: $input)
                            Button("Ajouter") {
                                let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !value.isEmpty else { return }
                                items.append(value)
                                input = ""
                            }
                        }

                        Section("Contenu") {
                            if items.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "sparkles")
                                        .font(.title2)
                                        .foregroundColor(.accentColor)
                                    Text("Prêt à personnaliser")
                                        .font(.headline)
                                    Text("Décris à Raphaël les écrans, données et actions à ajouter.")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                            } else {
                                ForEach(items, id: \\.self) { item in
                                    Text(item)
                                }
                                .onDelete { items.remove(atOffsets: $0) }
                            }
                        }
                    }
                    .navigationTitle("Prototype")
                }
            }
        }

        struct RaphaelGeneratedView_Previews: PreviewProvider {
            static var previews: some View {
                RaphaelGeneratedView()
            }
        }
        """
    }

    /// Petite base de script pour les demandes Python ; elle reste éditable et ne prétend
    /// pas avoir été exécutée sur l'iPhone.
    public func generatePythonStarter(prompt: String) -> String {
        let escapedPrompt = prompt.replacingOccurrences(of: "\"", with: "\\\"")
        return """
        \"\"\"Base préparée par Raphaël pour : \(escapedPrompt)\"\"\"

        def main() -> None:
            # TODO: préciser les entrées, le traitement et le résultat attendu.
            print("Prototype prêt à être développé.")


        if __name__ == "__main__":
            main()
        """
    }

    // Aucun site n'est assemblé avec des blocs HTML codés en dur. Le brief
    // passe exclusivement par le pipeline de modèles de code ci-dessous.

    // Les anciens templates WebsiteBrief ont été supprimés. Le créateur de site
    // utilise maintenant l'inférence réelle pilotée par ChatViewModel.

    private func htmlEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
// MARK: - Intégrations Développeur & Cloud (GitHub, Gmail, Google Play Console, Déploiement Web)
    
    public func getGitHubAuthURL() -> URL {
        return URL(string: "https://github.com/login")!
    }
    
    public func deployProjectOnline(projectName: String, htmlCode: String) -> (liveURL: String, status: String) {
        let cleanName = projectName.lowercased().replacingOccurrences(of: " ", with: "-")
        let filename = "\(cleanName)_ready_to_publish.html"
        _ = saveFile(filename: filename, content: htmlCode)
        let statusMsg = "📦 **Projet préparé localement**\n\nLe fichier HTML est prêt dans `Documents/VAI_Workspace/\(filename)`.\n\nAucune URL publique n’a été créée : pour le mettre réellement en ligne, il faut connecter un dépôt GitHub ou un hébergeur autorisé, puis lancer une publication."
        return ("", statusMsg)
    }
    
    public func getGoogleMailURL() -> URL {
        return URL(string: "https://mail.google.com")!
    }
    
    public func getGooglePlayConsoleURL() -> URL {
        return URL(string: "https://play.google.com/console")!
    }
    
    public func generateGooglePlayManifest(appName: String, packageName: String) -> String {
        return """
        <?xml version="1.0" encoding="utf-8"?>
        <manifest xmlns:android="http://schemas.android.com/apk/res/android"
            package="\(packageName)">
            <application
                android:allowBackup="true"
                android:icon="@mipmap/ic_launcher"
                android:label="\(appName)"
                android:roundIcon="@mipmap/ic_launcher_round"
                android:supportsRtl="true"
                android:theme="@style/Theme.SarahAI">
                <activity
                    android:name=".MainActivity"
                    android:exported="true">
                    <intent-filter>
                        <action android:name="android.intent.action.MAIN" />
                        <category android:name="android.intent.category.LAUNCHER" />
                    </intent-filter>
                </activity>
            </application>
        </manifest>
        """
    }
    
    public func ingestDesignTokens(jsonString: String) -> String {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return "⚠️ Format de tokens invalide. Fournissez un JSON valide avec les clés de style ou calques Figma."
        }
        
        var parsedSummary = "🎨 **Raphaël [Ingestion Design Tokens Figma/Stitch]**\n\n"
        parsedSummary += "• **Propriétés détectées :** \(json.keys.count) variables\n"
        if let colors = json["colors"] as? [String: String] {
            parsedSummary += "• **Palette :** \(colors.keys.joined(separator: ", "))\n"
        }
        if let typography = json["typography"] as? [String: Any] {
            parsedSummary += "• **Typographie :** \(typography.keys.joined(separator: ", "))\n"
        }
        parsedSummary += "\n✨ Composant Web prêt à être généré dans `Documents/VAI_Workspace/`."
        return parsedSummary
    }
}


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
            return "Le HTML généré n'a pas passé le contrôle WebKit : \(details). Aucun fallback prédéfini n'a été injecté."
        }
    }
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

        let revisions = workspaceDirectory.appendingPathComponent("revisions", isDirectory: true)
        try? FileManager.default.createDirectory(at: revisions, withIntermediateDirectories: true)
        let snapshot = revisions.appendingPathComponent("index-r\(project.revision).html")
        try? project.html.write(to: snapshot, atomically: true, encoding: .utf8)
    }

    public func currentWebProjectHTML() -> String? { loadAgenticProject()?.html }

    public func resetCurrentWebProject() {
        try? FileManager.default.removeItem(at: agenticProjectURL)
        try? FileManager.default.removeItem(at: workspaceDirectory.appendingPathComponent("index.html"))
    }

    public var isRealWebGenerationConfigured: Bool {
        SarahCodingRuntime.shared.isConfigured
    }

    public func auditWebHTML(_ html: String) -> SarahWebAuditReport {
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
        if hasRegex(#"<html[^>]*\slang\s*="#) { passed.append("Langue du document") } else { warnings.append("Attribut lang manquant sur <html>") }
        if lower.contains("charset=") { passed.append("UTF-8 déclaré") } else { warnings.append("Meta charset manquante") }
        if hasRegex(#"<title>\s*[^<]{2,}\s*</title>"#) { passed.append("Titre de page") } else { errors.append("Titre de page vide ou manquant") }
        if lower.contains("name=\"description\"") || lower.contains("name='description'") { passed.append("Meta description") } else { warnings.append("Meta description manquante") }
        if lower.contains("<main") { passed.append("Landmark main") } else { warnings.append("Balise <main> manquante") }
        if hasRegex(#"<h1(?:\s|>)[\s\S]*?</h1>"#) { passed.append("Titre H1") } else { errors.append("H1 manquant") }
        if lower.contains("@media") || lower.contains("clamp(") || lower.contains("min(") || lower.contains("max(") { passed.append("Responsive CSS") } else { warnings.append("Peu de règles responsive détectées") }

        let forbiddenPlaceholders = ["lorem ipsum", "produit 01", "offre 01", "example.com", "placeholder.com", "à compléter", "todo:"]
        let foundPlaceholders = forbiddenPlaceholders.filter { lower.contains($0) }
        if foundPlaceholders.isEmpty { passed.append("Contenu non factice") } else { errors.append("Contenu factice détecté : " + foundPlaceholders.joined(separator: ", ")) }

        let remoteAssetPatterns = [
            #"(?:src|poster)\s*=\s*["']https?://"#,
            #"<link[^>]+href\s*=\s*["']https?://"#,
            #"url\(\s*["']?https?://"#
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
        var result = html.trimmingCharacters(in: .whitespacesAndNewlines)
        if !result.lowercased().contains("<!doctype html") {
            result = "<!doctype html>\n" + result
        }
        if let htmlRange = result.range(of: "<html", options: .caseInsensitive),
           let close = result[htmlRange.lowerBound...].firstIndex(of: ">") {
            let opening = String(result[htmlRange.lowerBound...close])
            if !opening.lowercased().contains(" lang=") {
                result.replaceSubrange(htmlRange.lowerBound...close, with: String(opening.dropLast()) + " lang=\"fr\">")
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

    private func architectSystemPrompt() -> String {
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
            }
        }
    }

    private func localAgenticBuild(
        prompt: String,
        completion: @escaping (SarahAgenticWebBuildResult?) -> Void
    ) {
        let existing = loadAgenticProject()
        var fullPrompt = implementerSystemPrompt() + "\n\nDEMANDE :\n" + prompt
        if let existing {
            fullPrompt += "\n\nPROJET EXISTANT À AMÉLIORER, RÉVISION \(existing.revision) :\n" + existing.html
        }

        AIService.shared.generateLocalCodeDocument(prompt: fullPrompt) { result in
            guard case .success(let raw) = result,
                  var html = self.extractHTMLDocument(raw) else {
                completion(nil)
                return
            }
            html = self.stabilizeHTML(html)
            let candidate = SarahAgenticWebBuildResult(
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
        }
    }

    private func qualityReviewLocalBuild(
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

    private func repairLocalBuild(
        _ build: SarahAgenticWebBuildResult,
        report: SarahBrowserSmokeReport,
        completion: @escaping (SarahAgenticWebBuildResult) -> Void
    ) {
        let prompt = repairSystemPrompt()
            + "\n\nHTML À CORRIGER :\n" + build.html
            + "\n\nRAPPORT WEBKIT :\n" + report.details
            + "\nErreurs JavaScript : " + report.javascriptErrors.joined(separator: " | ")

        AIService.shared.generateLocalCodeDocument(prompt: prompt) { result in
            guard case .success(let raw) = result,
                  var html = self.extractHTMLDocument(raw) else {
                completion(build)
                return
            }
            html = self.stabilizeHTML(html)
            var updated = build
            updated.html = html
            updated.staticAudit = self.auditWebHTML(html)
            completion(updated)
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
                  const brokenLocalLinks = localLinks.filter(a => { const href = a.getAttribute('href') || ''; const id = decodeURIComponent(href.slice(1)); return !id || !document.getElementById(id); }).length;
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
            completion(updated)
        }
    }
    /// Génère et teste un vrai site. Si un endpoint de code est configuré il est
    /// utilisé, sinon Raphaël passe au moteur IA local. Dans les deux cas, le HTML
    /// vient d'une inférence de modèle puis passe un audit statique et WebKit.
    public func buildAndTestWebsite(
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

}

