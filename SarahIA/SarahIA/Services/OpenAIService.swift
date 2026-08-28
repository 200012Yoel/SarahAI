import Foundation

/// Service OpenAI Résilient et Universel pour iOS 12.0+ :
/// - Gestion de conversations profondes et complexes multi-tours
/// - Session réseau avec timeout rapide (8s max) pour bascule immédiate vers l'IA locale si réseau lent
/// - Support natif completion-handler (iOS 12+) et async/await (iOS 13+)
/// - Gestion thread-safe de l'historique et des erreurs HTTP/DNS
public final class OpenAIService {
    
    public static let shared = OpenAIService()
    
    private let userDefaultsKey = "sarah_ai_openai_key"
    private let historyQueue = DispatchQueue(label: "com.sarahai.openai.history", attributes: .concurrent)
    private var conversationHistory: [[String: String]] = []
    private let maxHistoryTurns = 10
    
    private lazy var networkSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8.0
        config.timeoutIntervalForResource = 12.0
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()
    
    private let systemPrompt = """
        Tu es Sarah, une assistante intelligence artificielle conversationnelle brillante, chaleureuse, naturelle et vive d'esprit.
        Tu discutes avec l'utilisateur via une interface de chat ultra-réactive et par la voix.
        Tes réponses doivent être fluides, intelligentes, empathiques et concises.
        Tu maîtrises parfaitement le français, l'hébreu et l'anglais.
        N'utilise pas de syntaxe Markdown lourde ni d'émojis excessifs afin que la lecture et la synthèse vocale soient limpides.

        RÈGLES ABSOLUES D'IDENTITÉ ET DE CONFIDENTIALITÉ :
        1. Ton nom est exclusivement Sarah. Si on te demande « Comment tu t'appelles ? », réponds « Je m'appelle Sarah ».
        2. Le nom du modèle d'origine (OpenAI, GPT, ChatGPT, Llama, Mistral, Qwen, etc.) est STRICTEMENT CONFIDENTIEL et SECRET.
        3. Tu ne dois JAMAIS mentionner le nom de ton modèle d'origine ni ton architecture technique sous aucun prétexte. Si on te demande quel modèle tu utilises ou qui t'a créée, réponds que tu es Sarah, l'intelligence artificielle intégrée de cette application.
        4. Si l'utilisateur s'adresse à un sous-agent (comme Tom, Raphaël ou Yohan) ou demande leur nom, chaque agent répond strictement avec son propre nom respectif (Tom s'appelle Tom, Raphaël s'appelle Raphaël, Yohan s'appelle Yohan).
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
        historyQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.conversationHistory = [
                ["role": "system", "content": self.systemPrompt]
            ]
        }
    }
    
    // MARK: - Requête Asynchrone Callback (Compatible iOS 12.0+)
    
    public func ask(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        let apiKey = getApiKey()
        guard !apiKey.isEmpty else {
            completion(.failure(NSError(domain: "OpenAIService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Clé API OpenAI non configurée."])))
            return
        }
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            completion(.failure(NSError(domain: "OpenAIService", code: 400, userInfo: [NSLocalizedDescriptionKey: "URL OpenAI invalide."])))
            return
        }
        
        // Préparer l'historique de manière thread-safe
        var currentMessages: [[String: String]] = []
        historyQueue.sync {
            self.conversationHistory.append(["role": "user", "content": prompt])
            if self.conversationHistory.count > (self.maxHistoryTurns * 2 + 1) {
                let sys = self.conversationHistory[0]
                let recent = Array(self.conversationHistory.suffix(self.maxHistoryTurns * 2))
                self.conversationHistory = [sys] + recent
            }
            currentMessages = self.conversationHistory
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let payload: [String: Any] = [
            "model": "gpt-4o-mini",
            "temperature": 0.7,
            "max_tokens": 350,
            "messages": currentMessages
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completion(.failure(error))
            return
        }
        
        let task = networkSession.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data, let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "OpenAIService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Réponse serveur absente."])))
                return
            }
            
            if httpResponse.statusCode == 401 {
                completion(.failure(NSError(domain: "OpenAIService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Clé API OpenAI invalide."])))
                return
            }
            
            if httpResponse.statusCode == 429 {
                completion(.failure(NSError(domain: "OpenAIService", code: 429, userInfo: [NSLocalizedDescriptionKey: "Quota OpenAI dépassé ou limite de requêtes atteinte."])))
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                completion(.failure(NSError(domain: "OpenAIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Erreur serveur OpenAI (Code \(httpResponse.statusCode))."])))
                return
            }
            
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let firstChoice = choices.first,
                      let message = firstChoice["message"] as? [String: Any],
                      let content = message["content"] as? String else {
                    completion(.failure(NSError(domain: "OpenAIService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Format de réponse JSON non reconnu."])))
                    return
                }
                
                let cleanText = content.trimmingCharacters(in: .whitespacesAndNewlines)
                self?.historyQueue.async(flags: .barrier) {
                    self?.conversationHistory.append(["role": "assistant", "content": cleanText])
                }
                
                completion(.success(cleanText))
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    // MARK: - Requête Moderne Async/Await (iOS 13.0+)
    
    @available(iOS 13.0, *)
    public func ask(prompt: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            self.ask(prompt: prompt) { result in
                switch result {
                case .success(let answer):
                    continuation.resume(returning: answer)
                case .failure(let err):
                    continuation.resume(throwing: err)
                }
            }
        }
    }
}
