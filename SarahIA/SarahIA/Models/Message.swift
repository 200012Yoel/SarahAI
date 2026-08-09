import Foundation

/// Représente un message dans la conversation entre l'utilisateur et Sarah AI.
public struct Message: Identifiable, Equatable, Codable {
    public let id: UUID
    public let content: String
    public let isFromUser: Bool
    public let timestamp: Date
    public var audioDuration: TimeInterval?
    
    public init(
        id: UUID = UUID(),
        content: String,
        isFromUser: Bool,
        timestamp: Date = Date(),
        audioDuration: TimeInterval? = nil
    ) {
        self.id = id
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = timestamp
        self.audioDuration = audioDuration
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
