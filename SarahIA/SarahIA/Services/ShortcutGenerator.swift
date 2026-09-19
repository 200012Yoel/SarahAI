import Foundation
import UIKit

#if canImport(AppIntents)
import AppIntents
#endif

/// Pont 100 % local entre Sarah IA et Apple Raccourcis.
///
/// Sarah peut :
/// - proposer un plan d'actions ;
/// - générer localement un plist Shortcuts ;
/// - ouvrir l'éditeur Raccourcis ;
/// - lancer ou ouvrir un raccourci déjà installé ;
/// - exposer ses propres actions via App Intents.
///
/// Apple ne fournit pas d'API publique permettant à une app tierce d'injecter
/// silencieusement des blocs arbitraires dans l'éditeur Raccourcis ou de signer
/// localement un .shortcut arbitraire sur iPhone. Sarah reste donc strictement
/// dans les API publiques et ne transmet aucune définition de raccourci à un serveur.
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

    public struct PlanStep: Identifiable, Codable, Equatable {
        public let id: UUID
        public let title: String
        public let actionIdentifier: String
        public let explanation: String

        public init(title: String, actionIdentifier: String, explanation: String) {
            self.id = UUID()
            self.title = title
            self.actionIdentifier = actionIdentifier
            self.explanation = explanation
        }
    }

    public enum ShortcutBuildError: LocalizedError {
        case serializationFailed
        case writeFailed

        public var errorDescription: String? {
            switch self {
            case .serializationFailed:
                return "Impossible de sérialiser le brouillon Apple Raccourcis."
            case .writeFailed:
                return "Impossible d'enregistrer le brouillon local."
            }
        }
    }

    public static let documentedLegacyActionCount = 427
    public static let documentedAppIntentCount = 728
    public static let documentedActionCoverage = documentedLegacyActionCount + documentedAppIntentCount

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

    // MARK: - Plan local interactif

    /// Prépare les étapes que l'interface Sarah peut faire confirmer une par une.
    public func proposePlan(for prompt: String) -> [PlanStep] {
        let lower = normalized(prompt)
        var steps: [PlanStep] = []

        steps.append(PlanStep(
            title: "Commentaire Sarah",
            actionIdentifier: "is.workflow.actions.comment",
            explanation: "Ajoute une note expliquant la demande d'origine."
        ))

        if lower.contains("demande") || lower.contains("saisie") || lower.contains("question") {
            steps.append(PlanStep(
                title: "Demander une saisie",
                actionIdentifier: "is.workflow.actions.ask",
                explanation: "Demande une information à l'utilisateur."
            ))
        }

        if lower.contains("batterie") {
            steps.append(PlanStep(
                title: "Niveau de batterie",
                actionIdentifier: "is.workflow.actions.getbatterylevel",
                explanation: "Récupère le niveau de batterie de l'iPhone."
            ))
        }

        if lower.contains("presse papier") || lower.contains("presse-papier") || lower.contains("clipboard") {
            steps.append(PlanStep(
                title: "Presse-papiers",
                actionIdentifier: lower.contains("copie") ? "is.workflow.actions.setclipboard" : "is.workflow.actions.getclipboard",
                explanation: "Lit ou modifie le presse-papiers."
            ))
        }

        if extractURL(from: prompt) != nil || lower.contains("url") || lower.contains("site") {
            steps.append(PlanStep(
                title: "Ouvrir une URL",
                actionIdentifier: "is.workflow.actions.openurl",
                explanation: "Ouvre l'adresse demandée."
            ))
        }

        if lower.contains("notification") || lower.contains("alerte") || lower.contains("notifie") {
            steps.append(PlanStep(
                title: "Notification",
                actionIdentifier: "is.workflow.actions.notification",
                explanation: "Affiche une notification locale."
            ))
        }

        if lower.contains("attend") || lower.contains("pause") {
            steps.append(PlanStep(
                title: "Attendre",
                actionIdentifier: "is.workflow.actions.delay",
                explanation: "Insère une courte attente."
            ))
        }

        if lower.contains("vibre") || lower.contains("vibration") {
            steps.append(PlanStep(
                title: "Vibrer",
                actionIdentifier: "is.workflow.actions.vibrate",
                explanation: "Déclenche une vibration."
            ))
        }

        if steps.count == 1 {
            steps.append(PlanStep(
                title: "Texte",
                actionIdentifier: "is.workflow.actions.gettext",
                explanation: "Prépare le texte demandé."
            ))
            steps.append(PlanStep(
                title: "Afficher le résultat",
                actionIdentifier: "is.workflow.actions.showresult",
                explanation: "Affiche le résultat à l'écran."
            ))
        }

        return steps
    }

    // MARK: - Génération locale

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
            summary: "Brouillon local « \(finalTitle) » créé avec \(actions.count) action(s)."
        )
    }

    public func createDraftJSON(title: String, prompt: String) -> String {
        do {
            return try createDraft(title: title, prompt: prompt).plistString
        } catch {
            return "Erreur Raccourcis : \(error.localizedDescription)"
        }
    }

    // MARK: - Apple Raccourcis

    @MainActor
    public func openShortcutsApp() {
        guard let url = URL(string: "shortcuts://") else { return }
        UIApplication.shared.open(url)
    }

    @MainActor
    public func openShortcutCreation() {
        guard let url = URL(string: "shortcuts://create-shortcut") else {
            openShortcutsApp()
            return
        }
        UIApplication.shared.open(url) { success in
            if !success {
                self.openShortcutsApp()
            }
        }
    }

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
            UIApplication.shared.open(url)
        }
    }

    @MainActor
    public func openInstalledShortcut(named name: String) {
        var components = URLComponents()
        components.scheme = "shortcuts"
        components.host = "open-shortcut"
        components.queryItems = [URLQueryItem(name: "name", value: name)]

        if let url = components.url {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Actions plist

    private func buildActions(from prompt: String, title: String) -> [[String: Any]] {
        let lower = normalized(prompt)
        var actions: [[String: Any]] = [
            action(
                "is.workflow.actions.comment",
                ["WFCommentActionText": "Créé localement par Sarah IA. Demande : \(prompt)"]
            )
        ]

        if lower.contains("demande") || lower.contains("saisie") || lower.contains("question") {
            actions.append(action(
                "is.workflow.actions.ask",
                [
                    "WFAskActionPrompt": extractQuotedText(from: prompt) ?? "Que souhaitez-vous saisir ?",
                    "WFInputType": "Text"
                ]
            ))
        }

        if lower.contains("batterie") {
            actions.append(action("is.workflow.actions.getbatterylevel", [:]))
        }

        if lower.contains("date") || lower.contains("heure") {
            actions.append(action("is.workflow.actions.date", [:]))
        }

        if lower.contains("presse papier") || lower.contains("presse-papier") || lower.contains("clipboard") {
            if lower.contains("copie") || lower.contains("mettre") {
                actions.append(action(
                    "is.workflow.actions.setclipboard",
                    ["WFText": extractQuotedText(from: prompt) ?? prompt]
                ))
            } else {
                actions.append(action("is.workflow.actions.getclipboard", [:]))
            }
        }

        if let url = extractURL(from: prompt) {
            actions.append(action("is.workflow.actions.url", ["WFURLActionURL": url]))
            actions.append(action("is.workflow.actions.openurl", [:]))
        }

        if lower.contains("notification") || lower.contains("alerte") || lower.contains("notifie") {
            actions.append(action(
                "is.workflow.actions.notification",
                [
                    "WFNotificationActionTitle": title,
                    "WFNotificationActionBody": extractQuotedText(from: prompt) ?? prompt
                ]
            ))
        }

        if lower.contains("attend") || lower.contains("pause") {
            actions.append(action("is.workflow.actions.delay", ["WFDelayTime": 1]))
        }

        if lower.contains("vibre") || lower.contains("vibration") {
            actions.append(action("is.workflow.actions.vibrate", [:]))
        }

        if lower.contains("texte") || actions.count == 1 {
            actions.append(action(
                "is.workflow.actions.gettext",
                ["WFTextActionText": extractQuotedText(from: prompt) ?? prompt]
            ))
        }

        if lower.contains("affiche") || lower.contains("montre") || actions.count == 2 {
            actions.append(action(
                "is.workflow.actions.showresult",
                ["Text": "Exécution terminée par Sarah IA"]
            ))
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

    private func normalized(_ text: String) -> String {
        text.lowercased()
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
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
        return detector.firstMatch(in: text, options: [], range: range)?.url?.absoluteString
    }

    private func extractQuotedText(from text: String) -> String? {
        for pattern in ["«([^»]+)»", "\"([^\"]+)\"", "“([^”]+)”"] {
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
        NotificationCenter.default.post(name: .sarahStartNewChat, object: nil)
        return .result()
    }
}

@available(iOS 16.0, *)
public struct CreateSarahShortcutDraftIntent: AppIntent {
    public static var title: LocalizedStringResource = "Créer un brouillon de raccourci"
    public static var description = IntentDescription(
        "Demande à Sarah de préparer localement un workflow Apple Raccourcis."
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
