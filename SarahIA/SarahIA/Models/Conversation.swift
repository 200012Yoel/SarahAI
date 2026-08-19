import Foundation

/// Modèle d'une discussion sauvegardée
public struct Conversation: Identifiable, Equatable, Codable {
    public let id: UUID
    public var title: String
    public var isPinned: Bool
    public var isArchived: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var messages: [Message]
    
    public init(
        id: UUID = UUID(),
        title: String,
        isPinned: Bool = false,
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        messages: [Message] = []
    ) {
        self.id = id
        self.title = title
        self.isPinned = isPinned
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
    }
}
