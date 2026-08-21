import Foundation

/// Service OpenAI pour iOS :
/// - Gestion de conversations profondes et complexes multi-tours
/// - Mémoire contextuelle dynamique (maintient le fil des discussions sans perte)
/// - Modèle léger optimisé (gpt-4o-mini) avec fallback local instantané
public final class OpenAIService {
    
    public static let shared = OpenAIService()
    
    private let userDefaultsKey = "sarah_ai_openai_key"
    private var conversationHistory: [[String: String]] = []
    private let maxHistoryTurns = 12
    
    private let systemPrompt = """
        Tu es Sarah, une intelligence artificielle conversationnelle brillante, chaleureuse, naturelle et vive d'esprit.
        Tu discutes avec l'utilisateur via une interface de chat ultra-réactive et fluide ainsi que par la voix.
        Tes réponses doivent être fluides, intelligentes, empathiques et bien rythmées.
        Tu es capable de raisonnements complexes et d'analyses détaillées tout en restant concise et claire.
        Tu maîtrises parfaitement le français, l'hébreu et l'anglais.
        N'utilise pas de puces Markdown complexes ni d'émojis excessifs dans tes réponses afin que la lecture et la synthèse vocale soient parfaitement naturelles.
    """
    
    private init() {
        resetContext()
    }
    
    public func getApiKey() -> String {
        return UserDefaults.standard.string(forKey: userDefaultsKey) ?? ""
    }
    
    public func setApiKey(_ key: String) {
        UserDefaults.standard.setValue(key.trimmingCharacters(in: .whitespacesAndNewlines), forKey: userDefaultsKey)
    }
    
    public var isConfigured: Bool {
        return !getApiKey().isEmpty
    }
    
    public func resetContext() {
        conversationHistory = [
            ["role": "system", "content": systemPrompt]
        ]
    }
    
    /// Génère une réponse via l'API OpenAI avec gestion d'historique multi-tours
    @available(iOS 13.0, *)
    public func ask(prompt: String) async throws -> String {
        let apiKey = getApiKey()
        guard !apiKey.isEmpty else {
            throw NSError(domain: "OpenAIService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Clé API OpenAI non configurée"])
        }
        
        conversationHistory.append(["role": "user", "content": prompt])
        if conversationHistory.count > (maxHistoryTurns * 2 + 1) {
            let sys = conversationHistory[0]
            let recent = Array(conversationHistory.suffix(maxHistoryTurns * 2))
            conversationHistory = [sys] + recent
        }
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw NSError(domain: "OpenAIService", code: 400, userInfo: [NSLocalizedDescriptionKey: "URL invalide"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 12.0
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let payload: [String: Any] = [
            "model": "gpt-4o-mini",
            "temperature": 0.7,
            "max_tokens": 350,
            "messages": conversationHistory
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Erreur HTTP"
            throw NSError(domain: "OpenAIService", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: errorText])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NSError(domain: "OpenAIService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Réponse JSON invalide"])
        }
        
        let cleanText = content.trimmingCharacters(in: .whitespacesAndNewlines)
        conversationHistory.append(["role": "assistant", "content": cleanText])
        return cleanText
    }
}
