import Foundation

/// Moteur d'Indexation Sémantique & RAG Local pour iOS (100% Hors-Ligne) :
/// - Mémorise et indexe les thèmes et sujets clés de la discussion
/// - Permet à Sarah de faire référence avec pertinence aux sujets précédents
/// - Calcul local instantané sans serveur
public final class SemanticMemoryIndex {
    
    public static let shared = SemanticMemoryIndex()
    
    public struct MemoryItem {
        public let timestamp: Date
        public let text: String
        public let keywords: Set<String>
        public let topicType: String
    }
    
    private var indexedMemories: [MemoryItem] = []
    private let maxMemories = 60
    private let queue = DispatchQueue(label: "SarahAI.SemanticMemoryIndex", attributes: .concurrent)
    
    private let stopwords: Set<String> = [
        "le", "la", "les", "un", "une", "des", "du", "de", "d", "l", "et", "ou", "mais", "donc",
        "car", "ni", "que", "qui", "quoi", "dont", "où", "ce", "cet", "cette", "ces", "dans",
        "sur", "sous", "par", "pour", "avec", "sans", "est", "sont", "a", "ont", "je", "tu",
        "il", "elle", "nous", "vous", "ils", "elles", "mon", "ton", "son", "mes", "tes", "ses"
    ]
    
    private init() {}
    
    /// Indexe un nouvel échange dans la mémoire locale
    public func indexExchange(userText: String, assistantText: String, topicType: String = "general") {
        let keywords = extractKeywords(text: "\(userText) \(assistantText)")
        let item = MemoryItem(
            timestamp: Date(),
            text: "Utilisateur: \(userText) | Sarah: \(assistantText)",
            keywords: keywords,
            topicType: topicType
        )
        
        queue.async(flags: .barrier) {
            self.indexedMemories.append(item)
            if self.indexedMemories.count > self.maxMemories {
                self.indexedMemories.removeFirst()
            }
        }
    }
    
    /// Recherche le contexte pertinent pour une question donnée (Local RAG)
    public func findRelevantContext(query: String) -> String? {
        let queryKeywords = extractKeywords(text: query)
        guard !queryKeywords.isEmpty else { return nil }
        
        var bestMatch: String? = nil
        var bestScore = 0
        
        queue.sync {
            for item in self.indexedMemories.reversed() {
                let intersection = item.keywords.intersection(queryKeywords)
                let score = intersection.count
                if score > bestScore && score >= 2 {
                    bestScore = score
                    bestMatch = item.text
                }
            }
        }
        
        return bestMatch
    }
    
    private func extractKeywords(text: String) -> Set<String> {
        let clean = text.lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 && !stopwords.contains($0) }
        return Set(clean)
    }
}
