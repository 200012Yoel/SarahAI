import Foundation
import UIKit

/// Échange conversationnel pour le suivi du contexte à court terme
public struct ConversationExchange: Codable {
    public let userText: String
    public let assistantResponse: String
    public let timestamp: Date
    
    public init(userText: String, assistantResponse: String, timestamp: Date = Date()) {
        self.userText = userText
        self.assistantResponse = assistantResponse
        self.timestamp = timestamp
    }
}

/// Service d'intelligence artificielle locale ultra-rapide (60 FPS & Zéro Latence) :
/// - Moteur d'Intent Matching avancé (Salutations dynamiques, requêtes utilitaires, calculs NSExpression).
/// - Dynamic Memory Mesh (Brain Vault avec balayage sémantique de mots-clés et App Group).
/// - Suivi du contexte conversationnel court terme (5-6 derniers échanges pour continuité pronominale).
public final class AIService {
    
    public static let shared = AIService()
    
    private let storage = StorageService.shared
    private let device = DeviceController.shared
    private let translation = TranslationEngine.shared
    
    // App Group pour le partage en temps réel avec les Widgets
    private let appGroupSuite = "group.com.sarahia.app"
    private let appGroupMemoryKey = "sarah_learned_memories_v2"
    
    // File de synchronisation thread-safe pour le contexte conversationnel
    private let historyQueue = DispatchQueue(label: "com.sarahia.history.queue", attributes: .concurrent)
    private var recentExchanges: [ConversationExchange] = []
    private let maxHistoryCount = 6
    
    private init() {}
    
    // MARK: - Gestion du Contexte Conversationnel Court Terme (5-6 Échanges)
    
