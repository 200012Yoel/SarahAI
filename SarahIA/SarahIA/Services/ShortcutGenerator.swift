import Foundation
import UIKit

#if canImport(AppIntents)
import AppIntents
#endif

/// Pont natif entre Sarah IA et Apple Shortcuts.
///
/// Principes :
/// - Les actions Sarah sont exposées nativement à Raccourcis via App Intents (iOS 16+).
/// - Sarah peut générer localement un brouillon plist de raccourci pour les workflows.
/// - Un fichier .shortcut arbitraire ne peut pas être signé silencieusement sur iPhone
///   par une API publique Apple ; Sarah n'affiche donc jamais une fausse "signature réussie".
/// - Pour les actions Sarah elles-mêmes, App Intents évite totalement ce problème :
///   iOS les publie directement dans l'app Raccourcis.
public final class ShortcutGenerator {

    public static let shared = ShortcutGenerator()

    public struct ShortcutSchema: Codable {
        public let id: String
        public let title: String
        public let action: String
        public let parameters: [String: String]
        public let createdAt: Date
    }

    public struct DraftResult {
        public let title: String
        public let plistString: String
        public let fileURL: URL
        public let actionCount: Int
        public let summary: String
    }

    public enum ShortcutBuildError: LocalizedError {
        case serializationFailed
        case writeFailed

        public var errorDescription: String? {
            switch self {
            case .serializationFailed:
                return "Impossible de sérialiser le brouillon Apple Shortcuts."
            case .writeFailed:
                return "Impossible d'enregistrer le brouillon dans le dossier Shortcuts de Sarah."
            }
        }
    }

    /// Couverture documentaire de la référence Shortcuts utilisée pendant le développement.
    /// Ces nombres décrivent la référence technique consultée, pas 1 155 fonctions codées
    /// en dur dans Sarah.
    public static let documentedLegacyActionCount = 427
    public static let documentedAppIntentCount = 728
    public static let documentedActionCoverage = documentedLegacyActionCount + documentedAppIntentCount

    /// Familles d'actions que le compilateur local de Sarah sait actuellement produire
    /// de manière déterministe, sans demander à un LLM d'inventer des clés plist.
    public static let locallyValidatedActionFamilies: [String] = [
        "Texte", "Afficher le résultat", "Demander une saisie", "Notification",
        "Presse-papiers", "URL", "Ouvrir une URL", "Commentaire",
        "Batterie", "Date actuelle", "Attendre", "Vibrer"
    ]

