import Foundation

/// Représente un message dans la conversation entre l'utilisateur et Sarah AI.
public struct Message: Identifiable, Equatable, Codable {
    public let id: UUID
    public let content: String
    public let isFromUser: Bool
    public let timestamp: Date
    public var audioDuration: TimeInterval?
    public var imageData: Data?
    public var alertEvent: AlertEvent?
    public var generatedImageURL: String?
    public var generatedMusicStyle: String?
    
    public init(
        id: UUID = UUID(),
        content: String,
        isFromUser: Bool,
        timestamp: Date = Date(),
        audioDuration: TimeInterval? = nil,
        imageData: Data? = nil,
        alertEvent: AlertEvent? = nil,
        generatedImageURL: String? = nil,
        generatedMusicStyle: String? = nil
    ) {
        self.id = id
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = timestamp
        self.audioDuration = audioDuration
        self.imageData = imageData
        self.alertEvent = alertEvent
        self.generatedImageURL = generatedImageURL
        self.generatedMusicStyle = generatedMusicStyle
    }
    
    /// Détecte si le message contient une image générée (URL Pollinations / Flux ou fichier local)
    public var detectedImageURL: String? {
        if let explicit = generatedImageURL, !explicit.isEmpty { return explicit }
        if content.contains("https://image.pollinations.ai/prompt/") {
            let parts = content.components(separatedBy: "https://image.pollinations.ai/prompt/")
            if parts.count > 1 {
                let urlPart = parts[1].components(separatedBy: .whitespacesAndNewlines).first ?? ""
                return "https://image.pollinations.ai/prompt/\(urlPart)"
            }
        }
        return nil
    }
    
    /// Détecte si le message est une composition musicale de Sarah
    public var detectedMusicStyle: String? {
        if let explicit = generatedMusicStyle, !explicit.isEmpty { return explicit }
        if content.contains("Sarah Music Engine") || content.contains("Morceau composé") || content.contains("Moteur Musical Open Source") {
            for style in ["Lo-Fi Chill", "Synthwave Électro", "Piano Classique", "Ambiance Méditation", "Épique Cinématique", "Jazz Bossa"] {
                if content.contains(style) { return style }
            }
            return "Lo-Fi Chill"
        }
        return nil
    }
    
    /// Détecte si le message est un rapport d'analyse de vision
    public var isVisionReport: Bool {
        return content.contains("Éléments identifiés") || content.contains("Texte extrait (OCR)") || content.contains("Visages détectés")
    }
    
    /// Formate l'heure du message pour l'affichage (ex: "14:32")
    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: timestamp)
    }
    
    /// Formate la date complète pour les séparateurs de conversation
    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: timestamp)
    }
}