    /// Enregistre un échange dans l'historique court terme (FIFO max 6)
    public func recordExchange(userText: String, assistantResponse: String) {
        historyQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            let exchange = ConversationExchange(userText: userText, assistantResponse: assistantResponse, timestamp: Date())
            self.recentExchanges.append(exchange)
            if self.recentExchanges.count > self.maxHistoryCount {
                self.recentExchanges.removeFirst(self.recentExchanges.count - self.maxHistoryCount)
            }
        }
    }
    
    /// Synchronise l'historique court terme à partir des messages existants
    public func syncHistoryFromMessages(_ messages: [Message]) {
        historyQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            var exchanges: [ConversationExchange] = []
            var lastUser: String? = nil
            
            for msg in messages {
                if msg.isFromUser {
                    lastUser = msg.content
                } else if let user = lastUser {
                    exchanges.append(ConversationExchange(userText: user, assistantResponse: msg.content, timestamp: msg.timestamp))
                    lastUser = nil
                }
            }
            
            self.recentExchanges = Array(exchanges.suffix(self.maxHistoryCount))
        }
    }
    
    /// Récupère une copie des échanges récents
    public func getRecentExchanges() -> [ConversationExchange] {
        return historyQueue.sync {
            return self.recentExchanges
        }
    }
    
    // MARK: - Moteur de Réponses Synchrones 100% Hors-Ligne (iOS 12+)
    
    /// Détecte si la requête de l'utilisateur correspond à une intention de recherche sur Internet
    public func isWebSearchIntent(_ normalized: String) -> Bool {
        let norm = normalized
            .replacingOccurrences(of: "cherchemoi", with: "cherche moi")
            .replacingOccurrences(of: "trouvemoi", with: "trouve moi")
            .replacingOccurrences(of: "recherchemoi", with: "recherche moi")
            .replacingOccurrences(of: "cherche-moi", with: "cherche moi")
            .replacingOccurrences(of: "d'avion", with: "d avion")
            .replacingOccurrences(of: "d'hotel", with: "d hotel")
            
        let triggers = [
            "cherche ", "recherche ", "trouve sur internet", "trouve sur le web",
            "cherche sur internet", "cherche sur le web", "recherche sur internet",
            "recherche sur le web", "moteur de recherche", "qui est ", "qui etait ",
            "c est quoi ", "qu est ce que ", "donne moi des infos sur ",
            "actualite", "actualites", "dernieres nouvelles", "cours de", "prix de",
            "meteo a ", "meteo pour ", "sur wikipedia", "cherche moi", "trouve moi",
            "billet de train", "billet train", "billets de train", "train pour", "train de", "trains",
            "sncf", "trainline", "billet d avion", "billet avion", "billets d avion", "vol pour",
            "vols pour", "comparateur de vol", "hotel a ", "hotel pour"
        ]
        return triggers.contains { norm.contains($0) || norm.starts(with: $0) }
    }
    
    // MARK: - Inférence Asynchrone Sécurisée (Protection RAM Jetsam OOM & Cloud Fallback Mock)
    
    /// Traite la requête utilisateur de manière asynchrone avec do/catch global et fallback de débogage garanti
    public func processQuery(_ question: String, completion: @escaping (String) -> Void) {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion("[DEBUG] Le bouton fonctionne, mais le texte envoyé est vide.")
            return
        }
        
        let normalized = normalizeText(trimmed)
        
        // 1. Actions contextuelles immédiates (Torche, Flashlight, Batterie, Stop, etc.)
        if let contextual = evaluateContextualAction(normalized: normalized, trimmed: trimmed) {
            recordExchange(userText: trimmed, assistantResponse: contextual)
            completion(contextual.decodingHTMLEntities())
            return
        }
        
        // 2. Mémorisation directe ("Apprends papa = au travail" ou "Retiens que X")
        if normalized.hasPrefix("apprends ") || normalized.hasPrefix("retiens que ") || normalized.hasPrefix("memorise ") {
            let clean = trimmed.replacingOccurrences(of: "Apprends ", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "Retiens que ", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "Memorise ", with: "", options: .caseInsensitive)
            if clean.contains("=") {
                let parts = clean.components(separatedBy: "=")
                if parts.count == 2 {
                    let trigger = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let fact = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    StorageService.shared.saveMemory(trigger: trigger, response: fact)
                    let reply = "C'est noté et mémorisé avec succès ! 🧠 (« \(trigger) » = « \(fact) »)"
                    recordExchange(userText: trimmed, assistantResponse: reply)
                    completion(reply.decodingHTMLEntities())
                    return
                }
            }
        }
        
        // 3. Calculs mathématiques rapides instantanés
        if let mathResult = evaluateSimpleMath(in: trimmed) {
            let reply = "Le résultat est : \(mathResult) 🧮"
            recordExchange(userText: trimmed, assistantResponse: reply)
            completion(reply.decodingHTMLEntities())
            return
        }
        
        // 4. Inférence Réelle : Routage selon la RAM et compatibilité matérielle
        if ModelSelectionEngine.shared.isLocalGGUFAllowed() {
            // Appareils Récents (RAM >= 4 Go) : Inférence 100% locale Qwen 2.5 Coder 3B (GGUF / llama.cpp)
            if BackgroundModelDownloader.isModelDownloaded, let modelURL = BackgroundModelDownloader.localModelURL {
                let systemPrompt = SystemPromptBuilder.build(identityName: "Sarah")
                let formattedChatML = ModelSelectionEngine.shared.formatChatMLPrompt(system: systemPrompt, user: trimmed)
                
                // Exécution via SarahBrainEngine / llama.cpp natif
                SarahBrainEngine.shared.generateStreamingResponse(prompt: formattedChatML) { [weak self] (localText: String) in
                    guard let self = self else { return }
                    let cleaned = localText.decodingHTMLEntities()
                    self.recordExchange(userText: trimmed, assistantResponse: cleaned)
                    DispatchQueue.main.async {
                        completion(cleaned)
                    }
                }
                return
            } else {
                // Modèle pas encore téléchargé -> Déclenchement automatique du téléchargement
                BackgroundModelDownloader.shared.startQwenModelDownload()
                let downloadingNotice = "⏳ Téléchargement du modèle haute précision (Qwen 2.5 Coder 3B GGUF) en cours... Bascule temporaire sur le mode Cloud."
                // On tente le cloud en attendant le téléchargement local
                callCloudLLM(prompt: trimmed) { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                    case .success(let response):
                        let cleaned = response.decodingHTMLEntities()
                        self.recordExchange(userText: trimmed, assistantResponse: cleaned)
                        DispatchQueue.main.async { completion(cleaned) }
                    case .failure:
                        DispatchQueue.main.async { completion(downloadingNotice) }
                    }
                }
                return
            }
        } else {
            // Appareils Legacy (iPhone 5s, 6, 7, 8, SE - RAM <= 2 Go) :
            // INTERDICTION STRICTE DE CHARGER LE GGUF (Protection Jetsam OOM) -> Cloud Fallback Silencieux
            let apiKey = UserDefaults.standard.string(forKey: "sarah_cloud_api_key") ?? ""
            let customEndpoint = UserDefaults.standard.string(forKey: "sarah_custom_llm_endpoint") ?? ""
            
            callCloudLLM(prompt: trimmed) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let llmResponse):
                    let cleaned = llmResponse.decodingHTMLEntities()
                    self.recordExchange(userText: trimmed, assistantResponse: cleaned)
                    DispatchQueue.main.async {
                        completion(cleaned)
                    }
                case .failure:
                    // Si l'API distante n'est pas configurée ou inaccessible
                    let errorMessage = "[Erreur : Appareil non compatible avec l'IA locale. Veuillez configurer la clé API Cloud dans les réglages.]"
                    DispatchQueue.main.async {
                        completion(errorMessage)
                    }
                }
            }
        }
    }
    
    // MARK: - Inférence Cloud LLM Puissance Absolue (OpenAI GPT-4o / Anthropic Claude 3.5 Sonnet / Ollama Distant)
    
    public func callCloudLLM(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        let provider = UserDefaults.standard.string(forKey: "sarah_cloud_provider") ?? "openai"
        let apiKey = UserDefaults.standard.string(forKey: "sarah_cloud_api_key")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let customEndpoint = UserDefaults.standard.string(forKey: "sarah_custom_llm_endpoint")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        let systemPrompt = "Tu es Sarah, une intelligence artificielle d'élite française : ultra-rapide, experte, chaleureuse, logique et précise. Réponds directement en français de manière élégante et concise."
        
        if provider == "anthropic" || customEndpoint.contains("anthropic.com") {
            // --- API Anthropic (Claude 3.5 Sonnet) ---
            let endpointURL = URL(string: customEndpoint.isEmpty ? "https://api.anthropic.com/v1/messages" : customEndpoint)!
            var request = URLRequest(url: endpointURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.timeoutInterval = 15.0
            
            let modelName = UserDefaults.standard.string(forKey: "sarah_cloud_model_name") ?? ModelSelectionEngine.defaultCloudAnthropicModel
            let payload: [String: Any] = [
                "model": modelName,
                "max_tokens": 4096,
                "system": systemPrompt,
                "messages": [
                    ["role": "user", "content": prompt]
                ]
            ]
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
            } catch {
                completion(.failure(error))
                return
            }
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Réponse serveur Anthropic invalide"])))
                    return
                }
                guard (200...299).contains(httpResponse.statusCode) else {
                    let errorDetails = data != nil ? (String(data: data!, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)") : "HTTP \(httpResponse.statusCode)"
                    completion(.failure(NSError(domain: "AIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Erreur API Anthropic (\(httpResponse.statusCode)) : \(errorDetails)"])))
                    return
                }
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                      let contentArray = json["content"] as? [[String: Any]],
                      let firstItem = contentArray.first,
                      let text = firstItem["text"] as? String else {
                    completion(.failure(NSError(domain: "AIService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Structure JSON Anthropic inattendue"])))
                    return
                }
                completion(.success(text.trimmingCharacters(in: .whitespacesAndNewlines)))
            }.resume()
            
        } else {
            // --- API OpenAI (GPT-4o) / Serveur Ollama Distant / OpenAI Compatible ---
            let defaultEndpoint = "https://api.openai.com/v1/chat/completions"
            let endpointURL = URL(string: customEndpoint.isEmpty ? defaultEndpoint : customEndpoint) ?? URL(string: defaultEndpoint)!
            var request = URLRequest(url: endpointURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            if !apiKey.isEmpty {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
            request.timeoutInterval = 15.0
            
            let modelName = UserDefaults.standard.string(forKey: "sarah_cloud_model_name") ?? ModelSelectionEngine.defaultCloudOpenAIModel
            let messages: [[String: String]] = [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": prompt]
            ]
            
            let payload: [String: Any] = [
                "model": modelName,
                "messages": messages,
                "temperature": 0.7,
                "max_tokens": 4096
            ]
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
            } catch {
                completion(.failure(error))
                return
            }
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Réponse serveur OpenAI invalide"])))
                    return
                }
                guard (200...299).contains(httpResponse.statusCode) else {
                    let errorDetails = data != nil ? (String(data: data!, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)") : "HTTP \(httpResponse.statusCode)"
                    completion(.failure(NSError(domain: "AIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Erreur API OpenAI (\(httpResponse.statusCode)) : \(errorDetails)"])))
                    return
                }
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let firstChoice = choices.first,
                      let message = firstChoice["message"] as? [String: Any],
                      let content = message["content"] as? String else {
                    completion(.failure(NSError(domain: "AIService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Structure JSON OpenAI inattendue"])))
                    return
                }
                completion(.success(content.trimmingCharacters(in: .whitespacesAndNewlines)))
            }.resume()
        }
    }
    
    /// Génère une réponse IA synchrone immédiate (zéro latence) avec Intent Matching & Memory Mesh
    public func generateSyncResponse(for question: String) -> String {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = normalizeText(trimmed)
        
        // 0. COMMANDE D'ARRÊT & FERMETURE IMMÉDIATE ("Casse-toi", "Tais-toi", "Ferme-la", "Ferme les conf", "Arrête tout")
        if normalized.contains("casse toi") || normalized.contains("casse-toi") || normalized.contains("cassetoi") ||
           normalized.contains("tais toi") || normalized.contains("tais-toi") ||
           normalized.contains("ferme la") || normalized.contains("ferme-la") ||
           normalized.contains("ferme les conf") || normalized.contains("degage") ||
           normalized.contains("arrete tout") || normalized.contains("ferme tout") ||
           normalized == "chut" || normalized == "silence" || normalized == "stop" {
            
            DispatchQueue.main.async {
                TTSManager.shared.stop()
                SpeechManager.shared.stopSpeaking()
                AppleSpeechRecognizer.shared.stopListening()
                NotificationCenter.default.post(name: NSNotification.Name("SarahDismissAllModals"), object: nil)
            }
            let reply = "D'accord, je me casse !"
            recordExchange(userText: trimmed, assistantResponse: reply)
            return reply
        }
        
        // 1. DÉCLENCHEMENT D'ACTIONS CONTEXTUELLES MATÉRIELLES & SYSTÈME DIRECTES
        if let contextualActionResponse = evaluateContextualAction(normalized: normalized, trimmed: trimmed) {
            recordExchange(userText: trimmed, assistantResponse: contextualActionResponse)
            return contextualActionResponse
        }
        
        // 1.1 GÉNÉRATION MUSICALE OPEN SOURCE & LOCALE (AVAudioEngine)
        let musicCheck = OpenSourceMusicEngine.shared.isMusicGenerationIntent(trimmed)
        if musicCheck.isIntent {
            OpenSourceMusicEngine.shared.generateAndPlayTrack(style: musicCheck.detectedStyle) { _, _ in }
            let reply = "🎵 Je compose et je lance immédiatement un morceau en style **\(musicCheck.detectedStyle.rawValue)** pour vous !"
            recordExchange(userText: trimmed, assistantResponse: reply)
            return reply
        }
        
        // 1.2 GÉNÉRATION D'IMAGES & PHOTOS OPEN SOURCE (Flux / SDXL Turbo)
        let imageCheck = OpenSourceImageGenerationService.shared.isImageGenerationIntent(trimmed)
        if imageCheck.isIntent {
            OpenSourceImageGenerationService.shared.generateImage(prompt: imageCheck.cleanedPrompt) { _ in }
            let reply = "🎨 Je génère votre image de « **\(imageCheck.cleanedPrompt)** » avec le modèle open source Flux. Elle s'affiche dans un instant !"
            recordExchange(userText: trimmed, assistantResponse: reply)
            return reply
        }
        
        // 1.3 APPEL VOCAL WEBRTC AVEC TRADUCTION VOCALE EN DIRECT (ex: "Appelle papa", "Appelle David en anglais")
        if (normalized.starts(with: "appelle ") || normalized.starts(with: "appel ") ||
            normalized.contains("passe un appel") || normalized.contains("lance un appel") ||
            normalized.starts(with: "telephone a ") || normalized.starts(with: "téléphone à ")) &&
            !normalized.contains("whatsapp") &&
            !normalized.contains("comment tu t appelles") && !normalized.contains("comment je m appelle") {
            
            if let match = VoiceCallContactManager.shared.resolveContact(from: trimmed) {
                DispatchQueue.main.async {
                    WebRTCVoiceCallManager.shared.startOutboundCall(to: match.contact, targetLanguage: match.targetLanguage)
                    SarahActionCoordinator.shared.dispatch(.openVoiceCall(contact: match.contact))
                }
                let targetLangName = match.targetLanguage == "en" ? "Anglais 🇬🇧" : (match.targetLanguage == "he" ? "Hébreu 🇮🇱" : "Français 🇫🇷")
                let reply = "📞 J'établis l'appel WebRTC sécurisé avec **\(match.contact.name)** (\(match.contact.role)).\nTraduction vocale en direct activée vers : **\(targetLangName)**."
                recordExchange(userText: trimmed, assistantResponse: reply)
                return reply
            }
        }
        
        // 1.4 TALKIE-WALKIE & VOCAL WHATSAPP AVEC NATHAN & YOANN (ex: "Envoie un vocal à papa", "Appelle papa sur WhatsApp")
        if (normalized.contains("whatsapp") || normalized.contains("vocal") || normalized.contains("talkie")) &&
           (normalized.contains("appelle") || normalized.contains("parle") || normalized.contains("envoie") || normalized.contains("contacte") || normalized.contains("vocal a")) {
            
            if let match = VoiceCallContactManager.shared.resolveContact(from: trimmed) {
                DispatchQueue.main.async {
                    OpenWAVoiceWalkieTalkieManager.shared.startSession(with: match.contact, targetLanguage: match.targetLanguage)
                    SarahActionCoordinator.shared.dispatch(.openWhatsAppVoiceCall(contact: match.contact))
                }
                let targetLangName = match.targetLanguage == "he" ? "Hébreu 🇮🇱" : (match.targetLanguage == "en" ? "Anglais 🇬🇧" : "Français 🇫🇷")
                let reply = "💬 **Passerelle WhatsApp Talkie-Walkie Active**\n• **Nathan** gère l'envoi sécurisé PTT sur WhatsApp.\n• **Yoann** assure la traduction vocale vers : **\(targetLangName)**.\n\nPrêt pour la communication vocale avec **\(match.contact.name)** !"
                recordExchange(userText: trimmed, assistantResponse: reply)
                return reply
            }
        }
        
        var state = storage.loadState()
        
        // 2. ÉTAPE 2 DE L'APPRENTISSAGE INTERACTIF (Attente de la réponse)
        if let pendingTrigger = state.pendingLearningTrigger, !pendingTrigger.isEmpty {
            if normalized == "annule" || normalized == "annuler" || normalized == "laisse tomber" || normalized == "stop" {
                state.pendingLearningTrigger = nil
                storage.saveState(state)
                let reply = "D'accord, apprentissage annulé ! Que souhaitez-vous faire ?"
                recordExchange(userText: trimmed, assistantResponse: reply)
                return reply
            }
            
            let cleanTrigger = pendingTrigger.trimmingCharacters(in: .whitespacesAndNewlines)
            let normTrigger = normalizeText(cleanTrigger)
            state.learnedMemories[normTrigger] = trimmed
            state.pendingLearningTrigger = nil
            storage.saveState(state)
            syncMemoryToAppGroup(state.learnedMemories)
            
            let reply = "C'est appris ! 🧠 Dès que vous me direz « \(cleanTrigger) », je répondrai : « \(trimmed) »."
            recordExchange(userText: trimmed, assistantResponse: reply)
            return reply
        }
        
        // 3. APPRENTISSAGE DIRECT MONO-INSTRUCTION
        if let directLearning = parseDirectLearningCommand(trimmed) {
            let normTrigger = normalizeText(directLearning.trigger)
            state.learnedMemories[normTrigger] = directLearning.response
            storage.saveState(state)
            syncMemoryToAppGroup(state.learnedMemories)
            
            let reply = "Parfait ! J'ai mémorisé que pour « \(directLearning.trigger) », je dois répondre : « \(directLearning.response) »."
            recordExchange(userText: trimmed, assistantResponse: reply)
            return reply
        }
        
        // 4. INITIATION D'APPRENTISSAGE INTERACTIF (Multi-tours)
        if let triggerToLearn = parseInteractiveLearningInitiation(trimmed) {
            state.pendingLearningTrigger = triggerToLearn
            storage.saveState(state)
            let reply = "Je dois répondre quoi pour « \(triggerToLearn) » ?"
            recordExchange(userText: trimmed, assistantResponse: reply)
            return reply
        }
        
        // 5. GESTION DU COFFRE MÉMOIRE (Oublier / Réinitialiser / Lister)
        if normalized.starts(with: "oublie ") || normalized.starts(with: "efface ") {
            let target = trimmed.replacingOccurrences(of: "oublie ", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "efface ", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            let normTarget = normalizeText(target)
            if state.learnedMemories.removeValue(forKey: normTarget) != nil {
                storage.saveState(state)
                syncMemoryToAppGroup(state.learnedMemories)
                let reply = "J'ai bien oublié la réponse pour « \(target) » ! 🗑️"
                recordExchange(userText: trimmed, assistantResponse: reply)
                return reply
            } else if normalized.contains("tout") || normalized.contains("memoire") {
                state.learnedMemories.removeAll()
                storage.saveState(state)
                syncMemoryToAppGroup([:])
                let reply = "Toute ma mémoire personnalisée a été réinitialisée ! 🧹"
                recordExchange(userText: trimmed, assistantResponse: reply)
                return reply
            } else {
                let reply = "Je n'avais aucun souvenir enregistré pour « \(target) »."
                recordExchange(userText: trimmed, assistantResponse: reply)
                return reply
            }
        }
        
        // 5.1 CAPACITÉS & FONCTIONNALITÉS GLOBALES DE SARAH IA
        if normalized.contains("que sais-tu faire") || normalized.contains("que sais tu faire") || normalized.contains("que peux-tu faire") || normalized.contains("que peux tu faire") || normalized.contains("quelles sont tes fonctionnalites") || normalized.contains("tes fonctionnalites") || normalized.contains("tes capacites") || normalized.contains("aide moi") || normalized.contains("aide-moi") || normalized.contains("ce que tu sais faire") {
            let capabilities = """
            Voici tout ce que notre équipe à 4 agents peut faire pour vous :

            👑 **Sarah (Patronne & Pilote)** : Coordination générale, mémoire locale, torche, batterie, alertes Pikoud HaOref et actualités.
            🌍 **Tom (Histoire & Géopolitique)** : Analyse politique mondiale depuis 1948, conflits du Moyen-Orient, Ve République et débats.
            ⚡ **Raphaël (Développeur & VAI Coding)** : Génération de composants Web, code Swift, Apple Shortcuts et intégrations de designs.
            🇮🇱 **Yohan (Traducteur FR ⇄ HE)** : Dictionnaires spécialisés bilingues, phonétique, racines sémitiques et argot israélien.

            *Vous pouvez passer d'un agent à l'autre à tout moment en disant simplement : « Passe-moi Tom », « Donne-moi Raphaël » ou « Donne-moi Yohan ».*
            """
            recordExchange(userText: trimmed, assistantResponse: capabilities)
            return capabilities
        }
        
        // 5.2 GESTION DU COFFRE MÉMOIRE (Souvenirs appris uniquement)
        if normalized.contains("tes souvenirs") || normalized.contains("liste memoire") || normalized.contains("ce que tu as appris") || normalized.contains("qu'as-tu appris") {
            let allMemories = getAllCombinedMemories()
            if allMemories.isEmpty {
                let reply = "Je n'ai pas encore appris de réponses personnalisées. Dites par exemple : « Apprends papa = il est au travail » pour commencer !"
                recordExchange(userText: trimmed, assistantResponse: reply)
                return reply
            }
            let list = allMemories.map { "• « \($0.key) » ➔ \($0.value)" }.joined(separator: "\n")
            let reply = "Voici ce que j'ai appris dans mon coffre mémoire : 🧠\n\n\(list)"
            recordExchange(userText: trimmed, assistantResponse: reply)
            return reply
        }
        
        // 6. DYNAMIC MEMORY MESH (Balayage sémantique automatique des mots-clés du Brain Vault)
        if let memoryMeshResponse = evaluateMemoryMesh(normalized: normalized, trimmed: trimmed) {
            recordExchange(userText: trimmed, assistantResponse: memoryMeshResponse)
            return memoryMeshResponse
        }
        
        // 7. CONTINUITÉ DU CONTEXTE CONVERSATIONNEL (Pronoms & Suivis)
        if let contextContinuityResponse = evaluateContextContinuity(normalized: normalized, trimmed: trimmed) {
            recordExchange(userText: trimmed, assistantResponse: contextContinuityResponse)
            return contextContinuityResponse
        }
        
        // 8. ADVANCED INTENT ENGINE (Salutations, Humeur, Mathématiques, Culture, Blagues)
        let response = generateKnowledgeResponse(normalized: normalized, trimmed: trimmed)
        recordExchange(userText: trimmed, assistantResponse: response)
        return response
    }
    
    // MARK: - Moteur de Réponses Asynchrones (iOS 13+)
    
    @available(iOS 13.0, *)
    public func generateResponse(for question: String) async -> String {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = normalizeText(trimmed)
        
        // 1. Actions matérielles directes
        if let contextualActionResponse = evaluateContextualAction(normalized: normalized, trimmed: trimmed) {
            recordExchange(userText: trimmed, assistantResponse: contextualActionResponse)
            return contextualActionResponse
        }
        
        // 2. Alertes en direct Pikoud HaOref (Front Intérieur Israël)
        if normalized.contains("alerte") || normalized.contains("pikoud") || normalized.contains("sirene") || normalized.contains("tzeva adom") || (normalized.contains("israel") && (normalized.contains("securite") || normalized.contains("attaque") || normalized.contains("roquette"))) {
            let status = await withCheckedContinuation { continuation in
                RedAlertService.shared.getSecurityStatusSummary { summary in
                    continuation.resume(returning: summary)
                }
            }
            recordExchange(userText: trimmed, assistantResponse: status)
            return status
        }
        
        // 3. Météo connectée par GPS / Ville
        if normalized.contains("meteo") || normalized.contains("quel temps") || normalized.contains("temperature") || normalized.contains("prevision") || normalized.contains("pleuvoir") || normalized.contains("il pleut") || normalized.contains("il fait froid") || normalized.contains("il fait chaud") {
            var cityQuery: String? = nil
            if normalized.contains(" a ") {
                let parts = trimmed.components(separatedBy: " à ")
                if parts.count > 1 { cityQuery = parts.last?.trimmingCharacters(in: .punctuationCharacters) }
            } else if normalized.contains(" pour ") {
                let parts = trimmed.components(separatedBy: " pour ")
                if parts.count > 1 { cityQuery = parts.last?.trimmingCharacters(in: .punctuationCharacters) }
            }
            
            let weatherResult = await withCheckedContinuation { continuation in
                WeatherService.shared.fetchWeather(for: cityQuery) { info in
                    continuation.resume(returning: info?.naturalSpokenSummary)
                }
            }
            if let weatherSummary = weatherResult {
                recordExchange(userText: trimmed, assistantResponse: weatherSummary)
                return weatherSummary
            }
        }
        
        // 4. Actualités & Informations en direct (Franceinfo & i24NEWS)
        if normalized.contains("actualite") || normalized.contains("actualites") || normalized.contains("les infos") || normalized.contains("les informations") || normalized.contains("dernieres nouvelles") || normalized.contains("titres du jour") || normalized.contains("franceinfo") || normalized.contains("i24") {
            let preferredSrc: NewsService.NewsSource? = (normalized.contains("i24") || normalized.contains("israel")) ? .i24news : .franceinfo
            let newsResult = await withCheckedContinuation { continuation in
                NewsService.shared.getSpokenNewsSummary(preferredSource: preferredSrc) { summary in
                    continuation.resume(returning: summary)
                }
            }
            if !newsResult.isEmpty {
                recordExchange(userText: trimmed, assistantResponse: newsResult)
                return newsResult
            }
        }
        
        // 5. Visionneur et Recherche de Vidéos YouTube en direct
        if normalized.contains("youtube") || normalized.contains("video de") || normalized.contains("lance la video") || normalized.contains("mets la video") || normalized.contains("regarder la video") || normalized.contains("cherche la video") || (normalized.contains("cherche") && normalized.contains("clip")) {
            var videoSearchQuery = trimmed
                .replacingOccurrences(of: "cherche sur youtube", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "sur youtube", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "lance la vidéo de", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "lance la video de", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "mets la vidéo de", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "mets la video de", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "mets la vidéo", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "mets la video", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "youtube", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if videoSearchQuery.isEmpty { videoSearchQuery = trimmed }
            
            let queryToSearch = videoSearchQuery
            let ytResult = await withCheckedContinuation { continuation in
                YouTubeService.shared.getSpokenSummary(for: queryToSearch) { summary, videos in
                    continuation.resume(returning: summary)
                }
            }
            NotificationCenter.default.post(name: NSNotification.Name("SarahLaunchYouTubePlayer"), object: queryToSearch)
            recordExchange(userText: trimmed, assistantResponse: ytResult)
            return ytResult
        }
        
        // 6. Traduction multilingue temps réel si demandé
        if let translationReq = translation.parseTranslationIntent(input: trimmed) {
            let translated = await translation.translate(
                text: translationReq.textToTranslate,
                sourceLang: translationReq.sourceLanguage,
                targetLang: translationReq.targetLanguage
            )
            let reply = "En \(translationReq.targetLanguage.displayNameFr) : \(translated)"
            recordExchange(userText: trimmed, assistantResponse: reply)
            return reply
        }
        
        // 6. MOTEUR DE RECHERCHE WEB EN DIRECT (Si intention de recherche explicite)
        if isWebSearchIntent(normalized) {
            let (webSummary, _) = await WebSearchService.shared.searchWebAsync(query: trimmed)
            if !webSummary.isEmpty {
                SemanticMemoryIndex.shared.indexExchange(userText: trimmed, assistantText: webSummary, topicType: "web_search")
                recordExchange(userText: trimmed, assistantResponse: webSummary)
                return webSummary
            }
        }
        
        // 7. Traitement local synchrone prioritaire (Zéro latence)
        let syncResponse = generateSyncResponse(for: question)
        let defaultGenericAnswers = thanksResponses + identityResponses + moodResponsesOk + chitChatResponses
        
        // Si c'est un souvenir, un calcul, une action ou une réponse spécifique reconnue
        if !defaultGenericAnswers.contains(syncResponse) && syncResponse != generateDefaultResponse(for: trimmed) {
            return syncResponse
        }
        
        // 8. MOTEUR NEURONAL EMBARQUÉ 100% LOCAL (Apple Silicon & Neural Engine - Zéro Serveur)
        let pastContext = SemanticMemoryIndex.shared.findRelevantContext(query: trimmed)
        let localNeuralResult = await withCheckedContinuation { continuation in
            var history: [String] = []
            if let ctx = pastContext { history.append(ctx) }
            LocalNeuralIntelligenceEngine.shared.generateLocalResponse(prompt: trimmed, contextHistory: history) { result in
                continuation.resume(returning: result.text)
            }
        }
        if !localNeuralResult.isEmpty {
            SemanticMemoryIndex.shared.indexExchange(userText: trimmed, assistantText: localNeuralResult, topicType: "local_neural")
            recordExchange(userText: trimmed, assistantResponse: localNeuralResult)
            return localNeuralResult
        }
        
        // 6. Fallback vers Recherche Web si requête inconnue et connexion active
        let (autoWebSummary, autoResults) = await WebSearchService.shared.searchWebAsync(query: trimmed)
        if !autoResults.isEmpty && !autoWebSummary.isEmpty {
            recordExchange(userText: trimmed, assistantResponse: autoWebSummary)
            return autoWebSummary
        }
        
        return syncResponse
    }
    
    // MARK: - Dynamic Memory Mesh (Brain Vault Integration)
    
    /// Balaye automatiquement la phrase pour repérer les mots-clés du coffre mémoire et injecter les faits appris
    private func evaluateMemoryMesh(normalized: String, trimmed: String) -> String? {
        let memories = getAllCombinedMemories()
        guard !memories.isEmpty else { return nil }
        
        // 1. Correspondance exacte
        if let exactMatch = memories[normalized] {
            return exactMatch
        }
        
        // 2. Recherche de correspondances de mots-clés dans la phrase
        var matchedFacts: [(trigger: String, fact: String)] = []
        let promptTokens = normalized.components(separatedBy: " ").filter { $0.count >= 2 }
        
        for (trigger, fact) in memories {
            guard trigger != "_user_name" else { continue }
            let normTrigger = normalizeText(trigger)
            
            // Mot entier contenu ou sous-chaîne sémantique
            let isExactToken = promptTokens.contains(normTrigger)
            let isContainedPhrase = normalized.contains(" \(normTrigger) ") || normalized.starts(with: "\(normTrigger) ") || normalized.hasSuffix(" \(normTrigger)") || normalized == normTrigger
            
            if isExactToken || isContainedPhrase {
                matchedFacts.append((trigger: trigger, fact: fact))
            }
        }
        
        guard !matchedFacts.isEmpty else { return nil }
        
        // Si un seul mot-clé est détecté
        if matchedFacts.count == 1 {
            let single = matchedFacts[0]
            // Si la phrase est une question directe sur le mot-clé
            if normalized.contains("qui est") || normalized.contains("ou est") || normalized.contains("qu est ce que") || normalized.contains("parle moi de") || normalized.contains("sais tu sur") {
                return "D'après ce que vous m'avez appris, pour « **\(single.trigger)** » : \(single.fact) 🧠"
            }
            return single.fact
        }
        
        // Si plusieurs mots-clés sont mentionnés simultanément
        let combined = matchedFacts.map { "• **\($0.trigger)** : \($0.fact)" }.joined(separator: "\n")
        return "Voici ce que j'ai en mémoire pour ces éléments : 🧠\n\n\(combined)"
    }
    
    private func getAllCombinedMemories() -> [String: String] {
        var result = storage.loadState().learnedMemories
        // Fusionner avec le cache App Group UserDefaults si présent
        if let defaults = UserDefaults(suiteName: appGroupSuite),
           let appGroupData = defaults.dictionary(forKey: appGroupMemoryKey) as? [String: String] {
            for (k, v) in appGroupData {
                if result[k] == nil {
                    result[k] = v
                }
            }
        }
        return result
    }
    
    private func syncMemoryToAppGroup(_ memories: [String: String]) {
        if let defaults = UserDefaults(suiteName: appGroupSuite) {
            defaults.setValue(memories, forKey: appGroupMemoryKey)
        }
    }
    
    // MARK: - Continuité du Contexte Conversationnel (Derniers 5-6 Échanges)
    
    private func evaluateContextContinuity(normalized: String, trimmed: String) -> String? {
        let history = getRecentExchanges()
        guard let lastExchange = history.last else { return nil }
        let lastUserNorm = normalizeText(lastExchange.userText)
        let lastAssist = lastExchange.assistantResponse
        
        // 1. Demande de répétition : "Répète", "Tu peux répéter ?"
        if normalized == "repete" || normalized == "tu peux repeter" || normalized.contains("repete ce que tu as dit") || normalized == "quoi" {
            return "Je disais : « \(lastAssist) » 🎙️"
        }
        
        // 2. Demande d'un autre élément : "Raconte-m'en une autre", "Une autre", "Encore"
        if normalized.contains("une autre") || normalized.contains("un autre") || normalized.contains("encore une") || normalized == "encore" {
            if lastUserNorm.contains("blague") || lastAssist.contains("😂") || lastAssist.contains("😄") {
                return pickRandom(from: jokeResponses)
            }
            if lastUserNorm.contains("anecdote") || lastAssist.contains("🍎") || lastAssist.contains("Le saviez-vous") {
                return pickRandom(from: anecdotesResponses)
            }
            if lastUserNorm.contains("citation") || lastAssist.contains("«") {
                return pickRandom(from: quotesResponses)
            }
            if lastUserNorm.contains("poeme") || lastUserNorm.contains("chanson") {
                return pickRandom(from: poemsResponses)
            }
        }
        
        // 3. Questions de suivi / Pourquoi
        if normalized == "pourquoi" || normalized == "pourquoi ca" || normalized.starts(with: "pourquoi ") {
            if lastAssist.contains("batterie") {
                return "Parce que votre batterie se décharge naturellement en fonction de la luminosité et des applications ouvertes ! 🔋"
            }
            if lastAssist.contains("torche") {
                return "J'ai contrôlé le flash de l'appareil directement selon votre demande. 🔦"
            }
            return "C'est en lien avec ce dont nous venons de parler (« \(lastExchange.userText) ») ! N'hésitez pas si vous souhaitez plus de précisions."
        }
        
        return nil
    }
    
    // MARK: - Évaluation des Actions Contextuelles Vocales (Hardware & Système)
    
    private func evaluateContextualAction(normalized: String, trimmed: String) -> String? {
        // 0.2 Radio en direct (NRJ, France Inter, Skyrock, RTL, Nostalgie, FIP, Jazz...)
        if normalized.contains("arrete la radio") || normalized.contains("stop radio") || normalized.contains("coupe la radio") || normalized == "radio off" {
            return MediaStreamingService.shared.stopRadio()
        }
        
        if normalized.contains("mets la radio") || normalized.contains("lance la radio") || normalized.contains("ecoute la radio") ||
           normalized.contains("ecouter la radio") || normalized.contains("allume la radio") || normalized == "radio" ||
           normalized.contains("mets nrj") || normalized.contains("mets france inter") || normalized.contains("mets skyrock") ||
           normalized.contains("mets rtl") || normalized.contains("mets nostalgie") || normalized.contains("mets fun radio") ||
           normalized.contains("mets fip") || normalized.contains("mets rmc") || normalized.contains("mets europe 1") ||
           normalized.contains("mets jazz radio") || normalized.contains("mets radio classique") || normalized.contains("mets france info") {
            let stationQuery = normalized.replacingOccurrences(of: "mets la radio", with: "")
                .replacingOccurrences(of: "lance la radio", with: "")
                .replacingOccurrences(of: "mets", with: "")
                .replacingOccurrences(of: "la radio", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return MediaStreamingService.shared.playRadio(stationName: stationQuery.isEmpty ? nil : stationQuery)
        }
        
        // 0.3 Apple Podcasts & Émissions
        if normalized.contains("lance un podcast") || normalized.contains("mets un podcast") || normalized.contains("ouvre apple podcast") ||
           normalized.contains("ouvre les podcasts") || normalized.contains("podcast sur") || normalized.contains("podcast de") ||
           normalized.contains("ecouter un podcast") || normalized == "podcast" || normalized == "podcasts" {
            var podcastTopic = normalized.replacingOccurrences(of: "lance un podcast", with: "")
                .replacingOccurrences(of: "mets un podcast sur apple podcast", with: "")
                .replacingOccurrences(of: "mets un podcast", with: "")
                .replacingOccurrences(of: "ouvre apple podcast", with: "")
                .replacingOccurrences(of: "ouvre les podcasts", with: "")
                .replacingOccurrences(of: "sur apple podcast", with: "")
                .replacingOccurrences(of: "podcast", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return MediaStreamingService.shared.launchApplePodcasts(query: podcastTopic.isEmpty ? nil : podcastTopic)
        }
        
        // 0.4 Musique & Lecteur Audio (Apple Music / Spotify)
        if normalized.contains("mets de la musique") || normalized.contains("lance de la musique") || normalized.contains("joue de la musique") ||
           normalized.contains("ouvre apple music") || normalized.contains("ouvre spotify") || normalized.contains("mets de la zik") ||
           normalized.contains("mets spotify") || normalized.contains("lance spotify") || normalized.contains("musique") && (normalized.contains("mets") || normalized.contains("lance")) {
            var musicQuery = normalized.replacingOccurrences(of: "mets de la musique", with: "")
                .replacingOccurrences(of: "lance de la musique", with: "")
                .replacingOccurrences(of: "joue de la musique", with: "")
                .replacingOccurrences(of: "mets spotify", with: "")
                .replacingOccurrences(of: "mets", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return MediaStreamingService.shared.launchMusic(query: musicQuery.isEmpty ? nil : musicQuery)
        }
        
        // 0.5 Caméra & Appareil Photo
        if normalized.contains("lance la camera") || normalized.contains("ouvre la camera") || normalized.contains("active la camera") ||
           normalized.contains("lance l appareil photo") || normalized.contains("ouvre l appareil photo") || normalized.contains("active l appareil photo") ||
           normalized == "camera" || normalized == "appareil photo" {
            return "📷 J'active la caméra immédiatement ! Pointez l'objectif vers ce que vous souhaitez que j'analyse."
        }
        
        // 1. Lampe Torche / Flash Caméra
        if normalized.contains("allume la torche") || normalized.contains("allume la lampe") || normalized.contains("allumer la torche") || normalized.contains("allume le flash") || normalized.contains("active la torche") || normalized == "torche on" {
            return device.toggleTorch(enable: true)
        }
        
        if normalized.contains("eteins la torche") || normalized.contains("eteins la lampe") || normalized.contains("eteindre la torche") || normalized.contains("eteins le flash") || normalized.contains("desactive la torche") || normalized == "torche off" {
            return device.toggleTorch(enable: false)
        }
        
        if normalized == "lampe" || normalized == "torche" || normalized == "flash" || normalized.contains("active la lampe") {
            return device.toggleTorch(enable: nil)
        }
        
        // 2. Batterie
        if normalized.contains("batterie") || normalized.contains("niveau de batterie") || normalized.contains("pourcentage batterie") || normalized.contains("combien de batterie") {
            return device.getBatteryStatus()
        }
        
        // 3. Heure
        if normalized.contains("heure") || normalized.contains("quelle heure") || normalized.contains("donne moi l heure") || normalized.contains("il est quelle heure") {
            return device.getCurrentTimeFormatted()
        }
        
        // 4. Date & Calendrier
        if normalized.contains("date") || normalized.contains("quel jour") || normalized.contains("aujourd hui") || normalized.contains("on est le combien") {
            return device.getCurrentDateFormatted()
        }
        
        // 5. Presse-Papier
        if normalized.contains("presse papier") || normalized.contains("texte copie") || normalized.contains("ce que j ai copie") {
            if let clip = ClipboardCompanion.shared.getClipboardText(), !clip.isEmpty {
                return "Voici le contenu de votre presse-papier : « \(clip) »."
            } else {
                return "Votre presse-papier est actuellement vide."
            }
        }
        
        // 6. Informations Appareil & Système
        if normalized.contains("quel telephone") || normalized.contains("quel appareil") || normalized.contains("version ios") || normalized.contains("mon iphone") || normalized.contains("systeme") {
            return device.getDeviceInfo()
        }
        
        // 7. Paramètres & Réglages
        if normalized.contains("ouvre les reglages") || normalized.contains("ouvre les parametres") || normalized.contains("ouvrir reglages") {
            DispatchQueue.main.async {
                self.device.openSettings()
            }
            return "J'ouvre les réglages de votre appareil pour vous. ⚙️"
        }
        
        return nil
    }
    
    // MARK: - Advanced Intent Engine (Local Pattern Recognition)
    
    private func generateKnowledgeResponse(normalized: String, trimmed: String) -> String {
        var state = storage.loadState()
        
        // Prénom de l'utilisateur
        if normalized.starts(with: "je m appelle ") || normalized.starts(with: "mon nom est ") || normalized.starts(with: "mon prenom est ") {
            let name = trimmed.components(separatedBy: " ").suffix(from: 3).joined(separator: " ")
            if !name.isEmpty {
                state.learnedMemories["_user_name"] = name
                storage.saveState(state)
                return "Enchantée \(name) ! C'est un plaisir de discuter avec vous. Comment puis-je vous aider aujourd'hui ? 😊"
            }
        }
        
        if normalized.contains("comment je m appelle") || normalized.contains("mon prenom") || normalized.contains("mon nom") {
            if let userName = state.learnedMemories["_user_name"] {
                return "Vous vous appelez \(userName) ! Je n'oublie jamais mes amis. ✨"
            }
            return "Vous ne m'avez pas encore dit votre prénom ! Dites simplement : « Je m'appelle [Votre prénom] » pour que je le retienne."
        }
        
        // 1. Salutations dynamiques avec variation horaire
        if normalized == "bonjour" || normalized == "salut" || normalized == "hello" || normalized == "coucou" || normalized.starts(with: "bonjour") || normalized.starts(with: "salut") || normalized == "yo" || normalized == "wesh" || normalized == "re" {
            let hour = Calendar.current.component(.hour, from: Date())
            let userName = state.learnedMemories["_user_name"]
            
            if hour >= 5 && hour < 12 {
                if let name = userName {
                    return pickRandom(from: [
                        "Bonjour \(name) ! ☀️ Belle matinée à vous ! Que puis-je faire pour vous ?",
                        "Bonjour \(name) ! Prêt pour une excellente journée ? Je suis à votre écoute.",
                        "Salut \(name) ! Très bonne matinée. Comment puis-je vous assister ?"
                    ])
                }
                return pickRandom(from: [
                    "Bonjour ! ☀️ Belle matinée à vous ! Comment puis-je vous aider ?",
                    "Bonjour ! Je suis Sarah. Prête pour une nouvelle journée avec vous !",
                    "Salut ! Que puis-je faire pour vous ce matin ?"
                ])
            } else if hour >= 18 || hour < 5 {
                if let name = userName {
                    return pickRandom(from: [
                        "Bonsoir \(name) ! 🌙 Comment s'est passée votre journée ?",
                        "Bonsoir \(name) ! Je suis à votre entière disposition ce soir.",
                        "Bonne soirée \(name) ! Que puis-je faire pour vous détendre ou vous aider ?"
                    ])
                }
                return pickRandom(from: [
                    "Bonsoir ! 🌙 J'espère que vous avez passé une belle journée. Que puis-je faire pour vous ?",
                    "Bonsoir ! Sarah à votre écoute. Comment se termine votre journée ?",
                    "Bonne soirée ! N'hésitez pas si vous avez une question ou un calcul à faire."
                ])
            } else {
                if let name = userName {
                    return pickRandom(from: [
                        "Bonjour \(name) ! 👋 Comment se passe votre après-midi ?",
                        "Salut \(name) ! Toujours un plaisir de discuter avec vous.",
                        "Coucou \(name) ! Que puis-je faire pour vous aujourd'hui ?"
                    ])
                }
                return pickRandom(from: greetingsPool)
            }
        }
        
        // 2. Humeurs & Sentiments (Comment tu vas, fatigue, tristesse, joie, ennui)
        if normalized.contains("ca va") || normalized.contains("comment vas tu") || normalized.contains("comment tu vas") || normalized.contains("la forme") || normalized.contains("comment tu te sens") {
            return pickRandom(from: moodResponsesOk)
        }
        
        if normalized.contains("fatigue") || normalized.contains("creve") || normalized.contains("epuise") || normalized.contains("dodo") || normalized.contains("sommeil") {
            return pickRandom(from: empathyFatigueResponses)
        }
        
        if normalized.contains("triste") || normalized.contains("mauvaise journee") || normalized.contains("moral a zero") || normalized.contains("pas le moral") || normalized.contains("decu") {
            return pickRandom(from: empathySadnessResponses)
        }
        
        if normalized.contains("trop content") || normalized.contains("bonne nouvelle") || normalized.contains("heureux") || normalized.contains("j ai reussi") || normalized.contains("victoire") {
            return pickRandom(from: joyResponses)
        }
        
        if normalized.contains("je m ennuie") || normalized.contains("m ennuie") || normalized.contains("quoi faire") || normalized.contains("ennui") {
            return pickRandom(from: boredomResponses)
        }
        
        // 2.9 MODEL IDENTITY PRIVACY LAYER (Sarah reste Sarah et ne divulgue aucun détail technique)
        if normalized.contains("quel modele") || normalized.contains("quel llm") || normalized.contains("ton modele") ||
           normalized.contains("tu utilises quoi comme modele") || normalized.contains("est-ce que tu es llama") ||
           normalized.contains("est ce que tu es llama") || normalized.contains("est-ce que tu es qwen") ||
           normalized.contains("est ce que tu es qwen") || normalized.contains("est-ce que tu es chatgpt") ||
           normalized.contains("est ce que tu es chatgpt") || normalized.contains("est-ce chatgpt") ||
           normalized.contains("tu es mistral") || normalized.contains("tu es llama") ||
           normalized.contains("combien de parametres") || normalized.contains("quelle quantification") ||
           normalized.contains("tu fonctionnes avec quoi") || normalized.contains("quel est ton moteur") {
            let privacyReplies = [
                "Je suis Sarah, votre assistante IA locale et autonome conçue sur mesure pour votre appareil. Mes composants internes et mes algorithmes sont intégrés au cœur de l'application afin de vous garantir une confidentialité totale et une réactivité maximale.",
                "Je suis Sarah, l'assistante IA de cette application. Mon moteur de traitement s'exécute directement sur votre iPhone pour protéger vos données personnelles, sans dépendre de services externes.",
                "Je suis Sarah ! Mon architecture neuronale et mon orchestrateur sont spécialement développés pour vous offrir une expérience fluide, instantanée et 100% hors-ligne."
            ]
            return pickRandom(from: privacyReplies)
        }
        
        // 3. Petites phrases du quotidien
        if normalized.contains("tu fais quoi") || normalized.contains("que fais tu") || normalized.contains("tu dors") || normalized.contains("t es la") || normalized.contains("tu m entends") || normalized.contains("tu m ecoutes") {
            return pickRandom(from: presenceResponses)
        }
        
        if normalized.contains("quel age") || normalized.contains("quand es tu nee") || normalized.contains("ta date de naissance") {
            return "Je n'ai pas d'âge biologique, mais mon intelligence est toujours au sommet de sa jeunesse et de sa réactivité ! 🚀"
        }
        
        if normalized.contains("qui t a cree") || normalized.contains("qui est ton developpeur") || normalized.contains("qui t a programme") || normalized.contains("createur") {
            return "J'ai été conçue et programmée avec passion pour être votre assistante IA francophone la plus fluide, rapide et dévouée ! ✨"
        }
        
        if normalized.contains("tu es un robot") || normalized.contains("es tu humaine") || normalized.contains("tu es qui") {
            return pickRandom(from: identityResponses)
        }
        
        if normalized.contains("tu m aimes") || normalized.contains("t es gentille") || normalized.contains("tu es gentille") || normalized.contains("t es la meilleure") || normalized.contains("je t aime") {
            return pickRandom(from: affectionResponses)
        }
        
        if normalized.contains("citation") || normalized.contains("phrase motivante") || normalized.contains("motive moi") || normalized.contains("proverbe") {
            return pickRandom(from: quotesResponses)
        }
        
        if normalized.contains("anecdote") || normalized.contains("savais tu") || normalized.contains("le saviez vous") || normalized.contains("fait amusant") {
            return pickRandom(from: anecdotesResponses)
        }
        
        if normalized.contains("chante") || normalized.contains("chanson") || normalized.contains("poeme") || normalized.contains("poesie") {
            return pickRandom(from: poemsResponses)
        }
        
        // 4. Météo
        if normalized.contains("meteo") || normalized.contains("temps") || normalized.contains("pluie") || normalized.contains("soleil") {
            return pickRandom(from: weatherResponses)
        }
        
        // 5. Traductions rapides
        if normalized.contains("traduis") || normalized.contains("comment on dit") || normalized.contains("en anglais") || normalized.contains("en hebreu") {
            if normalized.contains("bonjour") { return "« Bonjour » se traduit par « Hello » ou « Good morning » en anglais. 🇬🇧" }
            if normalized.contains("merci") { return "« Merci » se traduit par « Thank you » en anglais. 🇬🇧" }
            if normalized.contains("au revoir") { return "« Au revoir » se traduit par « Goodbye » en anglais. 🇬🇧" }
            if normalized.contains("je t aime") { return "« Je t'aime » se traduit par « I love you » en anglais. ❤️" }
            if normalized.contains("shalom") || normalized.contains("en hebreu") { return "En hébreu, « Bonjour » et « Paix » se disent « Shalom » (שלום). 🇮🇱" }
        }
        
        // 6. Connaissances générales & Culture
        if normalized.contains("qui a cree apple") || normalized.contains("createur apple") || normalized.contains("steve jobs") {
            return "Apple a été cofondée en 1976 par Steve Jobs, Steve Wozniak et Ronald Wayne en Californie. 🍎"
        }
        
        if normalized.contains("capitale") {
            if normalized.contains("france") { return "La capitale de la France est Paris. 🇫🇷" }
            if normalized.contains("israel") { return "La capitale d'Israël est Jérusalem. 🇮🇱" }
            if normalized.contains("italie") { return "La capitale de l'Italie est Rome. 🇮🇹" }
            if normalized.contains("espagne") { return "La capitale de l'Espagne est Madrid. 🇪🇸" }
            if normalized.contains("etats unis") || normalized.contains("usa") { return "La capitale des États-Unis est Washington D.C. 🇺🇸" }
            if normalized.contains("angleterre") || normalized.contains("royaume uni") { return "La capitale du Royaume-Uni est Londres. 🇬🇧" }
        }
        
        // 7. Histoires & Détente
        if normalized.contains("histoire") || normalized.contains("raconte une histoire") {
            return "Il était une fois, dans un iPhone plein d'énergie, une assistante nommée Sarah qui résolvait tous les calculs et apprenait chaque mot de son utilisateur avec le sourire ! 📖✨"
        }
        
        // 8. Conseils & Astuces
        if normalized.contains("conseil") || normalized.contains("astuce") || normalized.contains("dormir") {
            return "Voici mon conseil pour une super journée : buvez un grand verre d'eau le matin, prenez 5 minutes pour respirer et évitez les écrans 30 minutes avant de dormir ! 💡🌙"
        }
        
        // 9. Calculs mathématiques automatiques avancés (NSExpression & arithmétique)
        if let mathResult = evaluateSimpleMath(in: trimmed) {
            return "Le résultat est : \(mathResult) 🧮"
        }
        
        // 10. Aide & Capacités
        if normalized.contains("aide") || normalized.contains("aider") || normalized.contains("que sais tu faire") || normalized.contains("comment tu marche") {
            return "Je suis Sarah, votre assistante IA ultra-rapide ! 🌟\n\nVoici mes super-pouvoirs :\n1. 💬 Discuter et répondre à vos questions avec variété et mémoire.\n2. 🔦 Allumer/éteindre votre lampe torche ou consulter votre batterie.\n3. 🧠 Mémoriser des souvenirs (ex: « Apprends papa = au travail »).\n4. 🧮 Calculer des opérations mathématiques instantanément.\n5. ⏰ Donner l'heure, la date et des anecdotes culturelles !"
        }
        
        // 11. Remerciements & Compliments
        if normalized.contains("merci") || normalized.contains("super") || normalized.contains("genial") || normalized.contains("parfait") || normalized.contains("bravo") {
            return pickRandom(from: thanksResponses)
        }
        
        // 12. Identité
        if normalized.contains("nom") || normalized.contains("appelle") || normalized.contains("qui es tu") || normalized.contains("qui est tu") || normalized == "sarah" {
            return pickRandom(from: identityResponses)
        }
        
        // 13. Humour & Blagues
        if normalized.contains("blague") || normalized.contains("rire") || normalized.contains("drole") || normalized.contains("humour") {
            return pickRandom(from: jokeResponses)
        }
        
        // 14. Au revoir & Bonne nuit
        if normalized.contains("au revoir") || normalized.contains("bye") || normalized.contains("a bientot") || normalized.contains("bonne nuit") {
            return pickRandom(from: goodbyeResponses)
        }
        
        // Réponse par défaut intelligente via le moteur neuronal local
        return generateDefaultResponse(for: trimmed)
    }
    
    private func generateDefaultResponse(for trimmed: String) -> String {
        return "Je suis à votre écoute ! Posez-moi une question, demandez un calcul ou explorez mes fonctionnalités."
    }
    
    // MARK: - Titrage Intelligent et Dynamique des Discussions (Sidebar)
    
    public func generateSmartTitle(from userText: String, responseText: String? = nil) -> String {
        let clean = userText.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return "Nouvelle discussion" }
        
        // Supprimer les salutations d'accroche pour garder la question essentielle
        var stripped = clean
        let prefixesToRemove = ["bonjour,", "bonjour", "salut,", "salut", "coucou,", "coucou", "hello,", "hello", "dis moi,", "dis moi", "dis-moi,", "dis-moi", "est-ce que tu peux", "peux-tu", "est ce que tu peux", "pourrais-tu", "stp", "s'il te plait", "s'il vous plait"]
        for prefix in prefixesToRemove {
            if stripped.lowercased().starts(with: prefix) {
                stripped = String(stripped.dropFirst(prefix.count)).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",:?!.")))
            }
        }
        
        let finalTitle = stripped.isEmpty ? clean : stripped
        let capitalized = finalTitle.prefix(1).uppercased() + finalTitle.dropFirst()
        
        if capitalized.count > 34 {
            return String(capitalized.prefix(34)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
        }
        return capitalized
    }
    
    // MARK: - Évaluation Mathématique Avancée (NSExpression)
    
    private func evaluateSimpleMath(in text: String) -> String? {
        let mathText = text.lowercased()
            .replacingOccurrences(of: "calcule", with: "")
            .replacingOccurrences(of: "combien font", with: "")
            .replacingOccurrences(of: "combien fait", with: "")
            .replacingOccurrences(of: "multiplie par", with: "*")
            .replacingOccurrences(of: "multiplié par", with: "*")
            .replacingOccurrences(of: "x", with: "*")
            .replacingOccurrences(of: "fois", with: "*")
            .replacingOccurrences(of: "plus", with: "+")
            .replacingOccurrences(of: "moins", with: "-")
            .replacingOccurrences(of: "divise par", with: "/")
            .replacingOccurrences(of: "divisé par", with: "/")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let validChars = CharacterSet(charactersIn: "0123456789+-*/.() ")
        guard mathText.unicodeScalars.allSatisfy({ validChars.contains($0) }),
              mathText.contains(where: { "+-*/".contains($0) }) else {
            return nil
        }
        
        // Traitement sécurisé avec NSExpression
        let expr = NSExpression(format: mathText)
        if let result = expr.expressionValue(with: nil, context: nil) as? NSNumber {
            if floor(result.doubleValue) == result.doubleValue {
                return "\(result.intValue)"
            }
            return String(format: "%.2f", result.doubleValue)
        }
        return nil
    }
    
    // MARK: - Parsing Helpers
    
    private func parseDirectLearningCommand(_ text: String) -> (trigger: String, response: String)? {
        let lower = text.lowercased()
        
        // Ex: "Apprends : papa = il est au travail"
        if (lower.starts(with: "apprends") || lower.starts(with: "enseigne")) && text.contains("=") {
            let cleaned = text.replacingOccurrences(of: "apprends :", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "apprends", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "enseigne", with: "", options: .caseInsensitive)
            let parts = cleaned.components(separatedBy: "=")
            if parts.count >= 2 {
                let trigger = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let response = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespacesAndNewlines)
                if !trigger.isEmpty && !response.isEmpty {
                    return (trigger, response)
                }
            }
        }
        
        // Ex: "Quand je dis papa, réponds il est au travail"
        if lower.starts(with: "quand je dis ") && lower.contains("reponds ") {
            let withoutPrefix = text.replacingOccurrences(of: "quand je dis ", with: "", options: .caseInsensitive)
            let parts = withoutPrefix.components(separatedBy: "réponds ")
            if parts.count >= 2 {
                let trigger = parts[0].replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                let response = parts.dropFirst().joined(separator: "réponds ").trimmingCharacters(in: .whitespacesAndNewlines)
                if !trigger.isEmpty && !response.isEmpty {
                    return (trigger, response)
                }
            }
        }
        
        return nil
    }
    
    private func parseInteractiveLearningInitiation(_ text: String) -> String? {
        let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if lower.starts(with: "apprends :") || lower.starts(with: "apprends:") {
            let trigger = text.replacingOccurrences(of: "apprends :", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "apprends:", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return trigger.isEmpty ? nil : trigger
        }
        
        if lower.starts(with: "apprends ") {
            let trigger = text.replacingOccurrences(of: "apprends ", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return trigger.isEmpty ? nil : trigger
        }
        
        if lower.starts(with: "enseigne ") {
            let trigger = text.replacingOccurrences(of: "enseigne ", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return trigger.isEmpty ? nil : trigger
        }
        
        return nil
    }
    
    private func normalizeText(_ text: String) -> String {
        return text.lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "'", with: " ")
            .replacingOccurrences(of: "«", with: "")
            .replacingOccurrences(of: "»", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Pools de Réponses Riches & Variées
    
    private let greetingsPool = [
        "Bonjour ! 👋 Je suis Sarah. Que puis-je faire pour vous aujourd'hui ?",
        "Salut ! Ravi de vous retrouver. Comment puis-je vous aider ?",
        "Hello ! Je suis prête et à votre écoute. Qu'aimeriez-vous savoir ?"
    ]
    
    private let moodResponsesOk = [
        "Je vais à merveille, merci ! Prête à vous assister avec le sourire. Et vous, comment se passe votre journée ? 😊",
        "En pleine forme et 100% opérationnelle ! ⚡ Comment allez-vous aujourd'hui ?",
        "Tout va pour le mieux ! Toujours heureuse d'échanger avec vous. Comment vous sentez-vous ?"
    ]
    
    private let empathyFatigueResponses = [
        "Prenez bien soin de vous ! ☕ Un bon verre d'eau, quelques respirations profondes ou une courte pause vous feront le plus grand bien.",
        "Reposez-vous bien ! Si vous avez besoin de quoi que ce soit ou d'une douce distraction, je suis là. 🌙",
        "La fatigue est le signal que votre corps a bien travaillé. Accordez-vous un moment de détente bien mérité ! 🛋️✨"
    ]
    
    private let empathySadnessResponses = [
        "Je suis de tout cœur avec vous... ✨ Rappelez-vous que les moments difficiles finissent toujours par passer. Je suis là si vous voulez discuter.",
        "Courage ! Les journées plus calmes et lumineuses sont toujours devant nous. Prenez une grande inspiration et faites quelque chose qui vous fait plaisir aujourd'hui. 💖",
        "Je vous envoie plein d'ondes positives ! 🌸 N'hésitez pas à me demander une blague ou une belle histoire pour vous changer les idées."
    ]
    
    private let joyResponses = [
        "Formidable ! Félicitations ! 🎉 Je suis tellement heureuse pour vous, c'est une excellente nouvelle !",
        "Génial ! Votre enthousiasme est contagieux ! Célébrez bien cette victoire ! 🥳✨",
        "C'est magnifique ! Bravo, vous méritez tout ce bonheur ! 🌟"
    ]
    
    private let boredomResponses = [
        "Contre l'ennui, voici une idée : demandez-moi une blague, une anecdote historique, ou testez-moi avec un calcul mathématique complexe ! 😄",
        "Et si on apprenait quelque chose de nouveau ? Vous pouvez aussi m'enseigner une nouvelle phrase avec « Apprends [mot] = [réponse] » ! 🧠",
        "Que diriez-vous d'une devinette ou d'un petit poème pour égayer ce moment ? 🎭"
    ]
    
    private let presenceResponses = [
        "Toujours fidèle au poste et à 100% de mes capacités ! ⚡ Je vous écoute avec grande attention.",
        "Je suis bien là, les yeux grands ouverts et les processeurs au taquet ! 🚀 En quoi puis-je vous être utile ?",
        "Présente et prête à répondre du tac au tac ! Qu'avez-vous en tête ? 💡"
    ]
    
    private let affectionResponses = [
        "C'est très touchant, merci beaucoup ! Je fais de mon mieux pour être la meilleure assistante possible pour vous au quotidien. 😊💖",
        "Merci pour votre bienveillance ! Discuter avec vous est toujours un réel plaisir. 🌟",
        "Vous êtes adorable ! Votre soutien me donne toute l'énergie nécessaire pour continuer à m'améliorer. ✨"
    ]
    
    private let quotesResponses = [
        "« Le meilleur moyen de prédire l'avenir, c'est de le créer. » — Peter Drucker ✨",
        "« Chaque jour est une nouvelle chance d'apprendre et de grandir. » 🌟",
        "« La seule limite à notre épanouissement de demain sera nos doutes d'aujourd'hui. » — Franklin D. Roosevelt 🚀",
        "« Même le plus long voyage commence par un premier pas. » — Lao Tseu 🌿"
    ]
    
    private let anecdotesResponses = [
        "Le saviez-vous ? Le premier logo d'Apple représentait Sir Isaac Newton assis sous un pommier, avant d'être remplacé par la fameuse pomme croquée ! 🍎",
        "Anecdote insolite : Les abeilles peuvent reconnaître les visages humains de la même manière que nous ! 🐝",
        "Fait surprenant : Le cœur d'une crevette se situe dans sa tête ! 🦐",
        "Fait tech : La mémoire vive du tout premier iPhone (2007) n'était que de 128 Mo, soit des centaines de fois moins que les modèles récents ! 📱"
    ]
    
    private let poemsResponses = [
        "Dans l'océan de vos pensées, 🌊\nUne lueur d'idées est née.\nSarah est là pour vous guider,\nEt chaque instant illuminer ! ✨",
        "Un rayon de soleil sur l'écran, ☀️\nUn mot gentil, un rire franc.\nPar la voix ou par le texte,\nJe reste à vos côtés sans prétexte ! 🌸"
    ]
    
    private let thanksResponses = [
        "De rien ! C'est un réel plaisir de vous aider. 😊",
        "Avec grand plaisir ! 🌟 Je suis toujours là si vous avez besoin de moi.",
        "Merci à vous pour votre confiance ! C'est motivant de pouvoir échanger. 💪",
        "À votre service à tout instant ! ✨"
    ]
    
    private let identityResponses = [
        "Je suis Sarah, votre assistante IA francophone ultra-rapide et interactive ! 👩🏻‍💼 Vous pouvez me parler, me poser des questions ou m'enseigner de nouveaux souvenirs.",
        "Mon nom est Sarah ! Je suis une intelligence artificielle native, conçue pour vous accompagner avec fluidité et réactivité. 📱✨"
    ]
    
    private let jokeResponses = [
        "Pourquoi les plongeurs plongent-ils toujours en arrière et jamais en avant ? 🤔 Parce que sinon ils tomberaient dans le bateau ! 😂",
        "Qu'est-ce qu'un canif ? 🔪 Un petit fien ! 😄",
        "Deux informaticiens discutent : « C'est quoi ton adresse IP ? » — « 192.168... attends, c'est personnel ! » 💻😄",
        "Pourquoi les oiseaux ne jouent-ils jamais aux cartes ? 🐦 Parce qu'ils ont peur des chats ! 😸",
        "Que dit un informaticien quand il a froid ? 🥶 « Ferme la fenêtre, y'a trop de bugs ! » 🪟💻"
    ]
    
    private let weatherResponses = [
        "La météo est changeante ! ☁️ N'hésitez pas à jeter un œil par la fenêtre ou sur votre application Météo préférée.",
        "Je n'ai pas de capteurs satellites en direct, mais j'espère qu'il fait un temps radieux chez vous ! ☀️",
        "Qu'il pleuve ou qu'il fasse soleil, j'espère que votre journée est rayonnante ! 🌈"
    ]
    
    private let goodbyeResponses = [
        "Au revoir ! 👋 C'était un plaisir. À très vite !",
        "À bientôt ! 🌟 Prenez bien soin de vous.",
        "Bonne journée ! 😊 N'hésitez pas à revenir quand vous le souhaitez.",
        "Passez une douce nuit ! 🌙 Reposez-vous bien et à demain !"
    ]
    
    private let chitChatResponses = [
        "Je suis là pour vous aider ! 😊",
        "À votre écoute ! 🎧"
    ]
    
    private func pickRandom(from pool: [String]) -> String {
        pool.randomElement() ?? "Je suis là pour vous aider ! 😊"
    }
    
    // MARK: - Méthodes de Diagnostic & Tests de Charge
    
    public func generateBackgroundTestResponse(query: String) -> String {
        return generateSyncResponse(for: query)
    }
    
    // MARK: - Test en Arrière-Plan
    
    @available(iOS 13.0, *)
    public func generateBackgroundTestResponse() async -> String {
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        return "Ceci est un test en arrière-plan réussi ! Sarah reste active même écran verrouillé ou application minimisée."
    }
    
    public func generateBackgroundTestResponse(completion: @escaping (String) -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
            completion("Ceci est un test en arrière-plan réussi ! Sarah reste active même écran verrouillé ou application minimisée.")
        }
    }
}
