import Foundation

/// Générateur local de plans Apple Shortcuts.
///
/// Apple ne fournit pas d'API publique permettant à une app tierce d'injecter
/// silencieusement une pile arbitraire d'actions dans l'éditeur Raccourcis.
/// Sarah construit donc une recette fidèle aux vrais noms de blocs, l'affiche
/// dans le chat, la copie dans le presse-papiers et ouvre un raccourci vierge.
public final class ShortcutGenerator {

    public static let shared = ShortcutGenerator()

    public struct ShortcutBlock: Identifiable, Codable, Equatable {
        public let id: String
        public let title: String
        public let subtitle: String?
        public let systemImage: String
        public let category: String
        public let parameters: [String: String]

        public init(
            id: String = UUID().uuidString,
            title: String,
            subtitle: String? = nil,
            systemImage: String,
            category: String,
            parameters: [String: String] = [:]
        ) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.systemImage = systemImage
            self.category = category
            self.parameters = parameters
        }
    }

    public struct ShortcutPlan: Codable, Equatable {
        public let title: String
        public let summary: String
        public let blocks: [ShortcutBlock]

        public init(title: String, summary: String, blocks: [ShortcutBlock]) {
            self.title = title
            self.summary = summary
            self.blocks = blocks
        }

        public var copyText: String {
            var lines = [title, summary, ""]
            for (index, block) in blocks.enumerated() {
                lines.append("\(index + 1). \(block.title)")
                if let subtitle = block.subtitle, !subtitle.isEmpty {
                    lines.append("   \(subtitle)")
                }
                for key in block.parameters.keys.sorted() {
                    if let value = block.parameters[key] {
                        lines.append("   \(key) : \(value)")
                    }
                }
            }
            return lines.joined(separator: "\n")
        }
    }

    /// Ancienne structure conservée pour les appels existants.
    public struct ShortcutSchema: Codable {
        public let id: String
        public let title: String
        public let action: String
        public let parameters: [String: String]
        public let createdAt: Date
    }

    private let markerPrefix = "[[SARAH_SHORTCUT_PLAN:"
    private let markerSuffix = "]]"

    private var shortcutsDirectory: URL {
        let fm = FileManager.default
        let urls = fm.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = (urls.first ?? fm.temporaryDirectory)
            .appendingPathComponent("Shortcuts", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private init() {}

    public func makePlan(title: String? = nil, prompt: String) -> ShortcutPlan {
        let clean = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = clean
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .lowercased()

        let proposed = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = (proposed?.isEmpty == false) ? proposed! : suggestedTitle(for: clean)

        if containsAny(normalized, [
            "transport", "metro", "rer", "bus", "tram", "train",
            "prochain passage", "prochains passages", "horaire", "horaires"
        ]) {
            return transitPlan(title: finalTitle)
        }

        if containsAny(normalized, ["meteo", "temperature", "pluie", "weather"]) {
            return weatherPlan(title: finalTitle)
        }

        if containsAny(normalized, ["alarme", "reveil", "minuteur", "timer"]) {
            return alarmPlan(title: finalTitle)
        }

        if containsAny(normalized, ["presse papier", "clipboard", "copier", "texte"]) {
            return clipboardPlan(title: finalTitle)
        }

        return genericPlan(title: finalTitle, prompt: clean)
    }

    public func marker(for plan: ShortcutPlan) -> String {
        guard let data = try? JSONEncoder().encode(plan) else { return "" }
        return markerPrefix + data.base64EncodedString() + markerSuffix
    }

    public func decodePlan(from text: String) -> ShortcutPlan? {
        guard let start = text.range(of: markerPrefix),
              let end = text.range(of: markerSuffix, range: start.upperBound..<text.endIndex) else {
            return nil
        }

        let encoded = String(text[start.upperBound..<end.lowerBound])
        guard let data = Data(base64Encoded: encoded),
              let plan = try? JSONDecoder().decode(ShortcutPlan.self, from: data) else {
            return nil
        }
        return plan
    }

    public func stripMarker(from text: String) -> String {
        guard let start = text.range(of: markerPrefix),
              let end = text.range(of: markerSuffix, range: start.upperBound..<text.endIndex) else {
            return text
        }

        var result = text
        result.removeSubrange(start.lowerBound..<end.upperBound)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var createShortcutURL: URL? {
        URL(string: "shortcuts://create-shortcut")
    }

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
            try? data.write(to: file)
        }
        return schema
    }

    private func transitPlan(title: String) -> ShortcutPlan {
        ShortcutPlan(
            title: title,
            summary: "Affiche les prochains passages d'une station. Les blocs correspondent aux actions Raccourcis ; la source transport/API doit être renseignée selon le réseau utilisé.",
            blocks: [
                block("Demander une entrée", subtitle: "Demander la station ou l'arrêt", icon: "text.cursor", category: "Entrée", parameters: ["Question": "Quelle station ou quel arrêt ?"]),
                block("Définir la variable", subtitle: "Conserver la station", icon: "variable", category: "Variable", parameters: ["Nom": "Station"]),
                block("Obtenir le contenu de l’URL", subtitle: "Interroger la source transport", icon: "network", category: "Web", parameters: ["Méthode": "GET", "URL": "Endpoint transport à configurer"]),
                block("Obtenir la valeur du dictionnaire", subtitle: "Lire les prochains départs", icon: "curlybraces", category: "Données", parameters: ["Clé": "departures / results"]),
                block("Obtenir les éléments de la liste", subtitle: "Garder les 3 prochains", icon: "list.number", category: "Liste", parameters: ["Éléments": "1 à 3"]),
                block("Répéter avec chaque élément", subtitle: "Construire une ligne par départ", icon: "repeat", category: "Contrôle"),
                block("Texte", subtitle: "Formater ligne, destination et heure", icon: "text.alignleft", category: "Texte", parameters: ["Format": "Ligne • Destination • Départ"]),
                block("Fin de la répétition", icon: "repeat.1", category: "Contrôle"),
                block("Afficher le résultat", subtitle: "Présenter les passages", icon: "rectangle.and.text.magnifyingglass", category: "Sortie")
            ]
        )
    }

    private func weatherPlan(title: String) -> ShortcutPlan {
        ShortcutPlan(
            title: title,
            summary: "Récupère la météo de la position choisie et affiche un résumé.",
            blocks: [
                block("Obtenir la position actuelle", icon: "location.fill", category: "Lieu"),
                block("Obtenir la météo actuelle", icon: "cloud.sun.fill", category: "Météo"),
                block("Obtenir les détails des conditions météo", subtitle: "Température et conditions", icon: "thermometer", category: "Météo"),
                block("Texte", subtitle: "Composer le résumé", icon: "text.alignleft", category: "Texte", parameters: ["Format": "Il fait [Température] • [Conditions]"]),
                block("Afficher le résultat", icon: "rectangle.and.text.magnifyingglass", category: "Sortie")
            ]
        )
    }

    private func alarmPlan(title: String) -> ShortcutPlan {
        ShortcutPlan(
            title: title,
            summary: "Demande une heure puis crée une alarme dans Horloge.",
            blocks: [
                block("Demander une entrée", subtitle: "Choisir l'heure", icon: "clock", category: "Entrée", parameters: ["Type": "Date et heure"]),
                block("Créer une alarme", subtitle: "Utiliser l'heure fournie", icon: "alarm.fill", category: "Horloge"),
                block("Afficher une notification", subtitle: "Confirmer la création", icon: "bell.fill", category: "Sortie")
            ]
        )
    }

    private func clipboardPlan(title: String) -> ShortcutPlan {
        ShortcutPlan(
            title: title,
            summary: "Prend le presse-papiers, traite le texte puis remet le résultat dans le presse-papiers.",
            blocks: [
                block("Obtenir le presse-papiers", icon: "doc.on.clipboard", category: "Presse-papiers"),
                block("Texte", subtitle: "Utiliser le contenu comme variable", icon: "text.alignleft", category: "Texte"),
                block("Copier dans le presse-papiers", icon: "doc.on.doc", category: "Presse-papiers"),
                block("Afficher une notification", subtitle: "Texte copié", icon: "bell.fill", category: "Sortie")
            ]
        )
    }

    private func genericPlan(title: String, prompt: String) -> ShortcutPlan {
        ShortcutPlan(
            title: title,
            summary: "Première structure générée par Raphaël à partir de ta demande.",
            blocks: [
                block("Demander une entrée", subtitle: prompt, icon: "text.cursor", category: "Entrée"),
                block("Définir la variable", subtitle: "Conserver l'entrée", icon: "variable", category: "Variable", parameters: ["Nom": "Entrée"]),
                block("Texte", subtitle: "Préparer le résultat", icon: "text.alignleft", category: "Texte"),
                block("Afficher le résultat", icon: "rectangle.and.text.magnifyingglass", category: "Sortie")
            ]
        )
    }

    private func suggestedTitle(for prompt: String) -> String {
        let normalized = prompt
            .replacingOccurrences(of: "crée", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "cree", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "raccourci", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "shortcut", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if normalized.isEmpty {
            return "Raccourci Sarah"
        }

        return String(normalized.prefix(42))
    }

    private func containsAny(_ text: String, _ values: [String]) -> Bool {
        values.contains(where: { text.contains($0) })
    }

    private func block(
        _ title: String,
        subtitle: String? = nil,
        icon: String,
        category: String,
        parameters: [String: String] = [:]
    ) -> ShortcutBlock {
        ShortcutBlock(
            title: title,
            subtitle: subtitle,
            systemImage: icon,
            category: category,
            parameters: parameters
        )
    }
}