    private var shortcutsDirectory: URL {
        let fm = FileManager.default
        let base = fm.urls(for: .documentDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("Shortcuts", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private init() {}

    // MARK: - API historique

    public func createShortcut(
        title: String,
        action: String,
        parameters: [String: String]
    ) -> ShortcutSchema {
        let id = "shortcut_\(Int(Date().timeIntervalSince1970))"
        let schema = ShortcutSchema(
            id: id,
            title: title,
            action: action,
            parameters: parameters,
            createdAt: Date()
        )

        let file = shortcutsDirectory.appendingPathComponent("\(id).json")
        if let data = try? JSONEncoder().encode(schema) {
            try? data.write(to: file, options: .atomic)
        }
        return schema
    }

    // MARK: - Génération locale de brouillons

    /// Construit un plist Shortcuts réel à partir des intentions courantes.
    /// Le résultat reste un brouillon non signé tant qu'il n'est pas finalisé
    /// par l'app Raccourcis / un outil Apple de signature.
    public func createDraft(title: String, prompt: String) throws -> DraftResult {
        let finalTitle = normalizedTitle(title)
        let actions = buildActions(from: prompt, title: finalTitle)

        let root: [String: Any] = [
            "WFWorkflowClientVersion": "3107.0.8.2",
            "WFWorkflowClientRelease": "22.1",
            "WFWorkflowMinimumClientVersion": 900,
            "WFWorkflowTypes": ["NCWidget", "WatchKit"],
            "WFWorkflowIcon": [
                "WFWorkflowIconStartColor": 4282601983,
                "WFWorkflowIconGlyphNumber": 61440
            ],
            "WFWorkflowImportQuestions": [],
            "WFWorkflowInputContentItemClasses": ["WFAppStoreAppContentItem"],
            "WFWorkflowActions": actions
        ]

        let data: Data
        do {
            data = try PropertyListSerialization.data(
                fromPropertyList: root,
                format: .xml,
                options: 0
            )
        } catch {
            throw ShortcutBuildError.serializationFailed
        }

        guard let plist = String(data: data, encoding: .utf8) else {
            throw ShortcutBuildError.serializationFailed
        }

        let url = shortcutsDirectory
            .appendingPathComponent("\(safeFilename(finalTitle)).shortcut")

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw ShortcutBuildError.writeFailed
        }

        return DraftResult(
            title: finalTitle,
            plistString: plist,
            fileURL: url,
            actionCount: actions.count,
            summary: "Brouillon « \(finalTitle) » créé avec \(actions.count) action(s). Il peut être inspecté dans Sarah puis finalisé dans Apple Raccourcis."
        )
    }

    public func createDraftJSON(title: String, prompt: String) -> String {
        do {
            let draft = try createDraft(title: title, prompt: prompt)
            return draft.plistString
        } catch {
            return "Erreur Shortcuts : \(error.localizedDescription)"
        }
    }

    // MARK: - Connexion à l'app Raccourcis

    /// Ouvre l'app Raccourcis.
    @MainActor
    public func openShortcutsApp() {
        guard let url = URL(string: "shortcuts://") else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    /// Ouvre l'éditeur d'un nouveau raccourci.
    @MainActor
    public func openShortcutCreation() {
        guard let url = URL(string: "shortcuts://create-shortcut") else {
            openShortcutsApp()
            return
        }
        UIApplication.shared.open(url, options: [:]) { success in
            if !success {
                self.openShortcutsApp()
            }
        }
    }

    /// Exécute un raccourci déjà présent dans la bibliothèque de l'utilisateur.
    /// Le nom est encodé et l'entrée texte est transmise par l'URL officielle.
    @MainActor
    public func runInstalledShortcut(named name: String, input: String? = nil) {
        var components = URLComponents()
        components.scheme = "shortcuts"
        components.host = "run-shortcut"

        var items = [URLQueryItem(name: "name", value: name)]
        if let input, !input.isEmpty {
            items.append(URLQueryItem(name: "input", value: "text"))
            items.append(URLQueryItem(name: "text", value: input))
        }
        components.queryItems = items

        if let url = components.url {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    /// Ouvre un raccourci existant dans l'éditeur Shortcuts.
    @MainActor
    public func openInstalledShortcut(named name: String) {
        var components = URLComponents()
        components.scheme = "shortcuts"
        components.host = "open-shortcut"
        components.queryItems = [URLQueryItem(name: "name", value: name)]

        if let url = components.url {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    // MARK: - Compilateur déterministe

    private func buildActions(from prompt: String, title: String) -> [[String: Any]] {
        let lower = prompt
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)

        var actions: [[String: Any]] = [
            action(
                "is.workflow.actions.comment",
                [
                    "WFCommentActionText":
                        "Créé par Sarah IA. Demande originale : \(prompt)"
                ]
            )
        ]

        if lower.contains("demande") || lower.contains("saisie") || lower.contains("ask") {
            actions.append(
                action(
                    "is.workflow.actions.ask",
                    [
                        "WFAskActionPrompt": extractQuotedText(from: prompt) ?? "Que souhaitez-vous saisir ?",
                        "WFInputType": "Text"
                    ]
                )
            )
        }

        if lower.contains("batterie") || lower.contains("battery") {
            actions.append(
                action(
                    "is.workflow.actions.getbatterylevel",
                    [:]
                )
            )
        }

        if lower.contains("date") || lower.contains("heure") || lower.contains("time") {
            actions.append(
                action(
                    "is.workflow.actions.date",
                    [:]
                )
            )
        }

        if lower.contains("presse-papier") || lower.contains("presse papier") || lower.contains("clipboard") {
            if lower.contains("copie") || lower.contains("mettre") || lower.contains("set") {
                actions.append(
                    action(
                        "is.workflow.actions.setclipboard",
                        ["WFText": extractQuotedText(from: prompt) ?? prompt]
                    )
                )
            } else {
                actions.append(
                    action(
                        "is.workflow.actions.getclipboard",
                        [:]
                    )
                )
            }
        }

        if let url = extractURL(from: prompt) {
            actions.append(
                action(
                    "is.workflow.actions.url",
                    ["WFURLActionURL": url]
                )
            )
            actions.append(
                action(
                    "is.workflow.actions.openurl",
                    [:]
                )
            )
        }

        if lower.contains("notification") || lower.contains("notifie") || lower.contains("alerte") {
            actions.append(
                action(
                    "is.workflow.actions.notification",
                    [
                        "WFNotificationActionTitle": title,
                        "WFNotificationActionBody": extractQuotedText(from: prompt) ?? prompt
                    ]
                )
            )
        }

        if lower.contains("attends") || lower.contains("attendre") || lower.contains("wait") {
            actions.append(
                action(
                    "is.workflow.actions.delay",
                    ["WFDelayTime": 1]
                )
            )
        }

        if lower.contains("vibre") || lower.contains("vibrer") || lower.contains("vibration") {
            actions.append(
                action(
                    "is.workflow.actions.vibrate",
                    [:]
                )
            )
        }

        if lower.contains("texte") || lower.contains("text") || actions.count == 1 {
            actions.append(
                action(
                    "is.workflow.actions.gettext",
                    [
                        "WFTextActionText": extractQuotedText(from: prompt) ?? prompt
                    ]
                )
            )
        }

        if lower.contains("affiche") || lower.contains("montre") || lower.contains("show") || actions.count == 2 {
            actions.append(
                action(
                    "is.workflow.actions.showresult",
                    [
                        "Text": "Exécution terminée par Sarah IA"
                    ]
                )
            )
        }

        return actions
    }

    private func action(_ identifier: String, _ parameters: [String: Any]) -> [String: Any] {
        var mutable = parameters
        mutable["UUID"] = UUID().uuidString.uppercased()
        return [
            "WFWorkflowActionIdentifier": identifier,
            "WFWorkflowActionParameters": mutable
        ]
    }

    private func normalizedTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Raccourci Sarah" : trimmed
    }

    private func safeFilename(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        return value
            .components(separatedBy: invalid)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractURL(from text: String) -> String? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector
            .firstMatch(in: text, options: [], range: range)?
            .url?
            .absoluteString
    }

    private func extractQuotedText(from text: String) -> String? {
        let patterns = [
            "«([^»]+)»",
            "\"([^\"]+)\"",
            "“([^”]+)”"
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(
                    in: text,
                    range: NSRange(text.startIndex..<text.endIndex, in: text)
                  ),
                  match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: text) else {
                continue
            }
            return String(text[range])
        }
        return nil
    }
}

// MARK: - Actions Sarah visibles dans Apple Raccourcis

#if canImport(AppIntents)
@available(iOS 16.0, *)
public struct AskSarahIntent: AppIntent {
    public static var title: LocalizedStringResource = "Demander à Sarah"
    public static var description = IntentDescription(
        "Envoie une demande à Sarah IA et renvoie sa réponse au raccourci."
    )

    @Parameter(title: "Demande")
    public var request: String

    public init() {}

    public func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let response: String = await withCheckedContinuation { continuation in
            AIService.shared.processQuery(request) { text in
                continuation.resume(returning: text)
            }
        }
        return .result(value: response)
    }
}

@available(iOS 16.0, *)
public struct NewSarahChatIntent: AppIntent {
    public static var title: LocalizedStringResource = "Nouveau chat Sarah"
    public static var description = IntentDescription(
        "Ouvre une nouvelle discussion vide dans Sarah IA."
    )
    public static var openAppWhenRun: Bool = true

    public init() {}

    public func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(
            name: .sarahStartNewChat,
            object: nil
        )
        return .result()
    }
}

@available(iOS 16.0, *)
public struct CreateSarahShortcutDraftIntent: AppIntent {
    public static var title: LocalizedStringResource = "Créer un brouillon de raccourci"
    public static var description = IntentDescription(
        "Demande à Sarah de préparer un workflow Apple Shortcuts local."
    )

    @Parameter(title: "Nom")
    public var name: String

    @Parameter(title: "Description")
    public var request: String

    public init() {}

    public func perform() async throws -> some IntentResult & ReturnsValue<String> {
        do {
            let result = try ShortcutGenerator.shared.createDraft(
                title: name,
                prompt: request
            )
            return .result(value: result.summary)
        } catch {
            return .result(value: "Erreur : \(error.localizedDescription)")
        }
    }
}

@available(iOS 16.0, *)
public struct SarahAppShortcutsProvider: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        [
            AppShortcut(
                intent: AskSarahIntent(),
                phrases: [
                    "Demande à \(.applicationName)",
                    "Pose une question à \(.applicationName)"
                ],
                shortTitle: "Demander à Sarah",
                systemImageName: "sparkles"
            ),
            AppShortcut(
                intent: NewSarahChatIntent(),
                phrases: [
                    "Nouveau chat avec \(.applicationName)"
                ],
                shortTitle: "Nouveau chat",
                systemImageName: "square.and.pencil"
            ),
            AppShortcut(
                intent: CreateSarahShortcutDraftIntent(),
                phrases: [
                    "Crée un raccourci avec \(.applicationName)"
                ],
                shortTitle: "Créer un raccourci",
                systemImageName: "wand.and.stars"
            )
        ]
    }
}
#endif
